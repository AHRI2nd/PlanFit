import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date_math.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/format.dart';
import '../../../../core/time_format.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../todo/application/todo_providers.dart';
import '../../application/schedule_providers.dart';
import '../../domain/calendar_dot.dart';
import '../../domain/drag_create.dart';
import '../../domain/event_overlap.dart';
import '../../domain/event_span.dart';
import '../event_edit/event_editor_sheet.dart';

// The narrowest a cascaded (overlapping-events) card is ever drawn — below
// this, there's so little width left per card that even a single line of
// title text barely fits, and a 2nd wrapped line (see the Text below) was
// found to silently fail to paint at all on this width range specifically
// (confirmed live: layout metrics reported two lines correctly, but only
// the first one actually rendered, with no visible ellipsis either).
// Crowded columns are widened up to this floor and overlapped evenly
// within their own day instead, the same "short events already extend a
// bit past their true span" trade-off day_view.dart's own
// _minEventCardHeight doc describes, just along the width axis here.
const double _minWeekEventWidth = 34.0;

/// A 7-day grid: hours down the rail, one column per day, events positioned
/// by day + time-of-day — the zoomed-out counterpart to [DayView]'s single
/// column. No existing-event drag/resize (unlike the day view): tapping an
/// event opens it for editing, tapping a day's header jumps into that day's
/// own [DayView] for finer-grained interactions, and a long-press-drag on
/// empty grid space creates a new event spanning the dragged range. The
/// whole page (header, all-day strip, and hour grid together) is itself a
/// swipeable page — see [_WeekPager].
class WeekView extends ConsumerWidget {
  const WeekView({super.key, required this.anchor});

  final DateTime anchor;

  static const double _hourHeight = 48;
  static const double _railInset = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startWeekday = ref.watch(weekStartWeekdayProvider);
    final weekStart = startOfWeek(anchor, startWeekday: startWeekday);
    return _WeekPager(
      weekStart: weekStart,
      // Lands on the same day-of-week the pager started from (e.g. swiping
      // from a Tuesday lands on the next week's Tuesday), not always that
      // week's Monday — matches how schedule_screen.dart's own title swipe
      // already navigates week view (`addCalendarDays(selected, ±7)`, off
      // the raw anchor), so every swipe entry point always agrees.
      onWeekChanged: (newWeekStart) => ref
          .read(selectedDateProvider.notifier)
          .select(
            addCalendarDays(newWeekStart, anchor.difference(weekStart).inDays),
          ),
    );
  }
}

/// Pages a full [_WeekPageContent] (header, all-day strip, and hour grid
/// together) through a real, physically-dragged [PageView] — prev/current/
/// next week, one per page — instead of a plain gesture detector that only
/// jumps discretely once a swipe completes. [PageView]'s own default
/// [PageScrollPhysics] already gives exactly the "follows the finger, then
/// magnet-snaps to the nearer page" feel this exists for, so none of that
/// needs reimplementing here.
///
/// Safe to wrap the *whole* page, not just the header (an earlier version
/// of this only wrapped the header) — the grid below has a long-press-drag
/// gesture for creating events, not a plain one, and a genuine long-press
/// wins Flutter's gesture arena during its hold phase (no horizontal
/// movement has happened yet for a drag recognizer to compete over), so it
/// never fights this pager's own horizontal [PageView] drag. Tapping a day
/// cell (header or grid) still works the same way, since a tap has ~zero
/// drag distance.
///
/// [weekStart] is the source of truth from outside (derived from
/// [SelectedDate], which the "오늘" button, the schedule title's own
/// swipe, and this pager's [onWeekChanged] can all change). The page index
/// itself is just an arbitrary large offset — [_currentPage] and
/// [_pageWeekStart] are kept in lockstep so a page number can always be
/// converted back to the real week it represents ([_weekStartForPage]),
/// without needing every possible week to have one fixed, pre-assigned page
/// number.
class _WeekPager extends StatefulWidget {
  const _WeekPager({required this.weekStart, required this.onWeekChanged});

  final DateTime weekStart;
  final ValueChanged<DateTime> onWeekChanged;

  // A fixed, generously wide page range (~960 years either side of
  // startup) rather than true unbounded paging — PageView needs a finite
  // itemCount, and no realistic use of this app gets anywhere near this
  // edge.
  static const int _pageCount = 100000;
  static const int _initialPage = _pageCount ~/ 2;

  @override
  State<_WeekPager> createState() => _WeekPagerState();
}

class _WeekPagerState extends State<_WeekPager> {
  late final PageController _controller;
  late int _currentPage;
  late DateTime _pageWeekStart;

  @override
  void initState() {
    super.initState();
    _currentPage = _WeekPager._initialPage;
    _pageWeekStart = widget.weekStart;
    _controller = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant _WeekPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weekStart == _pageWeekStart) return;
    // weekStart changed from outside this pager's own onPageChanged (the
    // "오늘" button, the schedule title's own swipe, ...) — resync the
    // controller to match instead of leaving it pointing at a stale week.
    final deltaWeeks = widget.weekStart.difference(_pageWeekStart).inDays ~/ 7;
    final targetPage = _currentPage + deltaWeeks;
    _currentPage = targetPage;
    _pageWeekStart = widget.weekStart;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpToPage(targetPage);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _weekStartForPage(int page) =>
      addCalendarDays(_pageWeekStart, (page - _currentPage) * 7);

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      key: const Key('weekPageSwipe'),
      controller: _controller,
      itemCount: _WeekPager._pageCount,
      onPageChanged: (page) {
        final newWeekStart = _weekStartForPage(page);
        _currentPage = page;
        _pageWeekStart = newWeekStart;
        widget.onWeekChanged(newWeekStart);
      },
      itemBuilder: (context, page) =>
          _WeekPageContent(weekStart: _weekStartForPage(page)),
    );
  }
}

/// One week's full content — everything [WeekView] used to build directly,
/// just keyed by an explicit [weekStart] (rather than reading
/// [selectedDateProvider] itself) so [_WeekPager] can render several
/// different weeks' worth of these as sibling pages.
class _WeekPageContent extends ConsumerWidget {
  const _WeekPageContent({required this.weekStart});

  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekEnd = addCalendarDays(weekStart, 7);
    final days = [for (var i = 0; i < 7; i++) addCalendarDays(weekStart, i)];
    final eventsAsync = ref.watch(eventsForWeekProvider(weekStart));
    final weekTodos =
        ref.watch(todosForWeekProvider(weekStart)).asData?.value ??
        const <TodoRow>[];
    final overdueTodos =
        ref.watch(overdueTodosProvider).asData?.value ?? const <TodoRow>[];
    final now = DateTime.now();
    final today = dateOnly(now);
    // Per calendar_dot.dart's shared rule — scoped to just this week's 7
    // days, unlike overdueTodosProvider itself (app-wide, unscoped).
    final overdueDays = {for (final t in overdueTodos) dateOnly(t.slotStart)}
      ..retainWhere(days.contains);
    final todoDays = {
      for (final t in weekTodos)
        if (!t.isDone) dateOnly(t.slotStart),
    }..removeAll(overdueDays);
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );

    void openDay(DateTime day) {
      ref.read(selectedDateProvider.notifier).select(day);
      ref.read(scheduleViewProvider.notifier).set(ScheduleView.day);
    }

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (events) {
        final allDay = events.where((e) => e.isAllDay).toList();
        final timed = events.where((e) => !e.isAllDay).toList();
        final byDay = <DateTime, List<EventRow>>{for (final d in days) d: []};
        for (final e in timed) {
          final d = dateOnly(e.startAt);
          byDay[d]?.add(e);
        }
        // Both all-day and timed events count toward "this day has an
        // event" — the header dot doesn't distinguish the two the way the
        // all-day strip below it does.
        final eventDays = {for (final e in events) dateOnly(e.startAt)};

        return Column(
          children: [
            _WeekHeader(
              days: days,
              today: today,
              locale: locale,
              accent: palette.accent,
              eventDays: eventDays,
              todoDays: todoDays,
              overdueDays: overdueDays,
              onTapDay: openDay,
            ),
            if (allDay.isNotEmpty)
              _AllDayStrip(
                days: days,
                weekStart: weekStart,
                weekEnd: weekEnd,
                events: allDay,
                railInset: WeekView._railInset,
              ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: SizedBox(
                  height: WeekView._hourHeight * 24,
                  child: _WeekGrid(
                    days: days,
                    today: today,
                    now: now,
                    byDay: byDay,
                    locale: locale,
                    hourHeight: WeekView._hourHeight,
                    railInset: WeekView._railInset,
                    accent: palette.accent,
                    onTapDay: openDay,
                    use24Hour: use24,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.days,
    required this.today,
    required this.locale,
    required this.accent,
    required this.eventDays,
    required this.todoDays,
    required this.overdueDays,
    required this.onTapDay,
  });

  final List<DateTime> days;
  final DateTime today;
  final String locale;
  final Color accent;
  final Set<DateTime> eventDays;
  final Set<DateTime> todoDays;
  final Set<DateTime> overdueDays;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          const SizedBox(width: WeekView._railInset),
          for (final day in days)
            Expanded(
              child: GestureDetector(
                onTap: () => onTapDay(day),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Text(
                      Fmt.weekdayShort(day, locale),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.inkFaint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Same marker language every other calendar surface
                    // uses — see calendar_dot.dart's shared rule. This
                    // view had none before.
                    SizedBox(
                      height: 6,
                      child: Builder(
                        builder: (context) {
                          final dotColor = calendarDotColor(
                            palette: palette,
                            hasEvent: eventDays.contains(day),
                            hasTodo: todoDays.contains(day),
                            hasOverdueTodo: overdueDays.contains(day),
                          );
                          if (dotColor == null) return const SizedBox.shrink();
                          return Center(
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: day == today ? accent : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: day == today ? Colors.white : null,
                          fontWeight: day == today ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small colored bars for all-day events, spanning every day column they
/// touch within the visible week — rounded only on the true start/end of
/// the event's own span (via [eventDaysInRange]) so an event that runs past
/// this week's edges reads as continuing off-screen rather than ending here.
class _AllDayStrip extends StatelessWidget {
  const _AllDayStrip({
    required this.days,
    required this.weekStart,
    required this.weekEnd,
    required this.events,
    required this.railInset,
  });

  final List<DateTime> days;
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<EventRow> events;
  final double railInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: railInset),
          for (final day in days)
            Expanded(
              child: Column(
                children: [
                  for (final e in events)
                    if (eventDaysInRange(e, weekStart, weekEnd).contains(day))
                      Builder(
                        builder: (context) {
                          final span = eventDaysInRange(e, weekStart, weekEnd);
                          final isFirst = span.first == day;
                          final isLast = span.last == day;
                          final accent = EventColorTag.resolve(
                            e.colorTag,
                            e.startAt,
                          );
                          // Same tap target every other all-day/holiday bar
                          // in the app already has (DayView's own
                          // all-day _EventCard) — this strip was missing it
                          // entirely, so a holiday or all-day event was
                          // visible here but unopenable. showEventEditor
                          // itself routes a subscribed/holiday-mirrored
                          // event to its read-only detail screen instead of
                          // the editable form — see its own doc.
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                showEventEditor(context, existing: e),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 1),
                              height: 16,
                              padding: EdgeInsets.only(
                                left: isFirst ? AppSpacing.xxs : 0,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.horizontal(
                                  left: isFirst
                                      ? const Radius.circular(4)
                                      : Radius.zero,
                                  right: isLast
                                      ? const Radius.circular(4)
                                      : Radius.zero,
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              child: isFirst
                                  ? Text(
                                      e.title.isEmpty ? '—' : e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: accent),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatefulWidget {
  const _WeekGrid({
    required this.days,
    required this.today,
    required this.now,
    required this.byDay,
    required this.locale,
    required this.hourHeight,
    required this.railInset,
    required this.accent,
    required this.onTapDay,
    required this.use24Hour,
  });

  final List<DateTime> days;
  final DateTime today;
  final DateTime now;
  final Map<DateTime, List<EventRow>> byDay;
  final String locale;
  final double hourHeight;
  final double railInset;
  final Color accent;
  final ValueChanged<DateTime> onTapDay;
  final bool use24Hour;

  @override
  State<_WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<_WeekGrid> with WidgetsBindingObserver {
  /// Long-press-drag-to-create state, mirroring DayView's own — see its doc
  /// comment. [_createDayIndex] pins the drag to whichever column it started
  /// in even if the finger wanders sideways into a neighboring one.
  int? _createDayIndex;
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

  /// Same reasoning as DayView's _TimelineState.didChangeAppLifecycleState —
  /// a long-press-drag already in progress gets no onLongPressEnd/Cancel
  /// callback at all if interrupted by backgrounding, so the create-ghost
  /// would otherwise stay stuck rendered indefinitely.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    if (_createDayIndex == null &&
        _createAnchorY == null &&
        _createCurrentY == null) {
      return;
    }
    setState(() {
      _createDayIndex = null;
      _createAnchorY = null;
      _createCurrentY = null;
    });
  }

  double _offsetFor(DateTime dayStart, DateTime t) =>
      t.difference(dayStart).inMinutes / 60.0 * widget.hourHeight;

  void _startCreate(int dayIndex, double y) {
    HapticFeedback.mediumImpact();
    setState(() {
      _createDayIndex = dayIndex;
      _createAnchorY = y;
      _createCurrentY = y;
    });
  }

  void _updateCreate(double y) {
    setState(() => _createCurrentY = y);
  }

  (DateTime, DateTime)? get _pendingCreateRange {
    final dayIndex = _createDayIndex;
    final anchor = _createAnchorY;
    final current = _createCurrentY;
    if (dayIndex == null || anchor == null || current == null) return null;
    final day = widget.days[dayIndex];
    final dayStart = DateTime(day.year, day.month, day.day);
    return snappedCreateRange(
      dayStart,
      anchor,
      current,
      hourHeight: widget.hourHeight,
    );
  }

  Future<void> _endCreate() async {
    final dayIndex = _createDayIndex;
    final range = _pendingCreateRange;
    setState(() {
      _createDayIndex = null;
      _createAnchorY = null;
      _createCurrentY = null;
    });
    if (dayIndex == null || range == null) return;
    await showEventEditor(
      context,
      initialDay: widget.days[dayIndex],
      initialStart: range.$1,
      initialEnd: range.$2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final days = widget.days;
    final hourHeight = widget.hourHeight;
    final railInset = widget.railInset;
    final locale = widget.locale;
    final accent = widget.accent;
    final today = widget.today;
    final now = widget.now;
    final byDay = widget.byDay;
    final onTapDay = widget.onTapDay;
    final use24 = widget.use24Hour;
    final pendingCreate = _pendingCreateRange;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = (constraints.maxWidth - railInset) / days.length;
          return Stack(
            children: [
              // Hour gridlines + rail labels.
              for (int h = 0; h < 24; h++)
                Positioned(
                  top: h * hourHeight,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: hourHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shifted up to stay visually centered on the
                        // gridline below — see DayView's own hour-grid doc
                        // for why the line itself sits exactly at this
                        // row's top edge (h * hourHeight, matching
                        // _offsetFor) instead of carrying the margin,
                        // now that events are positioned by that same
                        // _offsetFor with no fudge factor of their own.
                        Transform.translate(
                          offset: const Offset(0, -6),
                          child: SizedBox(
                            width: railInset - AppSpacing.xxs,
                            child: Text(
                              Fmt.hour(h, locale, use24Hour: use24),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: palette.inkFaint),
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

              // One tap target per day column, behind the events. A plain tap
              // jumps into that day (the precise-editing surface); a
              // long-press-drag instead creates an event right here, spanning
              // the dragged range — same gesture DayView's own timeline uses,
              // so the two views behave consistently.
              for (var i = 0; i < days.length; i++)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: railInset + i * columnWidth,
                  width: columnWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => onTapDay(days[i]),
                    onLongPressStart: (d) =>
                        _startCreate(i, d.localPosition.dy),
                    onLongPressMoveUpdate: (d) =>
                        _updateCreate(d.localPosition.dy),
                    onLongPressEnd: (_) => _endCreate(),
                  ),
                ),

              // Live preview of the event being drag-created — see DayView's
              // own for why this (rather than opening the editor live) is the
              // feedback shown while the finger is still down.
              if (pendingCreate != null && _createDayIndex != null)
                Positioned(
                  top: _offsetFor(days[_createDayIndex!], pendingCreate.$1) + 1,
                  left: railInset + _createDayIndex! * columnWidth + 1,
                  width: (columnWidth - 2).clamp(0, columnWidth),
                  height:
                      (_offsetFor(days[_createDayIndex!], pendingCreate.$2) -
                              _offsetFor(
                                days[_createDayIndex!],
                                pendingCreate.$1,
                              ))
                          .clamp(0, hourHeight * 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22),
                      border: Border.all(color: accent, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

              // Events, positioned by day column + time. Laid out into
              // non-overlapping columns within each day column the same
              // way DayView lays out its own timeline — see cascadeEvents'
              // doc for why two events sharing a moment in time each get
              // their own exclusive slice of the width instead of one
              // painting over the other.
              for (var i = 0; i < days.length; i++)
                for (final c in cascadeEvents(byDay[days[i]] ?? const []))
                  Builder(
                    builder: (context) {
                      final e = c.event;
                      final columnAvailable = columnWidth - 2;
                      final naturalWidth = columnAvailable / c.columnCount;
                      // Below _minWeekEventWidth, widen the card up to that
                      // floor and overlap cascaded cards evenly within
                      // their own day column instead — see its own doc.
                      // This formula is exactly `column * naturalWidth`
                      // (the plain non-overlapping tiling) whenever the
                      // floor doesn't bind, so it only changes anything in
                      // the crowded case.
                      final eventWidth = naturalWidth < _minWeekEventWidth
                          ? _minWeekEventWidth
                          : naturalWidth;
                      final maxLeftInset = (columnAvailable - eventWidth)
                          .clamp(0.0, columnAvailable);
                      final leftInset = c.columnCount > 1
                          ? (c.column / (c.columnCount - 1)) * maxLeftInset
                          : 0.0;
                      return Positioned(
                        top: _offsetFor(days[i], e.startAt),
                        left: railInset + i * columnWidth + 1 + leftInset,
                        width: eventWidth.clamp(0.0, columnWidth),
                        child: GestureDetector(
                          onTap: () => showEventEditor(context, existing: e),
                          child: Container(
                            constraints: BoxConstraints(
                              minHeight:
                                  (_offsetFor(days[i], e.endAt) -
                                          _offsetFor(days[i], e.startAt))
                                      .clamp(14, hourHeight * 24),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: EventColorTag.resolve(
                                e.colorTag,
                                e.startAt,
                              ).withValues(alpha: palette.isDark ? 0.32 : 0.22),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              e.title.isEmpty ? '—' : e.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

              // "Now" indicator, only in today's column when today is in view.
              if (days.contains(today))
                Positioned(
                  top: _offsetFor(today, now) - 1,
                  left: railInset + days.indexOf(today) * columnWidth,
                  width: columnWidth,
                  child: Container(height: 2, color: accent),
                ),
            ],
          );
        },
      ),
    );
  }
}
