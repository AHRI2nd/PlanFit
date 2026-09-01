import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date_math.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/format.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../todo/application/todo_providers.dart';
import '../../application/schedule_providers.dart';
import '../../domain/calendar_dot.dart';

/// A year at a glance: twelve compact month grids whose days glow where events
/// live. Tapping a month jumps to it in the month view. The whole grid is
/// itself a swipeable page — see [_YearPager] — so paging ±1 year works
/// anywhere on it, not just [schedule_screen.dart]'s shared (and much
/// narrower) title row.
///
/// No title of its own — that shared title row already shows the year. This
/// used to render its own second, non-interactive "2026" above the grid;
/// besides being a plain duplicate, its lack of any gesture made it an easy
/// — and completely dead — target for a user trying to swipe the year,
/// since it visually reads as *the* year label sitting right above the
/// content.
class YearView extends ConsumerWidget {
  const YearView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    return _YearPager(
      year: selected.year,
      // addCalendarYears, not a raw DateTime(newYear, month, day)
      // reconstruction — the latter silently rolls Feb 29 (a leap year)
      // into March 1 on a non-leap target year instead of clamping to
      // Feb 28, the exact bug addCalendarYears exists to avoid (see its
      // own doc in date_math.dart).
      onYearChanged: (newYear) => ref
          .read(selectedDateProvider.notifier)
          .select(addCalendarYears(selected, newYear - selected.year)),
    );
  }
}

/// Pages a full [_YearPageContent] (the 12-month grid) through a real,
/// physically-dragged [PageView] — same shape as week_view.dart's
/// `_WeekPager`, just keyed by year instead of week-start. See that class's
/// own doc for why a plain gesture detector that only jumps on release
/// isn't used instead.
class _YearPager extends StatefulWidget {
  const _YearPager({required this.year, required this.onYearChanged});

  final int year;
  final ValueChanged<int> onYearChanged;

  // ~2000 years either side of startup — plenty, and PageView needs a
  // finite itemCount rather than true unbounded paging.
  static const int _pageCount = 4000;
  static const int _initialPage = _pageCount ~/ 2;

  @override
  State<_YearPager> createState() => _YearPagerState();
}

class _YearPagerState extends State<_YearPager> {
  late final PageController _controller;
  late int _currentPage;
  late int _pageYear;

  @override
  void initState() {
    super.initState();
    _currentPage = _YearPager._initialPage;
    _pageYear = widget.year;
    _controller = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant _YearPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.year == _pageYear) return;
    // year changed from outside this pager's own onPageChanged (the
    // "오늘" button, the schedule title's own swipe, tapping a month to
    // jump into month view and back, ...) — resync the controller to
    // match instead of leaving it pointing at a stale year.
    final deltaYears = widget.year - _pageYear;
    final targetPage = _currentPage + deltaYears;
    _currentPage = targetPage;
    _pageYear = widget.year;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpToPage(targetPage);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _yearForPage(int page) => _pageYear + (page - _currentPage);

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      key: const Key('yearPageSwipe'),
      controller: _controller,
      itemCount: _YearPager._pageCount,
      onPageChanged: (page) {
        final newYear = _yearForPage(page);
        _currentPage = page;
        _pageYear = newYear;
        widget.onYearChanged(newYear);
      },
      itemBuilder: (context, page) =>
          _YearPageContent(year: _yearForPage(page)),
    );
  }
}

class _YearPageContent extends ConsumerWidget {
  const _YearPageContent({required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsForYearProvider(year));
    final overdueAsync = ref.watch(overdueTodosProvider);
    final todosAsync = ref.watch(todosForYearProvider(year));
    final locale = Localizations.localeOf(context).toLanguageTag();
    final startWeekday = ref.watch(weekStartWeekdayProvider);

    final counts = <DateTime, int>{};
    for (final e in eventsAsync.asData?.value ?? const <EventRow>[]) {
      final key = dateOnly(e.startAt);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    // Per calendar_dot.dart's shared rule.
    final overdueDays = <DateTime>{
      for (final t in overdueAsync.asData?.value ?? const <TodoRow>[])
        dateOnly(t.slotStart),
    };
    final todoDays = <DateTime>{
      for (final t in todosAsync.asData?.value ?? const <TodoRow>[])
        if (!t.isDone) dateOnly(t.slotStart),
    }..removeAll(overdueDays);

    return GridView.builder(
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
          overdueDays: overdueDays,
          todoDays: todoDays,
          locale: locale,
          startWeekday: startWeekday,
          onTap: () {
            ref
                .read(selectedDateProvider.notifier)
                .select(DateTime(year, month, 1));
            ref.read(scheduleViewProvider.notifier).set(ScheduleView.month);
          },
        );
      },
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.year,
    required this.month,
    required this.counts,
    required this.overdueDays,
    required this.todoDays,
    required this.locale,
    required this.startWeekday,
    required this.onTap,
  });

  final int year;
  final int month;
  final Map<DateTime, int> counts;
  final Set<DateTime> overdueDays;
  final Set<DateTime> todoDays;
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
                final hasOverdueTodo = overdueDays.contains(date);
                final hasTodo = todoDays.contains(date);
                final markerColor = calendarDotColor(
                  palette: palette,
                  hasEvent: count > 0,
                  hasTodo: hasTodo,
                  hasOverdueTodo: hasOverdueTodo,
                );
                final isToday = date == today;
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: markerColor != null
                        ? markerColor.withValues(
                            // An overdue or todo day is a flat,
                            // clearly-visible state regardless of how many
                            // events also land there — only the plain
                            // "has events" case scales with count the way
                            // it always has.
                            alpha: (hasOverdueTodo || hasTodo)
                                ? 0.55
                                : (0.30 + count * 0.18).clamp(0.3, 0.9),
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
                      color: markerColor != null
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
