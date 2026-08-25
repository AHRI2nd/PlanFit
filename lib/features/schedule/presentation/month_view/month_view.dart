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
import '../../application/schedule_providers.dart';
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

/// Rendered height of [TableCalendar]'s own month-title/chevron header row
/// (see `HeaderStyle.headerPadding`'s 8+8 default), scaled for the user's
/// text-size setting so this stays accurate under larger accessibility
/// fonts too.
double _monthHeaderHeight(BuildContext context) {
  final titleFontSize = Theme.of(context).textTheme.titleLarge?.fontSize ?? 22;
  final scaledFontSize = MediaQuery.textScalerOf(context).scale(titleFontSize);
  return scaledFontSize * 1.3 + 16;
}

/// The tallest [MonthCalendarRowHeight] can go without the grid + handle
/// pushing [DayView] (and the handle itself) out of the viewport — see the
/// doc on [_MonthSplitHandle] for why an unbounded rowHeight let the handle
/// scroll itself below the visible area with no way back.
double maxMonthRowHeight({
  required double availableHeight,
  required int rowCount,
  required BuildContext context,
}) {
  if (rowCount <= 0) return MonthCalendarRowHeight.min;
  final reserved =
      _monthHeaderHeight(context) +
      _monthDowHeight +
      _monthHandleHeight +
      _monthMinDayViewHeight;
  final forRows = availableHeight - reserved;
  if (forRows <= 0) return MonthCalendarRowHeight.min;
  return (forRows / rowCount).clamp(
    MonthCalendarRowHeight.min,
    MonthCalendarRowHeight.max,
  );
}

/// Month grid with per-day event dots. Tapping a day selects it and reveals
/// that day's detail below, so month and day stay one continuous surface.
class MonthView extends ConsumerWidget {
  const MonthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final selected = ref.watch(selectedDateProvider);
    final eventsAsync = ref.watch(eventsForMonthProvider(selected));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekStartsMonday = ref.watch(
      settingsControllerProvider.select((s) => s.weekStartsMonday),
    );
    final startWeekday = weekStartsMonday ? DateTime.monday : DateTime.sunday;
    final rowCount = monthRowCount(selected, startWeekday);

    final rowHeight = ref.watch(monthCalendarRowHeightProvider);

    final monthEvents = eventsAsync.asData?.value ?? const <EventRow>[];
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
          context: context,
        );
        final effectiveRowHeight = rowHeight.clamp(
          MonthCalendarRowHeight.min,
          maxRowHeight,
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
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: theme.textTheme.titleLarge!,
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: palette.inkSoft,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: palette.inkSoft,
                  ),
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
                    if (spanning.isEmpty && dots.isEmpty) return null;

                    // The selected day fills its cell with a solid accent circle, so
                    // an accent-colored marker would vanish into it — use white
                    // there for contrast instead.
                    final isSelected = d == dateOnly(selected);

                    return Positioned(
                      left: 0,
                      right: 0,
                      // Lifted well clear of the cell's bottom edge so it reads
                      // as sitting inside the selected/today circle, not clipped
                      // against it.
                      bottom: 6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (spanning.isNotEmpty)
                            Builder(
                              builder: (context) {
                                // Only the first spanning event gets a bar — a
                                // packed month cell has no room for more than one,
                                // and stacking several would crowd the day number.
                                final e = spanning.first;
                                final span = eventDaysInRange(
                                  e,
                                  monthStart,
                                  monthEnd,
                                );
                                final isFirst = span.first == d;
                                final isLast = span.last == d;
                                final color = EventColorTag.resolve(
                                  e.colorTag,
                                  e.startAt,
                                );
                                return Container(
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 2),
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
                              },
                            ),
                          if (dots.isNotEmpty)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : EventColorTag.resolve(
                                        dots.first.colorTag,
                                        day,
                                      ),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
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
            // Selected day's timeline flows directly below the month grid.
            Expanded(child: DayView(day: selected)),
          ],
        );
      },
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
