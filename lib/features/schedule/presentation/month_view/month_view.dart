import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/date_math.dart';
import '../../../../core/db/app_database.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../todo/application/todo_providers.dart';
import '../../application/schedule_providers.dart';
import '../../domain/calendar_dot.dart';
import '../../domain/event_span.dart';
import '../day_view/day_view.dart';

/// Number of week-rows [TableCalendar] renders for the month containing
/// [focusedDay], replicating its own internal `_getRowCount` (see
/// `table_calendar_base.dart`) so the split handle can convert a drag delta
/// in screen pixels into the matching per-row delta — without this, dragging
/// the handle by X pixels moves the boundary by X*rowCount pixels, since
/// every row grows by the same amount.
int monthRowCount(DateTime focusedDay, int startWeekday) {
  final first = DateTime(focusedDay.year, focusedDay.month, 1);
  final daysBefore = (first.weekday + 7 - startWeekday) % 7;
  final firstToDisplay = addCalendarDays(first, -daysBefore);

  final last = DateTime(focusedDay.year, focusedDay.month + 1, 0);
  final invertedStartWeekday = 8 - startWeekday;
  var daysAfter = 7 - ((last.weekday + invertedStartWeekday) % 7);
  if (daysAfter == 7) daysAfter = 0;
  final lastToDisplay = addCalendarDays(last, daysAfter);

  return (lastToDisplay.difference(firstToDisplay).inDays + 1) ~/ 7;
}

// table_calendar's own `daysOfWeekHeight` default — [MonthView] never
// overrides it, so this stays in lockstep with the actual rendered height.
const double _monthDowHeight = 16.0;

// [_MonthSplitHandle]'s own rendered height: 8+8 vertical padding, a 4px
// grip bar, an 8px gap, and a 1px divider.
const double _monthHandleHeight = 32.0;

// Floor reserved for [DayView] below the handle, so it's never squeezed to
// nothing even at the calendar's tallest allowed rowHeight.
const double _monthMinDayViewHeight = 96.0;

/// The tallest [MonthCalendarRowHeight] can go without the grid + handle
/// pushing [DayView] (and the handle itself) out of the viewport — see the
/// doc on [_MonthSplitHandle] for why an unbounded rowHeight let the handle
/// scroll itself below the visible area with no way back.
double maxMonthRowHeight({
  required double availableHeight,
  required int rowCount,
}) {
  if (rowCount <= 0) return MonthCalendarRowHeight.min;
  final reserved =
      _monthDowHeight + _monthHandleHeight + _monthMinDayViewHeight;
  final forRows = availableHeight - reserved;
  if (forRows <= 0) return MonthCalendarRowHeight.min;
  return (forRows / rowCount).clamp(
    MonthCalendarRowHeight.min,
    MonthCalendarRowHeight.max,
  );
}

// Height budgeted per event row in the expanded list — tuned for the tiny
// (9px) label style [MonthView] uses there, tight enough that 2-3 events
// still fit inside a reasonably-sized cell.
const double _monthEventRowHeight = 12.0;

// Small breathing room between the day-number circle and whatever sits
// below it (dot/bar summary or the expanded list), and between that content
// and the cell's own bottom edge. Shared by both the collapsed and expanded
// marker, and by monthDayNumberDiameter's own budget — see its doc.
const double _monthMarkerTopGap = 1.0;
const double _monthMarkerBottomPad = 1.0;

// The collapsed dot/bar summary's plain dot — also a named constant (not
// just a literal on the Container below) because monthDayNumberDiameter
// needs to budget room for exactly this size, not guess at it.
const double _monthCollapsedDotSize = 6.0;

/// The day-number circle's diameter at a given [rowHeight]/[columnWidth] —
/// capped by *both*, never just [rowHeight] alone. [MonthCalendarRowHeight]
/// ranges from [MonthCalendarRowHeight.min] to `.max`, but the grid's
/// column width barely moves (it only depends on screen width, not the
/// split-handle drag) — sizing the circle off [rowHeight] alone let it
/// stretch into a tall oval at the drag range's upper end and squash into a
/// short one at its lower end, instead of staying a circle either way.
///
/// The subtracted term also isn't just "a little breathing room": it's
/// sized so the collapsed dot/bar summary (or the expanded list — see
/// [monthEventListCapacity]) always has at least [_monthCollapsedDotSize]
/// of clearance below the circle, at every [rowHeight] down to
/// [MonthCalendarRowHeight.min]. A flat, smaller subtraction let the circle
/// grow large enough at the shortest allowed row that its own bottom edge
/// overlapped the dot sitting just underneath it.
double monthDayNumberDiameter({
  required double rowHeight,
  required double columnWidth,
}) {
  final reserved =
      2 * (_monthCollapsedDotSize + _monthMarkerTopGap + _monthMarkerBottomPad) +
      2; // +2: a little extra slack so the dot clears the circle, not just touches it.
  final capped = math.min(columnWidth - 12, rowHeight - reserved);
  return capped.clamp(20.0, 28.0);
}

/// Where the marker area (the collapsed dot/bar summary, or the expanded
/// list — see [monthEventListCapacity]) starts, in pixels from the cell's
/// own top edge — always right below [monthDayNumberDiameter]'s circle
/// plus a small gap, at every [rowHeight]. The single source of truth both
/// the collapsed and expanded branches in [MonthView] position themselves
/// against, so the two can never drift out of sync with each other.
double monthMarkerTop({required double rowHeight, required double columnWidth}) {
  final diameter = monthDayNumberDiameter(
    rowHeight: rowHeight,
    columnWidth: columnWidth,
  );
  final numberVerticalMargin = (rowHeight - diameter) / 2;
  return numberVerticalMargin + diameter + _monthMarkerTopGap;
}

/// How many event-title rows fit below the day-number circle at [rowHeight]
/// — 0 means there isn't room for a real list yet, so the caller should
/// keep showing the compact dot/bar summary instead. See
/// [monthDayNumberDiameter].
int monthEventListCapacity({
  required double rowHeight,
  required double columnWidth,
}) {
  final available =
      rowHeight -
      monthMarkerTop(rowHeight: rowHeight, columnWidth: columnWidth) -
      _monthMarkerBottomPad;
  if (available < _monthEventRowHeight) return 0;
  return (available / _monthEventRowHeight).floor().clamp(0, 5);
}

// Public aliases of this file's own private layout constants, purely so
// tests can verify the no-overlap invariant (rowHeight - monthMarkerTop(...)
// - monthMarkerBottomPad >= monthCollapsedDotSize) using this file's actual
// tuning instead of a second, easily-stale copy of the same numbers.
const double monthMarkerBottomPad = _monthMarkerBottomPad;
const double monthCollapsedDotSize = _monthCollapsedDotSize;

/// Month grid with per-day event dots. Tapping a day selects it and reveals
/// that day's detail below, so month and day stay one continuous surface.
class MonthView extends ConsumerWidget {
  const MonthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final selected = ref.watch(selectedDateProvider);
    final eventsAsync = ref.watch(eventsForMonthProvider(selected));
    final overdueAsync = ref.watch(overdueTodosProvider);
    final todosAsync = ref.watch(todosForMonthProvider(selected));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekStartsMonday = ref.watch(
      settingsControllerProvider.select((s) => s.weekStartsMonday),
    );
    final startWeekday = weekStartsMonday ? DateTime.monday : DateTime.sunday;
    final rowCount = monthRowCount(selected, startWeekday);

    final rowHeight = ref.watch(monthCalendarRowHeightProvider);

    final monthEvents = eventsAsync.asData?.value ?? const <EventRow>[];
    // Per calendar_dot.dart's shared rule — bucketed by day so the
    // markerBuilder below can look up "does this day have an overdue
    // to-do" in O(1) rather than scanning the whole list per cell.
    final overdueDays = <DateTime>{
      for (final t in overdueAsync.asData?.value ?? const <TodoRow>[])
        dateOnly(t.slotStart),
    };
    // Same rule, for the dot's second state — a day with an incomplete,
    // not-yet-overdue to-do. Excludes overdueDays so the two sets stay
    // mutually exclusive, matching calendarDotColor's own priority order.
    final todoDays = <DateTime>{
      for (final t in todosAsync.asData?.value ?? const <TodoRow>[])
        if (!t.isDone) dateOnly(t.slotStart),
    }..removeAll(overdueDays);
    final monthStart = DateTime(selected.year, selected.month, 1);
    final monthEnd = DateTime(selected.year, selected.month + 1, 1);
    // Multi-day (typically all-day) events get a continuous bar across every
    // day they touch — see eventDaysInRange's doc — rather than a marker on
    // just their start date. Single-day events keep the plain dot.
    final multiDay = <EventRow>[];
    final byDay = <DateTime, List<EventRow>>{};
    for (final e in monthEvents) {
      final key = dateOnly(e.startAt);
      byDay.putIfAbsent(key, () => []).add(e);
      if (e.isAllDay &&
          !dateOnly(
            e.endAt.subtract(const Duration(microseconds: 1)),
          ).isAtSameMomentAs(key)) {
        multiDay.add(e);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxRowHeight = maxMonthRowHeight(
          availableHeight: constraints.maxHeight,
          rowCount: rowCount,
        );
        final effectiveRowHeight = rowHeight.clamp(
          MonthCalendarRowHeight.min,
          maxRowHeight,
        );
        // TableCalendar sits inside this same horizontal gutter padding, so
        // this is its actual per-day column width — used to keep the day-
        // number circle a true circle (not stretched by rowHeight alone)
        // and to size the expanded event list. See monthDayNumberDiameter's
        // doc for why rowHeight alone isn't enough to derive either from.
        final columnWidth =
            (constraints.maxWidth - AppSpacing.gutter * 2) / 7;
        final numberDiameter = monthDayNumberDiameter(
          rowHeight: effectiveRowHeight,
          columnWidth: columnWidth,
        );
        final listCapacity = monthEventListCapacity(
          rowHeight: effectiveRowHeight,
          columnWidth: columnWidth,
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: TableCalendar<EventRow>(
                locale: locale,
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: selected,
                currentDay: DateTime.now(),
                rowHeight: effectiveRowHeight,
                selectedDayPredicate: (d) => dateOnly(d) == dateOnly(selected),
                eventLoader: (d) => byDay[dateOnly(d)] ?? const [],
                startingDayOfWeek: weekStartsMonday
                    ? StartingDayOfWeek.monday
                    : StartingDayOfWeek.sunday,
                availableGestures: AvailableGestures.horizontalSwipe,
                // Collapsed to zero height (formatButton already off,
                // both chevrons hidden, headerTitleBuilder below returns
                // nothing, padding zeroed) rather than left showing its
                // own "‹ 2026년 9월 ›" — schedule_screen.dart's shared
                // title row directly above already shows the same month/
                // year and is itself swipeable, so this was a second,
                // redundant copy of the same text a few hundred pixels
                // away. See maxMonthRowHeight's own doc: the space this
                // used to reserve for the header is no longer subtracted,
                // freeing it for the grid/day view below instead.
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  leftChevronVisible: false,
                  rightChevronVisible: false,
                  headerPadding: EdgeInsets.zero,
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: theme.textTheme.labelMedium!.copyWith(
                    color: palette.inkFaint,
                  ),
                  weekendStyle: theme.textTheme.labelMedium!.copyWith(
                    color: palette.inkFaint,
                  ),
                ),
                calendarBuilders: CalendarBuilders<EventRow>(
                  headerTitleBuilder: (context, day) => const SizedBox.shrink(),
                  markerBuilder: (context, day, events) {
                    final d = dateOnly(day);
                    // eventLoader only buckets an event under its *start* day, so a
                    // multi-day event touching a later day never shows up in
                    // `events` for that day — check `multiDay` against every day
                    // it actually spans instead (see eventDaysInRange's doc).
                    final spanning = multiDay
                        .where(
                          (e) => eventDaysInRange(
                            e,
                            monthStart,
                            monthEnd,
                          ).contains(d),
                        )
                        .toList();
                    final dots = events
                        .where((e) => !multiDay.contains(e))
                        .toList();
                    final hasOverdueTodo = overdueDays.contains(d);
                    final hasTodo = todoDays.contains(d);
                    if (spanning.isEmpty &&
                        dots.isEmpty &&
                        !hasOverdueTodo &&
                        !hasTodo) {
                      return null;
                    }

                    // The selected day fills its cell with a solid accent circle, so
                    // an accent-colored marker would vanish into it — use white
                    // there for contrast instead.
                    final isSelected = d == dateOnly(selected);

                    Widget spanBar({required bool asListRow}) {
                      // Only the first spanning event gets a bar — a packed
                      // month cell has no room for more than one, and
                      // stacking several would crowd the day number.
                      final e = spanning.first;
                      final span = eventDaysInRange(e, monthStart, monthEnd);
                      final isFirst = span.first == d;
                      final isLast = span.last == d;
                      final color = EventColorTag.resolve(
                        e.colorTag,
                        e.startAt,
                      );
                      final bar = Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : color,
                          borderRadius: BorderRadius.horizontal(
                            left: isFirst
                                ? const Radius.circular(2)
                                : Radius.zero,
                            right: isLast
                                ? const Radius.circular(2)
                                : Radius.zero,
                          ),
                        ),
                      );
                      if (!asListRow) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: bar,
                        );
                      }
                      // In the expanded list, every row (this bar included)
                      // gets the same fixed height so the list's own
                      // capacity math (monthEventListCapacity) stays exact.
                      return SizedBox(
                        height: _monthEventRowHeight,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: bar,
                          ),
                        ),
                      );
                    }

                    // Where the day-number circle's own bottom edge actually
                    // lands at this rowHeight — shared by both branches
                    // below so the marker always starts right under it,
                    // never overlapping it. See monthDayNumberDiameter's
                    // doc for why this can't just be a flat offset from the
                    // cell's own bottom edge instead.
                    final markerTop =
                        ((effectiveRowHeight - numberDiameter) / 2) +
                        numberDiameter +
                        _monthMarkerTopGap;

                    // Below monthEventListCapacity's own threshold: same
                    // compact dot/bar summary this has always shown.
                    if (listCapacity <= 0) {
                      return Positioned(
                        left: 0,
                        right: 0,
                        top: markerTop,
                        bottom: _monthMarkerBottomPad,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (spanning.isNotEmpty) spanBar(asListRow: false),
                            if (dots.isNotEmpty || hasOverdueTodo || hasTodo)
                              Container(
                                width: _monthCollapsedDotSize,
                                height: _monthCollapsedDotSize,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : calendarDotColor(
                                          palette: palette,
                                          hasEvent: dots.isNotEmpty,
                                          hasTodo: hasTodo,
                                          hasOverdueTodo: hasOverdueTodo,
                                        ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    // Room for a real list — show each event's own title
                    // (and its own color) instead of a single generic dot,
                    // with a to-do row appended when there's a pending one.
                    final items = <Widget>[
                      if (spanning.isNotEmpty) spanBar(asListRow: true),
                      for (final e in dots)
                        _MonthEventListRow(
                          color: EventColorTag.resolve(e.colorTag, e.startAt),
                          label: e.title.isEmpty ? '—' : e.title,
                          isSelected: isSelected,
                        ),
                      if (hasOverdueTodo || hasTodo)
                        _MonthEventListRow(
                          color: calendarDotColor(
                            palette: palette,
                            hasEvent: false,
                            hasTodo: hasTodo,
                            hasOverdueTodo: hasOverdueTodo,
                          )!,
                          label: l10n.todosSectionTitle,
                          isSelected: isSelected,
                        ),
                    ];
                    final visible = items.length <= listCapacity
                        ? items
                        : [
                            // Reserve the list's last visible slot for a
                            // "+N" hint instead of silently dropping
                            // whatever doesn't fit with no trace of it.
                            ...items.take(listCapacity - 1),
                            _MonthMoreRow(
                              count: items.length - (listCapacity - 1),
                              isSelected: isSelected,
                            ),
                          ];

                    return Positioned(
                      left: 0,
                      right: 0,
                      top: markerTop,
                      bottom: _monthMarkerBottomPad,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: visible,
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  // Vertical margin derived from numberDiameter (fixed
                  // regardless of rowHeight — see its own doc), not a flat
                  // constant: table_calendar sizes the day-number circle to
                  // whatever's left after this margin is subtracted from
                  // the cell, so a flat margin let the circle stretch into
                  // an oval at both ends of the split handle's drag range
                  // instead of staying round.
                  cellMargin: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: (effectiveRowHeight - numberDiameter) / 2,
                  ),
                  defaultTextStyle: theme.textTheme.bodyLarge!,
                  weekendTextStyle: theme.textTheme.bodyLarge!,
                  todayDecoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: theme.textTheme.bodyLarge!.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: theme.textTheme.bodyLarge!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  ref.read(selectedDateProvider.notifier).select(selectedDay);
                },
                onPageChanged: (focusedDay) {
                  ref.read(selectedDateProvider.notifier).select(focusedDay);
                },
              ),
            ),
            _MonthSplitHandle(rowCount: rowCount, maxRowHeight: maxRowHeight),
            // Selected day's timeline flows directly below the month grid —
            // always the timeline layout regardless of the layout-mode
            // preference, per DayView's own doc on `compact`.
            Expanded(child: DayView(day: selected, compact: true)),
          ],
        );
      },
    );
  }
}

/// One event's title in a month cell's expanded list — see
/// [monthEventListCapacity]. A small leading dot in the event's own color
/// (unlike the collapsed dot summary, which is deliberately blind to any
/// individual event's color — see [calendarDotColor]'s doc) plus its title,
/// both sized to fit inside [_monthEventRowHeight].
class _MonthEventListRow extends StatelessWidget {
  const _MonthEventListRow({
    required this.color,
    required this.label,
    required this.isSelected,
  });

  final Color color;
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: _monthEventRowHeight,
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                height: 1.1,
                color: isSelected ? Colors.white : palette.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The expanded list's overflow row — "+N" for however many items didn't
/// fit in [monthEventListCapacity]'s budget, rather than the list silently
/// dropping them with no trace they exist.
class _MonthMoreRow extends StatelessWidget {
  const _MonthMoreRow({required this.count, required this.isSelected});

  final int count;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: _monthEventRowHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '+$count',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : palette.inkFaint,
          ),
        ),
      ),
    );
  }
}

/// Drag handle between the month grid and the day timeline below it —
/// stands in for the plain divider that used to sit here, but also lets the
/// user trade grid space for timeline space by dragging
/// [MonthCalendarRowHeight] taller or shorter. A plain (not long-press)
/// vertical drag is fine here, unlike the grips inside day-view event
/// cards: this strip has no scrollable content underneath it competing for
/// the same gesture.
class _MonthSplitHandle extends ConsumerWidget {
  const _MonthSplitHandle({required this.rowCount, required this.maxRowHeight});

  final int rowCount;

  /// Clamps the drag the same way [MonthView.build] clamps what's actually
  /// rendered — see [maxMonthRowHeight]'s doc. Without this, a drag could
  /// keep pushing the *persisted* value past what's currently reachable, so
  /// the handle would visually stop (clamped for display) while still
  /// silently climbing underneath, one more reason the next drag-up
  /// wouldn't budge it right away.
  final double maxRowHeight;

  /// Logical-pixel step a screen reader's increase/decrease gesture (swipe
  /// up/down while focused, in both VoiceOver and TalkBack) moves the row
  /// height by — there's no finger delta to derive this from the way a real
  /// drag has, so it's a flat step instead, sized to clear a visible change
  /// each time without needing many repeats to cross the full min..max range.
  static const double _semanticStep = 4.0;

  /// Shared by the raw drag and the semantic increase/decrease actions.
  /// [persist] stays false for drag frames (see [MonthCalendarRowHeight.set]'s
  /// doc — the drag's own `onVerticalDragEnd` persists once, at the end);
  /// the semantic actions have no separate "end" event, so each one persists
  /// immediately, same as a single-step drag-and-release would.
  void _adjust(WidgetRef ref, double delta, {bool persist = false}) {
    final notifier = ref.read(monthCalendarRowHeightProvider.notifier);
    final next = ref.read(monthCalendarRowHeightProvider) + delta;
    notifier.set(next.clamp(MonthCalendarRowHeight.min, maxRowHeight));
    if (persist) notifier.persist();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = AppL10n.of(context);
    return Semantics(
      label: l10n.monthSplitHandleLabel,
      // No drag gesture to expose here (there's no meaningful "value" to
      // read out, just a size to nudge) — increase/decrease is what lets a
      // screen reader user reach this control at all, since the underlying
      // gesture is a raw vertical drag they otherwise couldn't perform on
      // this element.
      onIncrease: () => _adjust(ref, _semanticStep, persist: true),
      onDecrease: () => _adjust(ref, -_semanticStep, persist: true),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) {
            // The grid grows by rowCount times whatever a single row grows by,
            // so the delta has to be divided down to a per-row amount for the
            // boundary to actually track the finger instead of running ahead
            // of it.
            if (rowCount <= 0) return;
            _adjust(ref, details.delta.dy / rowCount);
          },
          onVerticalDragEnd: (_) =>
              ref.read(monthCalendarRowHeightProvider.notifier).persist(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.inkFaint,
                    borderRadius: AppRadius.allPill,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Divider(height: 1, color: palette.hairline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
