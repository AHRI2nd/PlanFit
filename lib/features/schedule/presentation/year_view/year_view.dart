import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/format.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../application/schedule_providers.dart';

/// A year at a glance: twelve compact month grids whose days glow where events
/// live. Tapping a month jumps to it in the month view.
class YearView extends ConsumerWidget {
  const YearView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final year = selected.year;
    final eventsAsync = ref.watch(eventsForYearProvider(year));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final startWeekday = ref.watch(weekStartWeekdayProvider);

    final counts = <DateTime, int>{};
    final dayColors = <DateTime, Color>{};
    for (final e in eventsAsync.asData?.value ?? const <EventRow>[]) {
      final key = dateOnly(e.startAt);
      counts[key] = (counts[key] ?? 0) + 1;
      dayColors.putIfAbsent(
        key,
        () => EventColorTag.resolve(e.colorTag, e.startAt),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$year',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFeatures: null,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xs,
              AppSpacing.gutter,
              140,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.82,
            ),
            itemCount: 12,
            itemBuilder: (context, i) {
              final month = i + 1;
              return _MiniMonth(
                year: year,
                month: month,
                counts: counts,
                dayColors: dayColors,
                locale: locale,
                startWeekday: startWeekday,
                onTap: () {
                  ref
                      .read(selectedDateProvider.notifier)
                      .select(DateTime(year, month, 1));
                  ref
                      .read(scheduleViewProvider.notifier)
                      .set(ScheduleView.month);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.year,
    required this.month,
    required this.counts,
    required this.dayColors,
    required this.locale,
    required this.startWeekday,
    required this.onTap,
  });

  final int year;
  final int month;
  final Map<DateTime, int> counts;
  final Map<DateTime, Color> dayColors;
  final String locale;
  final int startWeekday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlanks = (first.weekday - startWeekday) % 7;
    final today = dateOnly(DateTime.now());

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Fmt.monthName(first, locale),
            style: theme.textTheme.labelLarge?.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: leadingBlanks + daysInMonth,
              itemBuilder: (context, index) {
                if (index < leadingBlanks) return const SizedBox.shrink();
                final day = index - leadingBlanks + 1;
                final date = DateTime(year, month, day);
                final count = counts[date] ?? 0;
                final isToday = date == today;
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: count > 0
                        ? (dayColors[date] ??
                                  AppColors.timeGradient(date).first)
                              .withValues(
                                alpha: (0.30 + count * 0.18).clamp(0.3, 0.9),
                              )
                        : (isToday
                              ? palette.accent.withValues(alpha: 0.18)
                              : null),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: count > 0
                          ? Colors.white
                          : (isToday ? palette.accent : palette.inkFaint),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
