import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/db/app_database.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../settings/application/settings_controller.dart';
import '../../application/schedule_providers.dart';
import '../../domain/event_span.dart';
import '../day_view/day_view.dart';

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
        settingsControllerProvider.select((s) => s.weekStartsMonday));

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
      if (e.isAllDay && !dateOnly(e.endAt.subtract(const Duration(microseconds: 1))).isAtSameMomentAs(key)) {
        multiDay.add(e);
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: TableCalendar<EventRow>(
          locale: locale,
          firstDay: DateTime(2000),
          lastDay: DateTime(2100),
          focusedDay: selected,
          currentDay: DateTime.now(),
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
            leftChevronIcon:
                Icon(Icons.chevron_left, color: palette.inkSoft),
            rightChevronIcon:
                Icon(Icons.chevron_right, color: palette.inkSoft),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: theme.textTheme.labelMedium!
                .copyWith(color: palette.inkFaint),
            weekendStyle: theme.textTheme.labelMedium!
                .copyWith(color: palette.inkFaint),
          ),
          calendarBuilders: CalendarBuilders<EventRow>(
            markerBuilder: (context, day, events) {
              final d = dateOnly(day);
              // eventLoader only buckets an event under its *start* day, so a
              // multi-day event touching a later day never shows up in
              // `events` for that day — check `multiDay` against every day
              // it actually spans instead (see eventDaysInRange's doc).
              final spanning = multiDay
                  .where((e) =>
                      eventDaysInRange(e, monthStart, monthEnd).contains(d))
                  .toList();
              final dots = events.where((e) => !multiDay.contains(e)).toList();
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
                      Builder(builder: (context) {
                        // Only the first spanning event gets a bar — a
                        // packed month cell has no room for more than one,
                        // and stacking several would crowd the day number.
                        final e = spanning.first;
                        final span =
                            eventDaysInRange(e, monthStart, monthEnd);
                        final isFirst = span.first == d;
                        final isLast = span.last == d;
                        final color =
                            EventColorTag.resolve(e.colorTag, e.startAt);
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
                      }),
                    if (dots.isNotEmpty)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : EventColorTag.resolve(
                                  dots.first.colorTag, day),
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
            todayTextStyle: theme.textTheme.bodyLarge!
                .copyWith(color: palette.accent, fontWeight: FontWeight.w700),
            selectedDecoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: theme.textTheme.bodyLarge!
                .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          onDaySelected: (selectedDay, focusedDay) {
            ref.read(selectedDateProvider.notifier).select(selectedDay);
          },
          onPageChanged: (focusedDay) {
            ref.read(selectedDateProvider.notifier).select(focusedDay);
          },
        ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: const Divider(height: AppSpacing.md),
        ),
        // Selected day's timeline flows directly below the month grid.
        Expanded(child: DayView(day: selected)),
      ],
    );
  }
}
