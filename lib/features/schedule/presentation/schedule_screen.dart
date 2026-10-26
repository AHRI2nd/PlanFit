import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/date_math.dart';
import '../../../core/format.dart';
import '../../../core/lunar/lunar_date.dart';
import '../../../core/lunar/lunar_format.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/layout/app_layout.dart';
import '../../../design/widgets/swipe_navigation_detector.dart';
import '../../../design/widgets/time_gradient_background.dart';
import '../../../features/settings/application/settings_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../application/schedule_providers.dart';
import 'agenda_view/agenda_view.dart';
import 'calendar_legend_sheet.dart';
import 'day_view/day_view.dart';
import 'draggable_add_button.dart';
import 'event_edit/event_editor_sheet.dart';
import 'event_edit/quick_add_sheet.dart';
import 'month_view/month_view.dart';
import '../../../design/widgets/open_app_search.dart';
import 'week_view/week_view.dart';
import 'year_view/year_view.dart';

// A two-pane month view needs enough width for both a readable seven-column
// calendar and the selected day's time list. Below this threshold (including
// narrow iPad Split View windows), the single-pane month layout is clearer.
const double _monthTwoPaneMinWidth = 960;
const double _monthCalendarPaneMinWidth = 376;
const double _dayDetailPaneMinWidth = 320;

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
    final now = ref.watch(nowTickerProvider).asData?.value ?? DateTime.now();

    final title = switch (view) {
      ScheduleView.day => Fmt.fullDate(selected, locale),
      ScheduleView.week => () {
        final start = startOfWeek(selected, startWeekday: weekStartWeekday);
        final end = addCalendarDays(start, 6);
        return '${Fmt.monthDayShort(start, locale)} – ${Fmt.monthDayShort(end, locale)}';
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
        ref.watch(settingsControllerProvider.select((s) => s.showLunarDates))) {
      final lunar = LunarDate.fromSolar(selected);
      if (lunar != null) lunarSubtitle = LunarFmt.short(l10n, lunar);
    }

    return TimeGradientBackground(
      at: now,
      intensity: 0.7,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final heading = _SwipeableTitle(
                      view: view,
                      selected: selected,
                      title: title,
                      lunarSubtitle: lunarSubtitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                      chevronColor: palette.inkFaint,
                      onNavigate: (target) => ref
                          .read(selectedDateProvider.notifier)
                          .select(target),
                    );
                    final actions = <Widget>[
                      const AppSearchButton(),
                      TextButton(
                        onPressed: () => ref
                            .read(selectedDateProvider.notifier)
                            .jumpToToday(),
                        child: Text(l10n.commonToday),
                      ),
                    ];
                    final painter = TextPainter(
                      text: TextSpan(
                        text: l10n.commonToday,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final actionWidth = math.max(64.0, painter.width + 32) + 48;
                    painter.dispose();
                    if (constraints.maxWidth < 160 + actionWidth) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: actions,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: heading),
                        ...actions,
                      ],
                    );
                  },
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
                // The add button is stacked over the view rather than put in
                // Scaffold.floatingActionButton, because the user can drag it
                // and that slot owns its child's position. This Stack is
                // exactly the area it may be moved within: the view content,
                // below the header and switcher, so a parked button can never
                // cover the controls needed to get back from wherever it was
                // dragged to. Its own clearance from the floating nav bar is
                // handled inside it, since only it knows how tall it is.
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: switch (view) {
                        ScheduleView.day => DayView(day: selected),
                        ScheduleView.week => WeekView(anchor: selected),
                        ScheduleView.month => LayoutBuilder(
                          builder: (context, constraints) {
                            final size = constraints.biggest;
                            final layout = AppLayout.of(
                              context,
                              viewportSize: size,
                            );
                            final regions = layout.availableRegions;
                            if (regions.length > 1) {
                              final horizontal = regions.every(
                                (region) =>
                                    (region.top - regions.first.top).abs() < 1,
                              );
                              final ordered = [...regions]
                                ..sort(
                                  horizontal
                                      ? (a, b) => a.left.compareTo(b.left)
                                      : (a, b) => a.top.compareTo(b.top),
                                );
                              if (horizontal &&
                                  ordered.length >= 2 &&
                                  ordered[0].width >=
                                      _monthCalendarPaneMinWidth &&
                                  ordered[1].width >= _dayDetailPaneMinWidth &&
                                  ordered[0].height >= 600 &&
                                  ordered[1].height >= 600) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Positioned.fromRect(
                                      rect: ordered[0],
                                      child: MonthView(calendarOnly: true),
                                    ),
                                    Positioned.fromRect(
                                      rect: ordered[1],
                                      child: DayView(day: selected),
                                    ),
                                  ],
                                );
                              }
                              final vertical = regions.every(
                                (region) =>
                                    (region.left - regions.first.left).abs() <
                                    1,
                              );
                              if (vertical &&
                                  ordered.length >= 2 &&
                                  ordered[0].width >= 700 &&
                                  ordered[0].height >= 240 &&
                                  ordered[1].height >= 320) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Positioned.fromRect(
                                      rect: ordered[0],
                                      child: MonthView(calendarOnly: true),
                                    ),
                                    Positioned.fromRect(
                                      rect: ordered[1],
                                      child: DayView(day: selected),
                                    ),
                                  ],
                                );
                              }
                              final fallback = horizontal
                                  ? ordered.last
                                  : ordered.first;
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  Positioned.fromRect(
                                    rect: fallback,
                                    child: const MonthView(),
                                  ),
                                ],
                              );
                            }
                            // On a wide, comfortably tall iPad window keep
                            // the month grid and the selected day's timeline
                            // visible together. Narrow/short windows retain
                            // the existing full-width month view so the grid
                            // remains usable in Split View and landscape.
                            final twoPane =
                                size.width >= _monthTwoPaneMinWidth &&
                                size.height >= 600;
                            if (!twoPane) return const MonthView();
                            // PageView-backed day content is sensitive to
                            // fractional viewport widths in Flutter's sliver
                            // precision checks. Round the calendar pane to a
                            // logical pixel and give the remainder to the
                            // detail pane while preserving the intended 55:45
                            // balance.
                            final calendarPaneWidth =
                                (constraints.maxWidth * 0.55).floorToDouble();
                            final dayPaneWidth =
                                constraints.maxWidth - calendarPaneWidth - 1;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: calendarPaneWidth,
                                  child: MonthView(calendarOnly: true),
                                ),
                                VerticalDivider(
                                  width: 1,
                                  color: palette.inkFaint.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                SizedBox(
                                  width: dayPaneWidth,
                                  child: DayView(day: selected),
                                ),
                              ],
                            );
                          },
                        ),
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
                    DraggableAddButton(
                      // The month view is the only one that draws a control
                      // inside this Stack's region — its calendar/timeline
                      // switcher, on viewports too short to show both. Read
                      // off the view rather than the switcher's own
                      // presence: whether it is showing depends on the
                      // month's row count and the height MonthView ends up
                      // with, neither of which is known here, and reserving
                      // the strip on a tall month view costs only the top
                      // 44pt of somewhere to park.
                      topInset: view == ScheduleView.month
                          ? kMonthTabBarHeight
                          : 0,
                      onPressed: () =>
                          showEventEditor(context, initialDay: selected),
                    ),
                  ],
                ),
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
    final target = _swipeTarget(
      view: view,
      selected: selected,
      forward: forward,
    );
    if (target != null) onNavigate(target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
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
            //
            // Always occupies its 44x44 footprint (invisible, not omitted,
            // on agenda) rather than being conditionally left out of the
            // Row entirely — omitting it made this Row's own height
            // agenda-specific (title-text-height alone, instead of the
            // taller of that and the chevron's 44px), which visibly
            // shifted the view-switcher row right below it up when agenda
            // was selected (confirmed live: every other view's title text
            // is shorter than 44px too, so the chevron was setting this
            // row's real height everywhere *except* agenda, not just on
            // day's own taller two-line title).
            swipeable
                ? _TitleChevron(
                    icon: Icons.chevron_left,
                    color: chevronColor,
                    semanticLabel: l10n.scheduleTitlePrevious,
                    onTap: () => _navigate(false),
                  )
                : const SizedBox(width: 44, height: 44),
            const SizedBox(width: 2),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FittedBox instead of a plain maxLines:1 + ellipsis Text:
                  // even the already-abbreviated formats (Fmt.fullDate,
                  // monthDayShort's week range) overflow to "…" on a
                  // realistic narrow phone width in *every* locale this
                  // was checked in, not just the specific en/ja cases
                  // shortened earlier — a real device (and, it turns out,
                  // a widget test pinned to a real ~360dp width, unlike
                  // this file's own tests' much wider default surface,
                  // which is exactly why that went unnoticed) is
                  // narrower than the abbreviated string at this style's
                  // point size needs. Scaling the whole line down to fit
                  // reads correctly regardless of locale, date, or screen
                  // width instead of chasing ever-shorter formats per
                  // locale — this can only ever shrink text that would
                  // otherwise be clipped, never grow it past its natural
                  // size, so a wide screen where it already fits renders
                  // identically to before.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title, style: style, maxLines: 1),
                  ),
                  if (lunarSubtitle != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        lunarSubtitle!,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: chevronColor),
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            swipeable
                ? _TitleChevron(
                    icon: Icons.chevron_right,
                    color: chevronColor,
                    semanticLabel: l10n.scheduleTitleNext,
                    onTap: () => _navigate(true),
                  )
                : const SizedBox(width: 44, height: 44),
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
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // No tooltip/Semantics here at all used to mean a VoiceOver/TalkBack
    // user tapping through the header heard nothing meaningful for these —
    // the only way to page the calendar by tap, since the swipe gesture
    // this sits beside has no semantic alternative either.
    return Semantics(
      button: true,
      label: semanticLabel,
      // The tappable area is forced up to the 44x44 accessibility floor
      // (Apple HIG / Material both recommend it) via this SizedBox, kept
      // separate from the 18px icon's own visual size so growing the tap
      // target doesn't also grow what's drawn — Center then places that
      // unchanged icon+padding in the middle of the bigger invisible box.
      child: SizedBox(
        width: 44,
        height: 44,
        child: InkResponse(
          onTap: onTap,
          radius: 18,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary creation stays directly accessible; secondary actions use a menu.
enum _ScheduleTool { legend, layout }

class _HeaderTrailingIcons extends ConsumerWidget {
  const _HeaderTrailingIcons({
    required this.view,
    required this.onQuickAdd,
    required this.onLegend,
  });
  final ScheduleView view;
  final VoidCallback onQuickAdd;
  final VoidCallback onLegend;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final mode = ref.watch(dayViewLayoutModeProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            tooltip: l10n.quickAddEventTitle,
            icon: const Icon(Icons.bolt_outlined),
            onPressed: onQuickAdd,
          ),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: PopupMenuButton<_ScheduleTool>(
            tooltip: l10n.scheduleTools,
            icon: const Icon(Icons.more_vert),
            onSelected: (tool) {
              if (tool == _ScheduleTool.legend) {
                onLegend();
              } else {
                ref
                    .read(dayViewLayoutModeProvider.notifier)
                    .set(
                      mode == DayViewLayoutMode.timeline
                          ? DayViewLayoutMode.clock
                          : DayViewLayoutMode.timeline,
                    );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _ScheduleTool.legend,
                child: Text(l10n.calendarLegendTooltip),
              ),
              if (view == ScheduleView.day)
                PopupMenuItem(
                  value: _ScheduleTool.layout,
                  child: Text(
                    mode == DayViewLayoutMode.timeline
                        ? l10n.dayLayoutSwitchToClock
                        : l10n.dayLayoutSwitchToTimeline,
                  ),
                ),
            ],
          ),
        ),
      ],
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
    final style = Theme.of(context).textTheme.labelLarge;
    final requiredWidth = entries.fold<double>(6, (total, entry) {
      final painter = TextPainter(
        text: TextSpan(text: entry.$2, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = math.max(48.0, painter.width + 24);
      painter.dispose();
      return total + width;
    });
    final decoration = BoxDecoration(
      color: palette.surface,
      borderRadius: AppRadius.allPill,
      border: Border.all(color: palette.hairline),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < requiredWidth) {
          return PopupMenuButton<ScheduleView>(
            key: const Key('schedule-view-menu'),
            initialValue: current,
            onSelected: onChanged,
            tooltip: entries.firstWhere((entry) => entry.$1 == current).$2,
            itemBuilder: (_) => [
              for (final entry in entries)
                CheckedPopupMenuItem(
                  value: entry.$1,
                  checked: current == entry.$1,
                  child: Text(entry.$2),
                ),
            ],
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: decoration,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entries.firstWhere((entry) => entry.$1 == current).$2,
                      style: style,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: decoration,
          child: Row(
            children: [
              for (final entry in entries)
                Expanded(
                  child: Semantics(
                    selected: entry.$1 == current,
                    button: true,
                    child: TextButton(
                      onPressed: () => onChanged(entry.$1),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: entry.$1 == current
                            ? accent
                            : Colors.transparent,
                        foregroundColor: entry.$1 == current
                            ? Colors.white
                            : palette.inkSoft,
                      ),
                      child: Text(
                        entry.$2,
                        style: style?.copyWith(
                          color: entry.$1 == current
                              ? Colors.white
                              : palette.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
