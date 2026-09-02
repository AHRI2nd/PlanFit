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

// The tiny label style every expanded-list row (event, to-do, "+N"
// overflow) renders its text in — a single shared constant so
// [monthEventRowHeight]'s measurement can never drift out of sync with
// what these rows actually paint.
const _monthEventRowTextStyle = TextStyle(fontSize: 9, height: 1.1);

/// The real height one expanded-list row needs, measured from
/// [_monthEventRowTextStyle] itself rather than a guessed constant —
/// [monthEventListCapacity]'s "how many rows fit" arithmetic used to budget
/// a flat 12.0 per row, well above this text's own actual rendered height,
/// which quietly left an unused sliver of most cells' available space and
/// undercounted how many events a tall row could actually show before
/// falling back to a "+N" count. Measuring the real height instead keeps
/// the capacity math and the rows it counts honest with each other.
double monthEventRowHeight() {
  final painter = TextPainter(
    text: const TextSpan(text: 'Ag', style: _monthEventRowTextStyle),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.height;
}

// Small breathing room between the day-number circle and whatever sits
// below it (dot/bar summary or the expanded list), and between that content
// and the cell's own bottom edge. Shared by both the collapsed and expanded
// marker, and by [MonthCalendarRowHeight.min]'s own budget — see its doc.
const double _monthMarkerTopGap = 1.0;
const double _monthMarkerBottomPad = 2.0;

// The collapsed dot/bar summary's plain dot — also a named constant (not
// just a literal on the Container below) because [MonthCalendarRowHeight.min]
// needs to budget room for exactly this size, not guess at it.
const double _monthCollapsedDotSize = 6.0;

// How many individual dots the collapsed summary draws (one per event/
// to-do entry, each in its own color) before switching to a single "+N"
// count instead — a typical day cell is too narrow to keep adding dots
// indefinitely without them running into each other.
const int _monthCollapsedMaxDots = 4;

// The day-number circle's one fixed diameter — see monthDayNumberDiameter's
// doc for why this doesn't vary with rowHeight at all.
const double _monthDayNumberDiameterTarget = 24.0;

// The day-number circle's own top margin — FIXED regardless of rowHeight,
// rather than growing with it the way vertically centering the circle
// would. Derived once from MonthCalendarRowHeight.min so it exactly
// reproduces the small margin that height already needs (tuned there to
// avoid the circle overlapping the marker below it at the shortest allowed
// row height — see that constant's own doc); every pixel a taller row adds
// beyond the minimum goes entirely to the marker/list area below instead
// of half of it just becoming more blank space above the number, which is
// what a plain symmetric margin — literally centering the circle — was
// doing before. BoxDecoration's own circle painting always uses a box's
// *shorter* side for the circle's diameter regardless of the box's aspect
// ratio, so making the box asymmetric (see cellMargin below) doesn't risk
// distorting the circle the way an earlier, unrelated bug did — that one
// came from the box's height itself changing size, not its shape.
const double _monthNumberTopMargin =
    (MonthCalendarRowHeight.min - _monthDayNumberDiameterTarget) / 2;

/// The day-number circle's diameter — a single fixed size (24, or smaller
/// only on an unusually narrow column) that never changes as the split
/// handle drags [MonthCalendarRowHeight] taller or shorter. An earlier
/// version derived this from [rowHeight] as well, to guarantee the
/// collapsed dot/bar summary always had room below the circle — but that
/// meant the circle itself visibly grew and shrank as the grid was resized,
/// which read as its own bug. The clearance guarantee now comes from
/// [MonthCalendarRowHeight.min] being tall enough for this *fixed* diameter
/// instead — see its own doc.
double monthDayNumberDiameter({required double columnWidth}) {
  final capped = math.min(columnWidth - 12, _monthDayNumberDiameterTarget);
  return capped.clamp(16.0, _monthDayNumberDiameterTarget);
}

/// Where the marker area (the collapsed dot/bar summary, or the expanded
/// list — see [monthEventListCapacity]) starts, in pixels from the cell's
/// own top edge — always right below [monthDayNumberDiameter]'s circle
/// (itself sitting at the fixed [_monthNumberTopMargin], not vertically
/// centered — see that constant's own doc) plus a small gap. Doesn't
/// depend on rowHeight at all, unlike an earlier version that vertically
/// centered the circle: the single source of truth both the collapsed and
/// expanded branches in [MonthView] position themselves against, so the
/// two can never drift out of sync.
double monthMarkerTop({required double columnWidth}) {
  final diameter = monthDayNumberDiameter(columnWidth: columnWidth);
  return _monthNumberTopMargin + diameter + _monthMarkerTopGap;
}

/// How many event-title rows fit below the day-number circle at [rowHeight]
/// — 0 means there isn't room for a real list yet, so the caller should
/// keep showing the compact dot/bar summary instead. See
/// [monthDayNumberDiameter].
///
/// Requires room for at least 2 rows before returning anything nonzero, not
/// just 1: a list showing a single row isn't meaningfully more useful than
/// the collapsed dot summary it would be replacing, so switching visual
/// modes for it isn't worth it — this is also what keeps the list from
/// unlocking uninvited at [MonthCalendarRowHeight.defaultHeight] itself
/// (which has just enough room for exactly one row's real, measured
/// height), preserving the "only once the user drags the row taller"
/// behavior a flatter, more generous row-height budget used to provide
/// somewhat by accident.
int monthEventListCapacity({
  required double rowHeight,
  required double columnWidth,
}) {
  final available =
      rowHeight -
      monthMarkerTop(columnWidth: columnWidth) -
      _monthMarkerBottomPad;
  final rowHeightNeeded = monthEventRowHeight();
  final raw = (available / rowHeightNeeded).floor();
  if (raw < 2) return 0;
  return raw.clamp(0, 5);
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
        // this is its actual per-day column width — used to size the
        // day-number circle (see monthDayNumberDiameter's doc for why it's
        // a fixed size, not derived from rowHeight) and the expanded event
        // list.
        final columnWidth =
            (constraints.maxWidth - AppSpacing.gutter * 2) / 7;
        final numberDiameter = monthDayNumberDiameter(
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
                          color: color,
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
                        height: monthEventRowHeight(),
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
                    // lands — shared by both branches below so the marker
                    // always starts right under it, never overlapping it.
                    // monthMarkerTop is the single source of truth for
                    // this (also used by monthEventListCapacity's own
                    // arithmetic, and by cellMargin below, so all three
                    // agree on exactly where the circle sits) — see its
                    // own doc for why this no longer depends on rowHeight.
                    final markerTop = monthMarkerTop(columnWidth: columnWidth);

                    // Below monthEventListCapacity's own threshold: the
                    // compact dot/bar summary. One dot per single-day
                    // event/to-do entry, each in its own real color (up to
                    // _monthCollapsedMaxDots), so the count is actually
                    // visible at a glance instead of collapsing straight to
                    // one generic "something's here" dot; beyond that, a
                    // "+N" count instead — mirrors _MonthMoreRow's own
                    // overflow style in the expanded list, just centered
                    // under the date here rather than left-aligned in a
                    // list row.
                    final entryColors = <Color>[
                      for (final e in dots)
                        EventColorTag.resolve(e.colorTag, e.startAt),
                      if (hasOverdueTodo || hasTodo)
                        calendarDotColor(
                          palette: palette,
                          hasEvent: false,
                          hasTodo: hasTodo,
                          hasOverdueTodo: hasOverdueTodo,
                        )!,
                    ];
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
                            if (entryColors.isNotEmpty)
                              if (entryColors.length <=
                                  _monthCollapsedMaxDots)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final color in entryColors)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 1,
                                        ),
                                        child: Container(
                                          width: _monthCollapsedDotSize,
                                          height: _monthCollapsedDotSize,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              else
                                // Flexible+FittedBox, not a bare Text: at
                                // the shortest allowed row height there's
                                // only as much vertical room as
                                // _monthCollapsedDotSize's own tiny dot
                                // needs (that size is exactly what
                                // MonthCalendarRowHeight.min budgets for),
                                // which a 9px-font line doesn't always fit
                                // without this scaling down to whatever
                                // room is actually available instead of
                                // overflowing the cell.
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '+${entryColors.length}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: palette.inkFaint,
                                      ),
                                    ),
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
                  // table_calendar's CellContent sizes the day-number
                  // circle's own box to whatever's left after this margin
                  // is subtracted from the cell (a flat margin either let
                  // the circle change size with rowHeight, or — the
                  // now-fixed numberDiameter — wasted an ever-growing
                  // chunk of a taller row as blank space just centering
                  // it). Asymmetric on purpose: a small fixed top margin
                  // (matching monthMarkerTop's own _monthNumberTopMargin,
                  // so the circle and the marker below it agree on where
                  // it sits) and a bottom margin that absorbs the rest —
                  // BoxDecoration's circle painting uses a box's *shorter*
                  // side for the circle's own diameter regardless of the
                  // box's aspect ratio, so an asymmetric (non-square) box
                  // doesn't risk distorting it, as long as this bottom
                  // margin still leaves the box's own height exactly
                  // matching numberDiameter (which it does, by
                  // construction, below).
                  cellMargin: EdgeInsets.fromLTRB(
                    6,
                    _monthNumberTopMargin,
                    6,
                    effectiveRowHeight - _monthNumberTopMargin - numberDiameter,
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
/// both sized to fit inside [monthEventRowHeight].
class _MonthEventListRow extends StatelessWidget {
  const _MonthEventListRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: monthEventRowHeight(),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _monthEventRowTextStyle.copyWith(color: palette.inkSoft),
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
  const _MonthMoreRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: monthEventRowHeight(),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '+$count',
          style: _monthEventRowTextStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: palette.inkFaint,
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
