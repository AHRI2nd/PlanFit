import 'package:flutter/material.dart';

import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/adaptive_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';

/// Extra bottom clearance reserved below the sheet's own content, on top of
/// [AppSpacing.lg] — [AppShell] runs its Scaffold with `extendBody: true` so
/// the floating Liquid-Glass tab bar (`GlassTabBar.bottom`'s default
/// `barHeight: 64`, plus its own vertical padding and margin from the screen
/// edge) paints *above* body content rather than reserving space for it. A
/// modal sheet inherits that same unreserved height, so content that reaches
/// the sheet's natural bottom edge renders underneath the tab bar instead of
/// above it — caught in live verification, where this sheet's closing info
/// box was invisible on a real device despite rendering fine (off-screen,
/// past flutter_test's default 800x600 surface) in the widget test. Sized
/// generously rather than exactly, since the tab bar's real footprint isn't
/// something this widget has a clean way to query.
const double _kFloatingNavBarClearance = 96;

/// Explains what the calendar dot's three colors mean — see
/// `calendar_dot.dart`'s own doc for the rule this restates in plain
/// language. The first explanatory UI of its kind in this app: every other
/// screen either shows a rule's effect directly or leans on a plain
/// always-visible note, never a tap-to-reveal sheet, so this establishes
/// the pattern other future ⓘ affordances can follow.
Future<void> showCalendarLegendSheet(BuildContext context) {
  return showAdaptiveBottomSheet(
    context: context,
    builder: (context) => const _CalendarLegendSheet(),
  );
}

class _CalendarLegendSheet extends StatelessWidget {
  const _CalendarLegendSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      // See _kFloatingNavBarClearance's own doc for why the bottom inset is
      // much larger than AppSpacing.lg alone.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.lg + _kFloatingNavBarClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.calendarLegendTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          _LegendRow(
            color: palette.danger,
            label: l10n.calendarLegendOverdueTodo,
          ),
          const SizedBox(height: AppSpacing.sm),
          _LegendRow(color: palette.todoAccent, label: l10n.calendarLegendTodo),
          const SizedBox(height: AppSpacing.sm),
          _LegendRow(color: palette.accent, label: l10n.calendarLegendEvent),
          const SizedBox(height: AppSpacing.md),
          // Same info-box language mirrored_event_detail_screen.dart's own
          // read-only note already uses.
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: AppRadius.cardMd,
              border: Border.all(color: palette.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: palette.inkFaint),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.calendarLegendMultiDayBarNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.inkFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
