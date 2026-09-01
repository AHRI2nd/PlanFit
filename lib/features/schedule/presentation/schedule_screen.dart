import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_math.dart';
import '../../../core/format.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_motion.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/swipe_navigation_detector.dart';
import '../../../design/widgets/time_gradient_background.dart';
import '../../../l10n/app_localizations.dart';
import '../application/schedule_providers.dart';
import 'agenda_view/agenda_view.dart';
import 'calendar_legend_sheet.dart';
import 'day_view/day_view.dart';
import 'event_edit/event_editor_sheet.dart';
import 'event_edit/quick_add_sheet.dart';
import 'month_view/month_view.dart';
import 'search/event_search_screen.dart';
import 'week_view/week_view.dart';
import 'year_view/year_view.dart';

/// The date [selected] moves to for a title-row swipe on [view], one period
/// in the direction implied by [forward] (true = next, false = previous).
/// Returns null for views with no natural "period" to page through (agenda),
/// meaning the swipe is a no-op there.
DateTime? _swipeTarget({
  required ScheduleView view,
  required DateTime selected,
  required bool forward,
}) {
  final sign = forward ? 1 : -1;
  return switch (view) {
    ScheduleView.day => addCalendarDays(selected, sign),
    ScheduleView.week => addCalendarDays(selected, sign * 7),
    ScheduleView.month => addCalendarMonths(selected, sign),
    ScheduleView.year => addCalendarYears(selected, sign),
    ScheduleView.agenda => null,
  };
}

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final view = ref.watch(scheduleViewProvider);
    final selected = ref.watch(selectedDateProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekStartWeekday = ref.watch(weekStartWeekdayProvider);

    final title = switch (view) {
      ScheduleView.day => Fmt.fullDate(selected, locale),
      ScheduleView.week => () {
        final start = startOfWeek(selected, startWeekday: weekStartWeekday);
        final end = addCalendarDays(start, 6);
        return '${Fmt.monthDay(start, locale)} – ${Fmt.monthDay(end, locale)}';
      }(),
      ScheduleView.month => Fmt.yearMonth(selected, locale),
      ScheduleView.year => '${selected.year}',
      ScheduleView.agenda => l10n.viewAgenda,
    };

    return TimeGradientBackground(
      intensity: 0.7,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Lifted clear of the floating glass nav bar, which lives outside this
        // nested Scaffold (in AppShell) so it isn't reserved for automatically.
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 88),
          child: FloatingActionButton(
            onPressed: () => showEventEditor(context, initialDay: selected),
            child: const Icon(Icons.add),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SwipeableTitle(
                        view: view,
                        selected: selected,
                        title: title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        onNavigate: (target) => ref
                            .read(selectedDateProvider.notifier)
                            .select(target),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.quickAddEventTitle,
                      icon: const Icon(Icons.bolt_outlined),
                      onPressed: () =>
                          showQuickAddEvent(context, anchorDay: selected),
                    ),
                    IconButton(
                      tooltip: l10n.searchTooltip,
                      icon: const Icon(Icons.search),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EventSearchScreen(),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(selectedDateProvider.notifier).jumpToToday(),
                      child: Text(l10n.commonToday),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ViewSwitcher(
                        current: view,
                        accent: palette.accent,
                        labels: (
                          l10n.viewDay,
                          l10n.viewWeek,
                          l10n.viewMonth,
                          l10n.viewYear,
                          l10n.viewAgenda,
                        ),
                        onChanged: (v) =>
                            ref.read(scheduleViewProvider.notifier).set(v),
                      ),
                    ),
                    // Lives here, not the title row above, so it only ever
                    // competes for space with the (already generously wide)
                    // switcher pills instead of the date title — cramming a
                    // day-layout toggle into the title row alongside the
                    // other header icons was what pushed a long Korean date
                    // string back into wrapping onto two lines, so the same
                    // "add it to the switcher row instead" fix applies here
                    // too rather than repeating that regression.
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      tooltip: l10n.calendarLegendTooltip,
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => showCalendarLegendSheet(context),
                    ),
                    if (view == ScheduleView.day) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const _DayLayoutToggle(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: switch (view) {
                  ScheduleView.day => DayView(day: selected),
                  ScheduleView.week => WeekView(anchor: selected),
                  ScheduleView.month => const MonthView(),
                  ScheduleView.year => const YearView(),
                  // Always "now", not `selected` — the list tab reads as
                  // "what's coming up", not "what's around whatever day
                  // some other tab last left selected". Doesn't lose any
                  // real navigability: agenda is the one view _swipeTarget
                  // never wires a swipe to (see its own switch above), so
                  // `selected` was never something the user could actually
                  // steer while already on this tab anyway.
                  ScheduleView.agenda => AgendaView(
                    anchor: dateOnly(DateTime.now()),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared per-view title text, made swipeable so the user can page
/// ±1 day/week/month/year without leaving [ScheduleScreen]'s title row.
/// Deliberately scoped to just this text — not the view's scrollable body —
/// since both [DayView]'s `_EventCard` and its embedded `HourlyTodoList`
/// already use a horizontal-drag/`Dismissible` swipe for delete there; a
/// gesture wired into the body would fight that instead of navigating.
class _SwipeableTitle extends StatelessWidget {
  const _SwipeableTitle({
    required this.view,
    required this.selected,
    required this.title,
    required this.style,
    required this.onNavigate,
  });

  final ScheduleView view;
  final DateTime selected;
  final String title;
  final TextStyle? style;
  final ValueChanged<DateTime> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SwipeNavigationDetector(
      key: const Key('scheduleTitleSwipe'),
      onSwipeLeft: () {
        final target = _swipeTarget(
          view: view,
          selected: selected,
          forward: true,
        );
        if (target != null) onNavigate(target);
      },
      onSwipeRight: () {
        final target = _swipeTarget(
          view: view,
          selected: selected,
          forward: false,
        );
        if (target != null) onNavigate(target);
      },
      // Padding, not just the bare Text, so the swipeable/tappable hit box
      // (this Row uses the default `center` cross-alignment, so it can't be
      // grown by stretching the Row — that forces an infinite-height layout
      // exception, since the Row's own incoming height constraint here is
      // unbounded) is noticeably taller than the text's own line height.
      // Without this, the only draggable strip is a thin band vertically
      // centered in the header, easy for a real swipe (which naturally
      // drifts a bit vertically) to miss entirely.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(title, style: style),
      ),
    );
  }
}

/// Switches [DayView] between its timeline and 24-hour clock layouts — only
/// shown while [ScheduleView.day] is active, since it's the only view either
/// layout applies to. Shows the icon for the layout a tap would switch *to*
/// (matching the icon convention play/pause buttons use), not the one
/// currently showing.
class _DayLayoutToggle extends ConsumerWidget {
  const _DayLayoutToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final mode = ref.watch(dayViewLayoutModeProvider);
    final targetMode = mode == DayViewLayoutMode.timeline
        ? DayViewLayoutMode.clock
        : DayViewLayoutMode.timeline;
    return IconButton(
      tooltip: targetMode == DayViewLayoutMode.clock
          ? l10n.dayLayoutSwitchToClock
          : l10n.dayLayoutSwitchToTimeline,
      icon: Icon(
        targetMode == DayViewLayoutMode.clock
            ? Icons.donut_large_outlined
            : Icons.view_timeline_outlined,
      ),
      onPressed: () =>
          ref.read(dayViewLayoutModeProvider.notifier).set(targetMode),
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({
    required this.current,
    required this.accent,
    required this.labels,
    required this.onChanged,
  });

  final ScheduleView current;
  final Color accent;
  final (String, String, String, String, String) labels;
  final ValueChanged<ScheduleView> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entries = [
      (ScheduleView.day, labels.$1),
      (ScheduleView.week, labels.$2),
      (ScheduleView.month, labels.$3),
      (ScheduleView.year, labels.$4),
      (ScheduleView.agenda, labels.$5),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.allPill,
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          for (final (v, label) in entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: context.motionDuration(
                    const Duration(milliseconds: 220),
                  ),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: v == current ? accent : Colors.transparent,
                    borderRadius: AppRadius.allPill,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: v == current ? Colors.white : palette.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
