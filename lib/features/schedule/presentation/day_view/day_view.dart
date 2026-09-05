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

  /// Extra room reserved below the 24 hour rows for a closing "오전 12시"
  /// (자정/midnight) boundary line — see week_view.dart's own copy of this
  /// constant for the full reasoning; kept as a matching, separately-tuned
  /// value here since this file's own hourHeight/font differ from week's.
  static const double _endOfDayHeight = 24;

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

    if (widget.compact) {
      // Compact instances (MonthView's embedded mini day view) skip the
      // pager entirely — they're a preview, not a navigable view of their
      // own, and don't share a selectedDateProvider swipe convention with
      // anything else on screen.
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xs,
          AppSpacing.gutter,
          140,
        ),
        children: [
          _DayContent(day: widget.day, compact: true),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            l10n.todosSectionTitle,
            trailing: IconButton(
              tooltip: l10n.todoAdd,
              onPressed: _focusAddTodo,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.add, size: 20, color: context.palette.inkFaint),
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
    }

    // A fixed height (PageView needs one) reserved for the *currently
    // settled* day's own content — an empty day (_EmptyDay) needs far
    // less than a populated one (the full 24-hour timeline). An adjacent
    // day peeked at mid-drag may genuinely need a different actual
    // height; _DayContent wraps each page in its own SingleChildScrollView
    // so a taller peek is just scrollable-but-clipped rather than
    // overflowing, and a shorter one just leaves blank space below —
    // once the swipe settles, this recomputes for the new day and the
    // box resizes to fit it exactly. Clock-mode days reserve the same
    // (timeline-height) box even though the dial+legend are usually
    // shorter — accepted as a minor over-reservation rather than adding
    // the complexity of measuring that mode's own (screen-width-
    // dependent) height.
    final eventsAsync = ref.watch(eventsForDayProvider(widget.day));
    final pagerHeight = switch (eventsAsync.asData?.value) {
      null => DayView._hourHeight * 24 + DayView._endOfDayHeight,
      final events when events.isEmpty => _DayContent.emptyContentHeight,
      _ => DayView._hourHeight * 24 + DayView._endOfDayHeight,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xs,
        AppSpacing.gutter,
        140,
      ),
      children: [
        SizedBox(
          height: pagerHeight,
          child: _DayContentPager(
            day: widget.day,
            onDayChanged: (newDay) =>
                ref.read(selectedDateProvider.notifier).select(newDay),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          l10n.todosSectionTitle,
          trailing: IconButton(
            tooltip: l10n.todoAdd,
            onPressed: _focusAddTodo,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.add, size: 20, color: context.palette.inkFaint),
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
  }
}

/// Pages a full [_DayContent] (all-day cards + empty-state/clock/timeline)
/// through a real, physically-dragged [PageView] — prev/current/next day,
/// one per page — instead of a plain gesture detector that only jumps
/// discretely once a swipe completes. Same shape as week_view.dart's
/// `_WeekPager`/year_view.dart's `_YearPager`; see either's own doc for why
/// a full [PageView] (rather than a simpler distance/velocity detector)
/// gives the "follows the finger, then magnet-snaps" feel this exists for.
///
/// [day] is the source of truth from outside (derived from
/// [SelectedDate], which the "오늘" button, the schedule title's own
/// swipe, and this pager's [onDayChanged] can all change). The page index
/// itself is just an arbitrary large offset — [_currentPage] and
/// [_pageDay] are kept in lockstep so a page number can always be
/// converted back to the real day it represents ([_dayForPage]), without
/// needing every possible day to have one fixed, pre-assigned page
/// number.
class _DayContentPager extends StatefulWidget {
  const _DayContentPager({required this.day, required this.onDayChanged});

  final DateTime day;
  final ValueChanged<DateTime> onDayChanged;

  // ~550 years either side of startup — plenty, and PageView needs a
  // finite itemCount rather than true unbounded paging.
  static const int _pageCount = 200000;
  static const int _initialPage = _pageCount ~/ 2;

  @override
  State<_DayContentPager> createState() => _DayContentPagerState();
}

class _DayContentPagerState extends State<_DayContentPager> {
  late final PageController _controller;
  late int _currentPage;
  late DateTime _pageDay;

  @override
  void initState() {
    super.initState();
    _currentPage = _DayContentPager._initialPage;
    _pageDay = widget.day;
    _controller = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant _DayContentPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.day == _pageDay) return;
    // day changed from outside this pager's own onPageChanged (the "오늘"
    // button, the schedule title's own swipe, ...) — resync the
    // controller to match instead of leaving it pointing at a stale day.
    final deltaDays = widget.day.difference(_pageDay).inDays;
    final targetPage = _currentPage + deltaDays;
    _currentPage = targetPage;
    _pageDay = widget.day;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpToPage(targetPage);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _dayForPage(int page) =>
      addCalendarDays(_pageDay, page - _currentPage);

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      key: const Key('dayContentSwipe'),
      controller: _controller,
      itemCount: _DayContentPager._pageCount,
      onPageChanged: (page) {
        final newDay = _dayForPage(page);
        _currentPage = page;
        _pageDay = newDay;
        widget.onDayChanged(newDay);
      },
      itemBuilder: (context, page) =>
          _DayContent(day: _dayForPage(page), scrollable: true),
    );
  }
}

/// Everything above the to-do section for one day — all-day cards plus
/// the empty-state/clock/timeline body. Used two ways: directly, as a
/// plain (unbounded-height) [ListView] item for the compact (MonthView-
/// embedded) case; and with [scrollable] set, as one page of
/// [_DayContentPager], where it sits inside a fixed-height [SizedBox] and
/// needs its own [SingleChildScrollView] to safely absorb a mismatch
/// between that reserved height and this specific day's actual content
/// height (see [DayView.build]'s own doc on why that height is only an
/// approximation for a peeked, not-yet-settled day).
class _DayContent extends ConsumerWidget {
  const _DayContent({
    required this.day,
    this.compact = false,
    this.scrollable = false,
  });

  final DateTime day;
  final bool compact;
  final bool scrollable;

  /// Close enough to _EmptyDay's own rendered height for
  /// [DayView.build]'s pager-height reservation — see that doc.
  static const double emptyContentHeight = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final eventsAsync = ref.watch(eventsForDayProvider(day));
    final now = DateTime.now();
    final isToday = dateOnly(now) == dateOnly(day);
    final layoutMode = compact
        ? DayViewLayoutMode.timeline
        : ref.watch(dayViewLayoutModeProvider);

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (events) {
        final timed = events.where((e) => !e.isAllDay).toList();
        final allDay = events.where((e) => e.isAllDay).toList();

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              _EmptyDay(l10n: l10n, compact: compact)
            else if (layoutMode == DayViewLayoutMode.clock) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DayClockView(
                    day: day,
                    events: timed,
                    isToday: isToday,
                    now: now,
                    locale: locale,
                  ),
                ),
              ),
              // The dial itself carries no title text — see DayClockView's
              // own doc — so this plain list is where a title actually
              // gets read.
              if (timed.isNotEmpty)
                DayClockLegend(events: timed, locale: locale),
            ] else
              SizedBox(
                // + _endOfDayHeight matches the outer pagerHeight reserved
                // for this same branch in DayView.build() exactly — keeping
                // them equal is what keeps this SingleChildScrollView inert
                // (content height == viewport height, so it never gains
                // scroll extent of its own) — see this file's own doc on
                // why that matters for the *outer* list this sits inside.
                height: DayView._hourHeight * 24 + DayView._endOfDayHeight,
                child: _Timeline(
                  day: day,
                  events: timed,
                  isToday: isToday,
                  now: now,
                  locale: locale,
                  hourHeight: DayView._hourHeight,
                  railInset: DayView._railInset,
                  endOfDayHeight: DayView._endOfDayHeight,
                  accent: palette.accent,
                ),
              ),
          ],
        );

        // NOT padded to match the timeline's own 00시-label shift (see
        // _Timeline's hour-label doc) — this scrollable is nested *inside*
        // DayView's own outer ListView (the thing that actually scrolls a
        // full day into view; this one's content normally fits its
        // reserved height exactly, so it's otherwise inert and just lets
        // vertical drags fall through to that outer list). Padding it, even
        // by a few px, gives it real scroll extent of its own — and once a
        // nested same-axis scrollable has ANY extent, it captures the drag
        // for itself instead of deferring to the outer one, which killed
        // the outer list's scrolling entirely (confirmed live: the whole
        // day got stuck unscrollable, hiding everything past whatever the
        // initial viewport height happened to show). _Timeline's own fix
        // (skip the shift for h == 0) avoids needing any padding here at
        // all.
        return scrollable ? SingleChildScrollView(child: content) : content;
      },
    );
  }
}

class _Timeline extends ConsumerStatefulWidget {
  const _Timeline({
    required this.day,
    required this.events,
    required this.isToday,
    required this.now,
    required this.locale,
    required this.hourHeight,
    required this.railInset,
    required this.endOfDayHeight,
    required this.accent,
  });

  final DateTime day;
  final List<EventRow> events;
  final bool isToday;
  final DateTime now;
  final String locale;
  final double hourHeight;
  final double railInset;
  final double endOfDayHeight;
  final Color accent;

  @override
  ConsumerState<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<_Timeline>
    with WidgetsBindingObserver {
  /// The shortest an event card is ever drawn, regardless of its actual
  /// duration — below this, its title/time text don't fit without
  /// clipping. Empirically the smallest that comfortably fits both text
  /// lines at this card's padding/type scale. Lower than it was before the
  /// resize grip was removed entirely (it used to also budget 16px for
  /// that) — the whole point of retuning this down is that a card no
  /// longer needs to stretch past its own true duration just to make room
  /// for a control that isn't there anymore, which used to read as the
  /// event's end time being wrong.
  static const double _minEventCardHeight = 64;

  /// Extra headroom [_minEventCardHeight] needs when the card also renders
  /// a location row — without this, a short (clamped-to-minimum) event that
  /// has a location set overflows its own card: `_minEventCardHeight` was
  /// tuned for title+time only, one row short of what a card with a
  /// location actually renders. Found by manually creating a 1-hour event
  /// with a location and watching it throw a real (not just debug-banner)
  /// "RenderFlex overflowed by 10.0 pixels" — a location row is genuinely
  /// missing from the space budget, not a cosmetic sliver.
  static const double _locationRowExtraHeight = 20;

  /// Extra headroom for a card sharing its time slot with others (see
  /// [cascadeEvents]) — its column is only a fraction of the full timeline
  /// width, so a title that would fit on one line at full width often
  /// doesn't at that narrower width. `_EventCard`'s title allows a 2nd line
  /// for exactly this case; this is the height that 2nd line needs, so it
  /// wraps into real space instead of overflowing the card.
  static const double _crowdedColumnExtraHeight = 22;

  double _minHeightFor(EventRow e, {bool crowded = false}) =>
      _minEventCardHeight +
      (crowded ? _crowdedColumnExtraHeight : 0) +
      ((e.location?.isNotEmpty ?? false) ? _locationRowExtraHeight : 0);

  /// The floor used instead of [_minHeightFor] when a card would otherwise
  /// have to stretch into the very next event's own card (see
  /// [_nextStartOnOrAfter]) — e.g. two plain back-to-back 1-hour events,
  /// each too short on its own to clear [_minEventCardHeight] but sharing
  /// no time at all, used to both hit that floor and paint 16px into each
  /// other. `_EventCard.tight` drops the location row to fit the title and
  /// time-range line within this smaller budget — found, like
  /// [_locationRowExtraHeight], by watching for a real "RenderFlex
  /// overflowed" exception rather than guessed.
  static const double _tightEventCardHeight = 60;

  /// The earliest start time among [widget.events] (other than the one
  /// with [excludingId]) that falls at or after [time] — used to stop a
  /// short card's minimum-height floor from stretching down past where
  /// the next event's own card actually begins. See [_tightEventCardHeight].
  DateTime? _nextStartOnOrAfter(DateTime time, String excludingId) {
    DateTime? best;
    for (final other in widget.events) {
      if (other.id == excludingId) continue;
      if (!other.startAt.isBefore(time) &&
          (best == null || other.startAt.isBefore(best))) {
        best = other.startAt;
      }
    }
    return best;
  }

  /// The event currently being dragged, if any — only one card can drag at a
  /// time since drags are single-pointer gestures.
  String? _draggingId;

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

  /// A long-press-drag (move/create) that's already been *accepted*
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
        _createAnchorY == null &&
        _createCurrentY == null) {
      return;
    }
    setState(() {
      _draggingId = null;
      _dragPixels = 0;
      _createAnchorY = null;
      _createCurrentY = null;
    });
  }

  /// Pixel offset from the top of the timeline for [t]. Computed as minutes
  /// elapsed since [widget.day]'s midnight rather than `t.hour * 60 +
  /// t.minute` — the latter reads midnight-of-the-*next*-day (exactly what a
  /// drag clamps an end time to when pushed past the bottom of the
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
  /// can never drag itself out of the timeline it's shown in. Shifts both
  /// ends by the same amount, preserving the event's own duration — moving
  /// is the only drag gesture a card has (see [_EventCard.onMoveStart]'s
  /// doc for why resizing this way was dropped).
  (DateTime start, DateTime end) _effectiveTimes(EventRow e) {
    if (_draggingId != e.id) {
      return (e.startAt, e.endAt);
    }
    final dayStart = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
    );
    final dayEnd = addCalendarDays(dayStart, 1);
    final delta = Duration(minutes: _snappedDeltaMinutes);

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
  }

  void _startDrag(String eventId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _draggingId = eventId;
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
                      //
                      // h == 0 skips the shift — see this file's own
                      // _DayContent doc for why matching top padding on the
                      // scrollable isn't an option here (it breaks the
                      // outer list's scrolling instead), leaving 00시's
                      // label sitting a few px lower than every other
                      // hour's — barely perceptible, and the only row where
                      // it's needed at all.
                      Transform.translate(
                        offset: Offset(0, h == 0 ? 0 : -7),
                        child: SizedBox(
                          // AppSpacing.xxs, not .sm — a double-digit hour
                          // ("오전 12시", "오후 10/11/12시") needs close to
                          // the full rail width at this 12sp size; .sm's
                          // wider margin wrapped every one of them onto 2
                          // lines (they still fit, just uglier, so this was
                          // never a clipping bug — week_view.dart's own
                          // copy uses a smaller 11sp label and never
                          // wrapped, hence no matching change there).
                          width: widget.railInset - AppSpacing.xxs,
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

            // The closing "오전 12시" boundary — same label as the very
            // top (00시 and 24시 are the same instant), sitting in the
            // dedicated endOfDayHeight strip below the last real hour row
            // rather than borrowing space from it, so it needs none of
            // 00시's own shift-skipping trick above: this box has real
            // room of its own to begin with.
            Positioned(
              top: widget.hourHeight * 24,
              left: 0,
              right: 0,
              child: SizedBox(
                height: widget.endOfDayHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: widget.railInset - AppSpacing.xxs,
                      child: Text(
                        Fmt.hour(0, widget.locale, use24Hour: use24),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: palette.inkFaint,
                              fontFeatures: null,
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
                  // the title and time without clipping — short events
                  // already visually extend a bit past their true span for
                  // this reason (the same trade-off Google Calendar and
                  // friends make), it's just precomputed here now instead
                  // of left to grow reactively.
                  final rawHeight = (_offsetFor(end) - _offsetFor(start)).clamp(
                    0.0,
                    widget.hourHeight * 24,
                  );
                  final minHeight = _minHeightFor(
                    e,
                    crowded: c.columnCount > 1,
                  );
                  // ...but that floor must never paint over the very next
                  // event's own card: when stretching all the way to
                  // minHeight would reach past it, drop to the smaller
                  // _tightEventCardHeight budget instead (see its doc),
                  // which _EventCard.tight then actually renders within by
                  // dropping the location row's own minHeight-budgeted
                  // room for. That smaller floor can still overlap the
                  // next card a little when the two are separated by less
                  // than _tightEventCardHeight itself (a pair of very
                  // short, e.g. 15-20 minute, back-to-back events) —
                  // bounded and far smaller than minHeight's own overlap
                  // would have been, rather than shrinking the
                  // card below the height its own (already-reduced)
                  // content needs to avoid overflowing.
                  final nextStart = _nextStartOnOrAfter(end, e.id);
                  final availableUntilNext = nextStart == null
                      ? null
                      : _offsetFor(nextStart) - _offsetFor(start);
                  final tight =
                      availableUntilNext != null &&
                      availableUntilNext < minHeight;
                  final cappedMinHeight = tight
                      ? _tightEventCardHeight
                      : minHeight;
                  final height = rawHeight < cappedMinHeight
                      ? cappedMinHeight
                      : rawHeight;
                  // A mirrored event (holiday or subscribed-calendar) stays
                  // read-only here the same way tapping it already routes to
                  // MirroredEventDetailScreen instead of the editor — drag
                  // is just another way to edit it, and letting it through
                  // used to silently push a duplicate to the device
                  // calendar (see EventRepositoryImpl._applySideEffects's
                  // own doc on this exact path).
                  final draggable = e.importSourceCalendarId == null;
                  return Positioned(
                    top: _offsetFor(start),
                    left: widget.railInset + leftInset,
                    right: rightInset,
                    height: height,
                    child: _EventCard(
                      event: e,
                      allDay: false,
                      height: height,
                      tight: tight,
                      isDragging: isDragging,
                      onMoveStart: draggable ? () => _startDrag(e.id) : null,
                      onMoveUpdate: _updateDrag,
                      onMoveEnd: () => _endDrag(e),
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
    this.tight = false,
    this.isDragging = false,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
  });

  final EventRow event;
  final bool allDay;

  /// The timeline's own computed pixel height for this card — null for the
  /// all-day strip, which sizes itself to its content instead.
  final double? height;

  /// Set when [_TimelineState] had to shrink this card's floor to
  /// `_tightEventCardHeight` because the next event's own card would
  /// otherwise have been painted over (see that constant's doc). Drops the
  /// location row and caps the title to 1 line instead of 2, keeping
  /// title, time-range and notify icon — the content set that smaller
  /// budget was tuned for.
  final bool tight;
  final bool isDragging;

  /// Dragging the card body moves the whole event, preserving its
  /// duration — the only drag gesture a card has. An earlier version also
  /// let a bottom-edge grip resize just the end time; removed for being
  /// inconsistently available (only cards with room to spare — i.e. not
  /// immediately followed by another event, see [tight] — could show it
  /// at all, so most cards never had it) rather than dropped for every
  /// card alike. Resizing is still possible through the editor sheet
  /// (tap the card) — this only removed the drag shortcut.
  final VoidCallback? onMoveStart;
  final ValueChanged<double>? onMoveUpdate;
  final VoidCallback? onMoveEnd;

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
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );

    // No swipe-to-delete here (an earlier version had one, hand-rolled
    // rather than via Dismissible for a GlassSurface/BackdropFilter sizing
    // bug — see git history if that's ever needed again) — deleting now
    // lives in the edit sheet's own delete button (tap the card to reach
    // it), freeing the whole all-day/timeline area to be a horizontal-drag
    // *navigation* surface instead (see `_DayContentPager`, which this
    // card sits inside) without the two competing for the same gesture.
    return GestureDetector(
      // Tapping anywhere on the card — not just the title/time text — opens
      // it for editing.
      onTap: () => showEventEditor(context, existing: event),
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
                              // 2, not 1: a card sharing its time slot with
                              // others (see cascadeEvents) only gets a
                              // fraction of the timeline's width, so a title
                              // that reads fine at full width often doesn't
                              // in that narrow column — letting it wrap
                              // downward instead of just clipping
                              // sideways uses the card's own height, which
                              // _minHeightFor already budgets extra room for
                              // in that case (see _crowdedColumnExtraHeight).
                              // tight has no such extra room to give (it's
                              // the smaller, next-event-constrained budget —
                              // see [tight]'s doc), so it stays at 1 there
                              // even when also crowded, rather than
                              // overflowing the tighter card.
                              maxLines: tight ? 1 : 2,
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
                            if (!tight &&
                                event.location != null &&
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
  const _EmptyDay({required this.l10n, this.compact = false});
  final AppL10n l10n;

  /// Set by [DayView]'s `compact` instance (MonthView's embedded panel).
  /// The full icon+title+hint block below is sized for a whole dedicated
  /// screen — inside the month grid's cramped, draggable day panel it alone
  /// could exceed the panel's entire minimum height (`_monthMinDayViewHeight`
  /// in month_view.dart), pushing the to-dos section that follows it below
  /// the fold on a day with no events. Compact mode swaps it for one small
  /// line of faint text, matching the "+" hint's own font size — enough to
  /// explain the empty state without competing with content that actually
  /// needs the room.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          l10n.dayEmpty,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: palette.inkFaint),
        ),
      );
    }
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
