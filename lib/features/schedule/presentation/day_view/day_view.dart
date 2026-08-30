import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date_math.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/di.dart';
import '../../../../core/format.dart';
import '../../../../core/time_format.dart';
import '../../../../design/glass/glass_surface.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../../design/widgets/section_header.dart';
import '../../../../design/widgets/snackbar_x.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/application/settings_controller.dart';
import '../../application/schedule_providers.dart';
import '../../../todo/presentation/hourly_todo_list.dart';
import '../../domain/drag_create.dart';
import '../../domain/event_input.dart';
import '../../domain/event_overlap.dart';
import '../event_edit/event_editor_sheet.dart';
import 'day_clock_view.dart';

/// The signature view: a day laid out as a vertical river of hours, with events
/// as glass cards floating over the time-of-day gradient, plus the day's to-dos.
///
/// Has two layouts, switched by [dayViewLayoutModeProvider]: the timeline
/// above, or [DayClockView]'s 24-hour dial. [compact] (set by `MonthView`'s
/// embedded instance, under its calendar grid) forces the timeline
/// regardless of that preference — a dial needs more room to stay legible
/// than the space left under a month grid affords, and unlike the
/// full-screen day view there's no layout-toggle control reachable from
/// there anyway.
class DayView extends ConsumerStatefulWidget {
  const DayView({super.key, required this.day, this.compact = false});

  final DateTime day;
  final bool compact;

  static const double _hourHeight = 64;
  static const double _railInset = 62;

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<DayView> {
  final _addTodoFocusNode = FocusNode();
  final _todosSectionKey = GlobalKey();

  @override
  void dispose() {
    _addTodoFocusNode.dispose();
    super.dispose();
  }

  /// The section header's "+" — jumps straight to the inline add field
  /// instead of making the user scroll past the whole 24-hour timeline to
  /// reach it themselves.
  void _focusAddTodo() {
    _addTodoFocusNode.requestFocus();
    final todosContext = _todosSectionKey.currentContext;
    if (todosContext != null) {
      Scrollable.ensureVisible(
        todosContext,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final eventsAsync = ref.watch(eventsForDayProvider(widget.day));
    final now = DateTime.now();
    final isToday = dateOnly(now) == dateOnly(widget.day);
    final layoutMode = widget.compact
        ? DayViewLayoutMode.timeline
        : ref.watch(dayViewLayoutModeProvider);

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (events) {
        final timed = events.where((e) => !e.isAllDay).toList();
        final allDay = events.where((e) => e.isAllDay).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xs,
            AppSpacing.gutter,
            140,
          ),
          children: [
            if (allDay.isNotEmpty) ...[
              for (final e in allDay)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _EventCard(event: e, allDay: true),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (timed.isEmpty && allDay.isEmpty)
              _EmptyDay(l10n: l10n)
            else if (layoutMode == DayViewLayoutMode.clock)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DayClockView(
                    day: widget.day,
                    events: timed,
                    isToday: isToday,
                    now: now,
                    locale: locale,
                  ),
                ),
              )
            else
              SizedBox(
                height: DayView._hourHeight * 24,
                child: _Timeline(
                  day: widget.day,
                  events: timed,
                  isToday: isToday,
                  now: now,
                  locale: locale,
                  hourHeight: DayView._hourHeight,
                  railInset: DayView._railInset,
                  accent: palette.accent,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              l10n.todosSectionTitle,
              trailing: IconButton(
                tooltip: l10n.todoAdd,
                onPressed: _focusAddTodo,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add, size: 20, color: palette.inkFaint),
              ),
            ),
            KeyedSubtree(
              key: _todosSectionKey,
              child: HourlyTodoList(
                day: widget.day,
                addFocusNode: _addTodoFocusNode,
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _DragMode { move, resize }

class _Timeline extends ConsumerStatefulWidget {
  const _Timeline({
    required this.day,
    required this.events,
    required this.isToday,
    required this.now,
    required this.locale,
    required this.hourHeight,
    required this.railInset,
    required this.accent,
  });

  final DateTime day;
  final List<EventRow> events;
  final bool isToday;
  final DateTime now;
  final String locale;
  final double hourHeight;
  final double railInset;
  final Color accent;

  @override
  ConsumerState<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<_Timeline>
    with WidgetsBindingObserver {
  /// The shortest an event card is ever drawn, regardless of its actual
  /// duration — below this, its title/time text and resize grip don't fit
  /// without clipping. Empirically the smallest that comfortably fits both
  /// text lines plus the grip at this card's padding/type scale.
  static const double _minEventCardHeight = 80;

  /// The event currently being dragged, if any — only one card can drag at a
  /// time since drags are single-pointer gestures.
  String? _draggingId;
  _DragMode? _dragMode;

  /// Raw accumulated pointer delta in pixels since the drag began; converted
  /// to a 5-minute-snapped offset for both the live preview and the save.
  double _dragPixels = 0;

  /// Long-press-drag-to-create state: the anchor (touch-down) and current
  /// pointer Y, both in the timeline's own coordinate space (0 = midnight).
  /// Null whenever no create-drag is in progress. The lower of the two ends
  /// up as the new event's start, the higher as its end — same "drag either
  /// direction from the anchor" convention as most calendar apps.
  double? _createAnchorY;
  double? _createCurrentY;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A long-press-drag (move/resize/create) that's already been *accepted*
  /// (i.e. `onLongPressStart` already fired) gets no `onLongPressEnd` or
  /// `onLongPressCancel` callback at all if the gesture is then interrupted
  /// by a `PointerCancelEvent` — Flutter's own `LongPressGestureRecognizer`
  /// only invokes `onLongPressCancel` while the gesture is still in its
  /// pre-acceptance `possible` state (confirmed against
  /// `_checkLongPressCancel` in long_press.dart). The app being backgrounded
  /// mid-drag (home button, an incoming call) is exactly that: the pointer
  /// stream cancels, and without this, the card/create-ghost would stay
  /// stuck rendered in its dragged-offset position indefinitely, no save
  /// having happened and no further gesture able to reach it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _resetDragState();
  }

  void _resetDragState() {
    if (_draggingId == null &&
        _dragMode == null &&
        _createAnchorY == null &&
        _createCurrentY == null) {
      return;
    }
    setState(() {
      _draggingId = null;
      _dragMode = null;
      _dragPixels = 0;
      _createAnchorY = null;
      _createCurrentY = null;
    });
  }

  /// Pixel offset from the top of the timeline for [t]. Computed as minutes
  /// elapsed since [widget.day]'s midnight rather than `t.hour * 60 +
  /// t.minute` — the latter reads midnight-of-the-*next*-day (exactly what a
  /// drag/resize clamps an end time to when pushed past the bottom of the
  /// timeline) as 0, identical to the day's own start, collapsing the live
  /// preview card to zero height instead of showing it pinned to the bottom.
  double _offsetFor(DateTime t) {
    final dayStart = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
    );
    final minutes = t.difference(dayStart).inMinutes;
    return minutes / 60.0 * widget.hourHeight;
  }

  int get _snappedDeltaMinutes {
    final raw = _dragPixels / widget.hourHeight * 60;
    return (raw / 5).round() * 5;
  }

  /// The start/end a card should render at (and, on drag end, be saved with)
  /// given the current drag — clamped to stay within [day, day+1) so a card
  /// can never drag itself out of the timeline it's shown in.
  (DateTime start, DateTime end) _effectiveTimes(EventRow e) {
    if (_draggingId != e.id || _dragMode == null) {
      return (e.startAt, e.endAt);
    }
    final dayStart = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
    );
    final dayEnd = addCalendarDays(dayStart, 1);
    final delta = Duration(minutes: _snappedDeltaMinutes);

    if (_dragMode == _DragMode.move) {
      var start = e.startAt.add(delta);
      var end = e.endAt.add(delta);
      if (start.isBefore(dayStart)) {
        final shift = dayStart.difference(start);
        start = start.add(shift);
        end = end.add(shift);
      }
      if (end.isAfter(dayEnd)) {
        final shift = end.difference(dayEnd);
        start = start.subtract(shift);
        end = end.subtract(shift);
      }
      return (start, end);
    } else {
      final minEnd = e.startAt.add(const Duration(minutes: 15));
      var end = e.endAt.add(delta);
      if (end.isBefore(minEnd)) end = minEnd;
      if (end.isAfter(dayEnd)) end = dayEnd;
      return (e.startAt, end);
    }
  }

  void _startDrag(String eventId, _DragMode mode) {
    HapticFeedback.mediumImpact();
    setState(() {
      _draggingId = eventId;
      _dragMode = mode;
      _dragPixels = 0;
    });
  }

  /// [totalDeltaY] is the cumulative offset since the long-press began (as
  /// long-press-move reports it), not a per-frame delta — so this sets
  /// rather than accumulates.
  void _updateDrag(double totalDeltaY) {
    setState(() => _dragPixels = totalDeltaY);
  }

  Future<void> _endDrag(EventRow e) async {
    final (start, end) = _effectiveTimes(e);
    setState(() {
      _draggingId = null;
      _dragMode = null;
      _dragPixels = 0;
    });
    if (start == e.startAt && end == e.endAt) return;
    await ref
        .read(eventRepositoryProvider)
        .save(
          EventInput(
            id: e.id,
            title: e.title,
            memo: e.memo,
            startAt: start,
            endAt: end,
            isAllDay: false,
            notify: e.notify,
            reminderMinutesBefore: e.reminderMinutesBefore,
            colorTag: e.colorTag,
          ),
        );
  }

  void _startCreate(double y) {
    HapticFeedback.mediumImpact();
    setState(() {
      _createAnchorY = y;
      _createCurrentY = y;
    });
  }

  void _updateCreate(double y) {
    setState(() => _createCurrentY = y);
  }

  /// The pending create-drag's start/end — null while no create-drag is
  /// active. See [snappedCreateRange] for the snapping/min-duration rules.
  (DateTime, DateTime)? get _pendingCreateRange {
    final anchor = _createAnchorY;
    final current = _createCurrentY;
    if (anchor == null || current == null) return null;
    final dayStart = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
    );
    return snappedCreateRange(
      dayStart,
      anchor,
      current,
      hourHeight: widget.hourHeight,
    );
  }

  Future<void> _endCreate() async {
    final range = _pendingCreateRange;
    setState(() {
      _createAnchorY = null;
      _createCurrentY = null;
    });
    if (range == null) return;
    await showEventEditor(
      context,
      initialDay: widget.day,
      initialStart: range.$1,
      initialEnd: range.$2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pendingCreate = _pendingCreateRange;
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Needed to split however many non-overlapping columns
        // cascadeEvents assigns a cluster into actual pixel widths below.
        final availableWidth = constraints.maxWidth - widget.railInset;

        return Stack(
          children: [
            // Long-press-drag on empty timeline space creates a new event
            // spanning the dragged range — positioned first (behind the hour
            // grid and event cards below) so a touch landing on an existing
            // card's own long-press region is claimed by that card first, per
            // Flutter's front-to-back hit-test order; this only ever wins the
            // gesture arena when the touch starts on genuinely empty space.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (d) => _startCreate(d.localPosition.dy),
                onLongPressMoveUpdate: (d) => _updateCreate(d.localPosition.dy),
                onLongPressEnd: (_) => _endCreate(),
              ),
            ),

            // Hour grid + labels.
            for (int h = 0; h < 24; h++)
              Positioned(
                top: h * widget.hourHeight,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: widget.hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shifted up to stay visually centered on the
                      // gridline below — the line itself sits exactly at
                      // this row's own top edge (h * hourHeight, matching
                      // _offsetFor's convention with no fudge factor) so
                      // event cards, which are positioned by that same
                      // _offsetFor, align exactly with it; previously the
                      // *line* carried a 7px top margin to center it under
                      // the label instead, which left every card's start/
                      // end a visible 7px off the gridline it's supposed
                      // to represent.
                      Transform.translate(
                        offset: const Offset(0, -7),
                        child: SizedBox(
                          width: widget.railInset - AppSpacing.sm,
                          child: Text(
                            Fmt.hour(h, widget.locale, use24Hour: use24),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: palette.inkFaint,
                                  fontFeatures: null,
                                ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(height: 1, color: palette.hairline),
                      ),
                    ],
                  ),
                ),
              ),

            // Live preview of the event being drag-created, shown while a
            // create-drag is in progress — the editor doesn't open until the
            // finger lifts (_endCreate), so this is the only feedback the user
            // gets of what range they're about to create.
            if (pendingCreate != null)
              Positioned(
                top: _offsetFor(pendingCreate.$1) + 2,
                left: widget.railInset,
                right: 0,
                height:
                    (_offsetFor(pendingCreate.$2) -
                            _offsetFor(pendingCreate.$1))
                        .clamp(0, widget.hourHeight * 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.22),
                    border: Border.all(color: widget.accent, width: 1.5),
                    borderRadius: AppRadius.cardMd,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Text(
                      '${Fmt.time(pendingCreate.$1, widget.locale, use24Hour: use24)} – ${Fmt.time(pendingCreate.$2, widget.locale, use24Hour: use24)}',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: widget.accent),
                    ),
                  ),
                ),
              ),

            // Event cards positioned by start time, sized exactly to their
            // own duration — top and bottom both land precisely on their
            // start/end hour gridlines, rather than the couple of px of
            // breathing room the layout used to nudge in (which read as the
            // card floating slightly off the grid it's meant to represent).
            //
            // Laid out into non-overlapping columns by [cascadeEvents] on each
            // card's own persisted (not drag-in-progress) start/end — two
            // events sharing a moment in time get their own side-by-side slice
            // of the width instead of one painting over the other, which for
            // two events of different lengths would otherwise make the
            // shorter one's edge read as truncating the longer one's — see
            // that function's own doc. Deliberately not recomputed against the
            // live drag preview, since reshuffling every other card's column
            // mid-drag would be distracting for what's a rare edge case to
            // begin with.
            for (final c in cascadeEvents(widget.events))
              Builder(
                key: ValueKey(c.event.id),
                builder: (context) {
                  final e = c.event;
                  final (start, end) = _effectiveTimes(e);
                  final isDragging = _draggingId == e.id;
                  final columnWidth = availableWidth / c.columnCount;
                  final leftInset = c.column * columnWidth;
                  final rightInset = availableWidth - leftInset - columnWidth;
                  // A floor under the raw duration-derived height: below
                  // roughly _minEventCardHeight, there just isn't room for
                  // the title, time and resize grip without clipping —
                  // short events already visually extend a bit past their
                  // true span for this reason (the same trade-off Google
                  // Calendar and friends make), it's just precomputed here
                  // now instead of left to grow reactively.
                  final rawHeight = (_offsetFor(end) - _offsetFor(start)).clamp(
                    0.0,
                    widget.hourHeight * 24,
                  );
                  final height = rawHeight < _minEventCardHeight
                      ? _minEventCardHeight
                      : rawHeight;
                  return Positioned(
                    top: _offsetFor(start),
                    left: widget.railInset + leftInset,
                    right: rightInset,
                    height: height,
                    child: _EventCard(
                      event: e,
                      allDay: false,
                      height: height,
                      isDragging: isDragging,
                      onMoveStart: () => _startDrag(e.id, _DragMode.move),
                      onMoveUpdate: _updateDrag,
                      onMoveEnd: () => _endDrag(e),
                      onResizeStart: () => _startDrag(e.id, _DragMode.resize),
                      onResizeUpdate: _updateDrag,
                      onResizeEnd: () => _endDrag(e),
                    ),
                  );
                },
              ),

            // "Now" indicator.
            if (widget.isToday)
              Positioned(
                top: _offsetFor(widget.now) - 4,
                left: widget.railInset - AppSpacing.sm - 4,
                right: 0,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(child: Container(height: 2, color: widget.accent)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({
    required this.event,
    required this.allDay,
    this.height,
    this.isDragging = false,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
  });

  final EventRow event;
  final bool allDay;

  /// The timeline's own computed pixel height for this card — null for the
  /// all-day strip, which sizes itself to its content instead. Used to pin
  /// the resize grip to the card's actual bottom edge rather than right
  /// under the title, so a multi-hour card's grip lands near the boundary
  /// it actually resizes instead of clustering all its content up top with
  /// a big empty gap below.
  final double? height;
  final bool isDragging;

  /// Dragging the card body moves the whole event, preserving its duration.
  final VoidCallback? onMoveStart;
  final ValueChanged<double>? onMoveUpdate;
  final VoidCallback? onMoveEnd;

  /// Dragging the bottom grip resizes the event by moving only its end time.
  final VoidCallback? onResizeStart;
  final ValueChanged<double>? onResizeUpdate;
  final VoidCallback? onResizeEnd;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(eventRepositoryProvider);
    final removed = event;
    await repo.delete(removed.id);
    messenger.showAutoDismissSnackBar(
      SnackBar(
        content: Text(l10n.eventDeleted),
        action: SnackBarAction(
          label: l10n.eventUndo,
          // restoreEvent(), not save() — the row is already gone by now, so
          // save() would see no existing row and treat this as a brand-new
          // event: reminderMinutesBefore resets to EventInput's default (0),
          // and recurrenceGroupId/recurrenceRule/osCalendarId/osEventId all
          // come from `existing`, which is null, silently severing the
          // restored event from its recurring series and its OS-calendar
          // link. restoreEvent() writes `removed` back exactly as it was.
          onPressed: () => repo.restoreEvent(removed),
        ),
      ),
    );
  }

  /// [color] shifted [amount] (0-1) toward black in HSL lightness, fully
  /// opaque — used for the card border so it reads as a solid, slightly
  /// deeper shade of the card's own accent rather than the same color at
  /// reduced alpha, which would blend into the tinted glass behind it.
  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final palette = context.palette;
    final accent = EventColorTag.resolve(event.colorTag, event.startAt);
    final theme = Theme.of(context);
    final draggable = onMoveStart != null;
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );

    // Swipe-to-delete is implemented by hand here rather than with
    // Dismissible: Dismissible wraps its child in a SizeTransition (even
    // with resizeDuration: null) and that combination, nested directly
    // around GlassSurface's BackdropFilter inside this Stack's per-event,
    // dynamically-sized cards, left the backdrop blur/tint painted at a
    // stale, smaller size than the card's real (correct) layout bounds
    // whenever that height differed between rebuilds — e.g. a 3-hour
    // event sharing a column with a 1-hour one rendered its glass fill
    // only ~1 hour tall, even though the card's own hit-test/border area
    // was verifiably the full 3 hours (confirmed by bounding the
    // ConstrainedBox itself in a debug border and watching only the
    // GlassSurface fill inside it come up short). Wrapping in
    // RepaintBoundary and disabling Dismissible's resize animation both
    // failed to fix it; only removing Dismissible entirely did.
    return GestureDetector(
      // Tapping anywhere on the card — not just the title/time text — opens
      // it for editing.
      onTap: () => showEventEditor(context, existing: event),
      // A decisive leftward swipe deletes — mirrors Dismissible's own
      // DismissDirection.endToStart, just without its slide/reveal
      // animation. Scoped to horizontal drags only, so it doesn't fight
      // the inner GestureDetector's long-press-drag (move) or the day
      // timeline's own vertical scroll.
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -300) _delete(context, ref);
      },
      // Long-press-then-drag (not a plain vertical drag) so a swipe that
      // starts on top of a card still scrolls the day timeline instead of
      // picking the event up — the two would otherwise both claim the same
      // vertical pan gesture. Lives on the same detector as onTap now that
      // it covers the whole card — tap and long-press are different enough
      // gesture types that Flutter's arena resolves them by timing, not by
      // competing for the same slot.
      onLongPressStart: onMoveStart == null ? null : (_) => onMoveStart!(),
      onLongPressMoveUpdate: onMoveUpdate == null
          ? null
          : (d) => onMoveUpdate!(d.offsetFromOrigin.dy),
      onLongPressEnd: onMoveEnd == null ? null : (_) => onMoveEnd!(),
      // A visible per-event border, distinct from GlassSurface's own subtle
      // hairline one — the main cue separating two cards that now sit flush
      // against each other (no gap) since cards align exactly to their hour
      // gridlines. Opaque and darkened rather than the accent at reduced
      // alpha, so it reads as a solid line against both the card's own
      // translucent tint and whatever sits behind it, instead of blending
      // into either. Painted as a Stack sibling *on top of* GlassSurface
      // rather than as a DecoratedBox wrapping it — DecoratedBox paints its
      // own decoration first and the child on top, so a border there was
      // being fully painted over by GlassSurface's own opaque-ish fill and
      // never actually visible.
      child: Stack(
        children: [
          RepaintBoundary(
            child: GlassSurface(
              borderRadius: AppRadius.cardMd,
              tint: accent.withValues(
                alpha:
                    (palette.isDark ? 0.22 : 0.16) * (isDragging ? 1.6 : 1.0),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                mainAxisSize: height == null
                    ? MainAxisSize.min
                    : MainAxisSize.max,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 30,
                        margin: const EdgeInsets.only(right: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: AppRadius.allPill,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title.isEmpty ? '—' : event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (!allDay)
                              Text(
                                '${Fmt.time(event.startAt, locale, use24Hour: use24)} – ${Fmt.time(event.endAt, locale, use24Hour: use24)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: palette.inkSoft,
                                ),
                              ),
                            if (event.location != null &&
                                event.location!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 12,
                                    color: palette.inkFaint,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      event.location!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: palette.inkFaint),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (event.notify)
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 15,
                          color: palette.inkFaint,
                        ),
                    ],
                  ),
                  // Pushes the resize grip down to the card's actual bottom
                  // edge for a card taller than its header content — without
                  // this, a multi-hour card's whole content (header + grip)
                  // stayed clumped at the very top with a large dead gap below,
                  // instead of the grip landing near the boundary it actually
                  // resizes. Safe to use unconditionally when height != null:
                  // height is this card's own exact, tight constraint (not
                  // just a loose minimum), so Expanded/Spacer here can never
                  // balloon the card past its intended size.
                  if (height != null) const Spacer(),
                  // A drag-to-resize grip, kept as a small separate hit region below
                  // the tappable/movable row rather than nested inside it — two
                  // drag recognizers stacked on the very same region would leave
                  // Flutter's gesture arena to guess which one the user meant.
                  // Long-press-then-drag here too, for the same reason as the move
                  // handler above: it must not fight the day timeline's own scroll.
                  if (!allDay && draggable)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPressStart: (_) => onResizeStart!(),
                      onLongPressMoveUpdate: (d) =>
                          onResizeUpdate!(d.offsetFromOrigin.dy),
                      onLongPressEnd: (_) => onResizeEnd!(),
                      child: SizedBox(
                        height: 16,
                        child: Center(
                          child: Container(
                            width: 28,
                            height: 3,
                            decoration: BoxDecoration(
                              color: palette.inkFaint,
                              borderRadius: AppRadius.allPill,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardMd,
                  border: Border.all(color: _darken(accent, 0.18)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.l10n});
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.bedtime_outlined, size: 40, color: palette.inkFaint),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.dayEmpty, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.dayAddHint,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.inkFaint),
          ),
        ],
      ),
    );
  }
}
