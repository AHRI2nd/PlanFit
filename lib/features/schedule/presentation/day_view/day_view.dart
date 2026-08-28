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

/// The signature view: a day laid out as a vertical river of hours, with events
/// as glass cards floating over the time-of-day gradient, plus the day's to-dos.
class DayView extends ConsumerWidget {
  const DayView({super.key, required this.day});

  final DateTime day;

  static const double _hourHeight = 64;
  static const double _railInset = 62;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final eventsAsync = ref.watch(eventsForDayProvider(day));
    final now = DateTime.now();
    final isToday = dateOnly(now) == dateOnly(day);

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
            else
              SizedBox(
                height: _hourHeight * 24,
                child: _Timeline(
                  day: day,
                  events: timed,
                  isToday: isToday,
                  now: now,
                  locale: locale,
                  hourHeight: _hourHeight,
                  railInset: _railInset,
                  accent: palette.accent,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(l10n.todosSectionTitle),
            HourlyTodoList(day: day),
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

class _TimelineState extends ConsumerState<_Timeline> with WidgetsBindingObserver {
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
        // Divides however many events share one overlap cluster evenly
        // across the available width — see cascadeEvents' doc and the
        // per-card inset math below for why W/(siblingCount+1) is the step
        // that gives every card in an N-way cluster the same width,
        // 2W/(N+1), rather than a fixed pixel offset that reads fine for
        // two cards but leaves a 3rd/4th nearly fully hidden.
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
                  SizedBox(
                    width: widget.railInset - AppSpacing.sm,
                    child: Text(
                      Fmt.hour(h, widget.locale, use24Hour: use24),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: palette.inkFaint,
                        fontFeatures: null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 7),
                      height: 1,
                      color: palette.hairline,
                    ),
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
                (_offsetFor(pendingCreate.$2) - _offsetFor(pendingCreate.$1))
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

        // Event cards positioned by start time. Duration sets a *minimum*
        // height only — the card is left free to grow past that so its
        // title/time text never gets clipped for short events, where the
        // duration-derived height is too small to fit two lines of text.
        //
        // Cascaded by [cascadeEvents] on each card's own persisted (not
        // drag-in-progress) start/end, so two events at the same time fan
        // out horizontally instead of one completely covering the other —
        // deliberately not recomputed against the live drag preview, since
        // reshuffling every other card's cascade offset mid-drag would be
        // distracting for what's a rare edge case to begin with.
        for (final c in cascadeEvents(widget.events))
          Builder(
            builder: (context) {
              final e = c.event;
              final (start, end) = _effectiveTimes(e);
              final isDragging = _draggingId == e.id;
              final step = c.siblingCount <= 1
                  ? 0.0
                  : availableWidth / (c.siblingCount + 1);
              final leftInset = c.index * step;
              final rightInset = (c.siblingCount - 1 - c.index) * step;
              return Positioned(
                top: _offsetFor(start) + 2,
                left: widget.railInset + leftInset,
                right: rightInset,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (_offsetFor(end) - _offsetFor(start)).clamp(
                        0,
                        widget.hourHeight * 24,
                      ),
                    ),
                    child: _EventCard(
                      event: e,
                      allDay: false,
                      isDragging: isDragging,
                      onMoveStart: () => _startDrag(e.id, _DragMode.move),
                      onMoveUpdate: _updateDrag,
                      onMoveEnd: () => _endDrag(e),
                      onResizeStart: () => _startDrag(e.id, _DragMode.resize),
                      onResizeUpdate: _updateDrag,
                      onResizeEnd: () => _endDrag(e),
                    ),
                  ),
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

    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 3),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.danger.withValues(alpha: 0.16),
          borderRadius: AppRadius.cardMd,
        ),
        child: Icon(Icons.delete_outline, color: palette.danger),
      ),
      onDismissed: (_) => _delete(context, ref),
      child: GlassSurface(
        borderRadius: AppRadius.cardMd,
        tint: accent.withValues(
          alpha: (palette.isDark ? 0.22 : 0.16) * (isDragging ? 1.6 : 1.0),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => showEventEditor(context, existing: event),
              // Long-press-then-drag (not a plain vertical drag) so a swipe
              // that starts on top of a card still scrolls the day timeline
              // instead of picking the event up — the two would otherwise
              // both claim the same vertical pan gesture.
              onLongPressStart: onMoveStart == null
                  ? null
                  : (_) => onMoveStart!(),
              onLongPressMoveUpdate: onMoveUpdate == null
                  ? null
                  : (d) => onMoveUpdate!(d.offsetFromOrigin.dy),
              onLongPressEnd: onMoveEnd == null ? null : (_) => onMoveEnd!(),
              child: Row(
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
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette.inkFaint,
                                  ),
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
            ),
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
