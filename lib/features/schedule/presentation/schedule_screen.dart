import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_math.dart';
import '../../../core/format.dart';
import '../../../core/lunar/lunar_date.dart';
import '../../../core/lunar/lunar_format.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_motion.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/swipe_navigation_detector.dart';
import '../../../design/widgets/time_gradient_background.dart';
import '../../../features/settings/application/settings_controller.dart';
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

    // Only Day view — Week/Month's own title is already a *period* ("Aug
    // 24 – Aug 30", "2026년 9월"), not a single day, so a single lunar date
    // there would misleadingly read as "the" lunar date for a whole
    // week/month. Week and Month instead get their own per-day lunar labels
    // right on each date cell (_WeekHeader, month_view.dart's
    // CalendarBuilders) — a day-level label belongs on the day it's for.
    String? lunarSubtitle;
    if (view == ScheduleView.day &&
        ref.watch(
          settingsControllerProvider.select((s) => s.showLunarDates),
        )) {
      final lunar = LunarDate.fromSolar(selected);
      if (lunar != null) lunarSubtitle = LunarFmt.short(l10n, lunar);
    }

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
                        lunarSubtitle: lunarSubtitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                        chevronColor: palette.inkFaint,
                        onNavigate: (target) => ref
                            .read(selectedDateProvider.notifier)
                            .select(target),
                      ),
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
                    _HeaderTrailingIcons(
                      view: view,
                      onQuickAdd: () =>
                          showQuickAddEvent(context, anchorDay: selected),
                      onLegend: () => showCalendarLegendSheet(context),
                    ),
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
    this.lunarSubtitle,
    required this.style,
    required this.chevronColor,
    required this.onNavigate,
  });

  final ScheduleView view;
  final DateTime selected;
  final String title;

  /// The current day's short lunar-date label ("음력 7월 22일" etc.), or
  /// null when [AppSettings.showLunarDates] is off, the setting-holder
  /// couldn't convert this particular day (outside klc's supported range),
  /// or [view] isn't [ScheduleView.day] — see [ScheduleScreen.build]'s own
  /// reasoning for why this is day-only.
  final String? lunarSubtitle;
  final TextStyle? style;
  final Color chevronColor;
  final ValueChanged<DateTime> onNavigate;

  void _navigate(bool forward) {
    final target = _swipeTarget(view: view, selected: selected, forward: forward);
    if (target != null) onNavigate(target);
  }

  @override
  Widget build(BuildContext context) {
    // Agenda has no period for _swipeTarget to page through (see its own
    // switch above), so there's nothing real to hint at or tap there.
    final swipeable = view != ScheduleView.agenda;
    return SwipeNavigationDetector(
      key: const Key('scheduleTitleSwipe'),
      onSwipeLeft: () => _navigate(true),
      onSwipeRight: () => _navigate(false),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Doubles as both the "you can page this" hint and its own
            // tap target — a plain tap here steps by one period, the same
            // as reaching the end of a swipe, for anyone who'd rather tap
            // than drag. A quick tap and the swipe gesture above coexist
            // fine on the same area (Flutter's gesture arena resolves a
            // near-zero-movement tap in the InkWell's favor), the same way
            // day_view.dart's event cards already combine a tap with a
            // separate drag gesture.
            if (swipeable) ...[
              _TitleChevron(
                icon: Icons.chevron_left,
                color: chevronColor,
                onTap: () => _navigate(false),
              ),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (lunarSubtitle != null)
                    Text(
                      lunarSubtitle!,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: chevronColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (swipeable) ...[
              const SizedBox(width: 2),
              _TitleChevron(
                icon: Icons.chevron_right,
                color: chevronColor,
                onTap: () => _navigate(true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One of [_SwipeableTitle]'s two chevrons — small, but padded out to a
/// comfortable tap target rather than just the bare 18px glyph.
class _TitleChevron extends StatelessWidget {
  const _TitleChevron({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

/// The view-switcher row's trailing icon cluster: quick-add + legend on
/// every view, plus [_DayLayoutToggle] on [ScheduleView.day] only.
///
/// Always reserves exactly the width the 2-icon (non-day) cluster needs,
/// regardless of which view is active — [_ViewSwitcher] sits in an
/// [Expanded] right next to this, so if this cluster's width changed
/// between views, the switcher pill itself would resize and visibly shift
/// left/right when switching tabs. A [Visibility] with `maintainSize` locks
/// that width in; day view's extra button then reuses that same footprint
/// by tightening the *gaps* between the 3 icons (smaller inter-icon spacing,
/// smaller tap padding around each) — the icons themselves stay their
/// normal size, never scaled down, only repositioned closer together. The
/// [FittedBox] around them is a pure safety net (`scaleDown` never enlarges,
/// and does nothing at all once the 3 tightened icons already fit) in case
/// some device/text-scale combination makes them not quite fit.
class _HeaderTrailingIcons extends StatelessWidget {
  const _HeaderTrailingIcons({
    required this.view,
    required this.onQuickAdd,
    required this.onLegend,
  });

  final ScheduleView view;
  final VoidCallback onQuickAdd;
  final VoidCallback onLegend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final baseIcons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.quickAddEventTitle,
          icon: const Icon(Icons.bolt_outlined),
          onPressed: onQuickAdd,
        ),
        IconButton(
          tooltip: l10n.calendarLegendTooltip,
          icon: const Icon(Icons.info_outline),
          onPressed: onLegend,
        ),
      ],
    );

    if (view != ScheduleView.day) return baseIcons;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: baseIcons,
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CompactHeaderIconButton(
                    tooltip: l10n.quickAddEventTitle,
                    icon: Icons.bolt_outlined,
                    onPressed: onQuickAdd,
                  ),
                  const SizedBox(width: 2),
                  _CompactHeaderIconButton(
                    tooltip: l10n.calendarLegendTooltip,
                    icon: Icons.info_outline,
                    onPressed: onLegend,
                  ),
                  const SizedBox(width: 2),
                  const _DayLayoutToggle(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A tap target for the day view's tightened 3-icon cluster (see
/// [_HeaderTrailingIcons]) — deliberately built on [InkResponse], not
/// [IconButton]. Measured live: even with `visualDensity: compact` and
/// `padding: EdgeInsets.zero`, [IconButton]'s own theme still enforces a
/// ~40px minimum tap box underneath (baseline default measured 44px, the
/// "compact" IconButton only reached 40px) — three of those can't fit in
/// the ~96px two normal `IconButton`s use, so the space would still run out
/// and fall back to the [FittedBox] safety net, uniformly shrinking the
/// icon glyphs along with everything else. [InkResponse] has no such
/// enforced minimum, so the icon itself (default 24dp, unscaled — no `size`
/// override) plus a small fixed padding is *all* of this widget's real
/// footprint, comfortably fitting 3 of them in that same reserved width.
class _CompactHeaderIconButton extends StatelessWidget {
  const _CompactHeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon),
        ),
      ),
    );
  }
}

/// Switches [DayView] between its timeline and 24-hour clock layouts — only
/// shown while [ScheduleView.day] is active, since it's the only view either
/// layout applies to. Shows the icon for the layout a tap would switch *to*
/// (matching the icon convention play/pause buttons use), not the one
/// currently showing.
///
/// Its only call site is inside [_HeaderTrailingIcons]' tightened 3-icon
/// cluster, so it uses the same compact tap-padding as
/// [_CompactHeaderIconButton] there — the icon glyph itself is still full
/// size, unscaled.
class _DayLayoutToggle extends ConsumerWidget {
  const _DayLayoutToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final mode = ref.watch(dayViewLayoutModeProvider);
    final targetMode = mode == DayViewLayoutMode.timeline
        ? DayViewLayoutMode.clock
        : DayViewLayoutMode.timeline;
    return _CompactHeaderIconButton(
      tooltip: targetMode == DayViewLayoutMode.clock
          ? l10n.dayLayoutSwitchToClock
          : l10n.dayLayoutSwitchToTimeline,
      icon: targetMode == DayViewLayoutMode.clock
          ? Icons.donut_large_outlined
          : Icons.view_timeline_outlined,
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
