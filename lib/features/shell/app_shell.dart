import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassTabBar, GlassTab;

import '../../core/clock.dart';
import '../../design/glass/glass_nav_bar.dart';
import '../../design/glass/glass_surface.dart' show ProgressiveBlur;
import '../../design/tokens/app_colors.dart';
import '../../design/tokens/app_spacing.dart' show AppBlur;
import '../../l10n/app_localizations.dart';
import '../schedule/application/schedule_providers.dart';
import '../todo/application/todo_providers.dart';

/// The screen-reader label for [item] on the iOS Liquid Glass tab bar —
/// pulled out as its own pure, top-level function purely so it's directly
/// unit-testable without needing `Platform.isIOS` to actually be true (see
/// [AppShell.build]'s own `_useNativeLiquidGlass` gate, which this label is
/// only ever used behind).
///
/// `liquid_glass_widgets`' own [GlassTab] wraps a tab's icon in
/// `ExcludeSemantics` and otherwise falls back to plain `label` — so a
/// badge count is invisible to VoiceOver on this tab bar unless spelled out
/// here explicitly. [GlassNavBar] (the non-iOS fallback) has no such
/// exclusion and picks its own badge `Text` up for free via ordinary
/// semantics merging, which is why only this path needs it.
@visibleForTesting
String iosTabSemanticLabel(AppL10n l10n, GlassNavItem item) =>
    item.badgeCount > 0
    ? l10n.tabBadgeSemanticLabel(item.label, item.badgeCount)
    : item.label;

/// The persistent chrome around the four tabs: content fills the screen and a
/// floating Liquid-Glass nav bar hovers over it, so the time-of-day gradient
/// shows through the glass.
///
/// On iOS this is real shader-based Liquid Glass ([GlassTabBar.bottom], from
/// `liquid_glass_widgets` — Impeller-only shader refraction, the closest
/// Flutter gets to Apple's iOS 26 material). Everywhere else it falls back to
/// [GlassNavBar], our hand-rolled `BackdropFilter` approximation, since the
/// design calls for a lighter Material-leaning touch on Android anyway.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static bool get _useNativeLiquidGlass => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    // Watches nowTickerProvider rather than computing DateTime.now()
    // directly — same staleness this widget's own todayProvider fix
    // addresses for the badge below, but for the tab bar's time-of-day
    // accent: without this, the accent color froze at whatever time it was
    // when AppShell last happened to rebuild, which a StatefulShellRoute
    // branch switch alone never triggers.
    final now = ref.watch(nowTickerProvider).asData?.value ?? DateTime.now();
    final accent = AppColors.timeGradient(now).first;

    // Today's undone to-dos, surfaced as a badge on the schedule tab so a
    // pending day is visible without opening it. Watches `todayProvider`
    // rather than computing `dateOnly(DateTime.now())` directly — see that
    // provider's own doc for why that distinction matters specifically for
    // this widget (a StatefulShellRoute branch's cached page doesn't
    // rebuild on every ancestor rebuild the way an ordinary widget does).
    final today = ref.watch(todayProvider);
    final todayTodos =
        ref.watch(todosForDayProvider(today)).asData?.value ?? const [];
    final undoneToday = todayTodos.where((t) => !t.isDone).length;

    final items = <GlassNavItem>[
      GlassNavItem(
        icon: Icons.wb_twilight_outlined,
        activeIcon: Icons.wb_twilight,
        label: l10n.tabHome,
      ),
      GlassNavItem(
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today,
        label: l10n.tabSchedule,
        badgeCount: undoneToday,
      ),
      GlassNavItem(
        icon: Icons.tune_outlined,
        activeIcon: Icons.tune,
        label: l10n.tabSettings,
      ),
    ];

    void onTap(int index) => navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _useNativeLiquidGlass
          ? IosGlassTabBar(
              items: items,
              currentIndex: navigationShell.currentIndex,
              accent: accent,
              onTap: onTap,
            )
          : GlassNavBar(
              items: items,
              currentIndex: navigationShell.currentIndex,
              accent: accent,
              onTap: onTap,
            ),
    );
  }
}

/// Wraps [GlassTabBar.bottom] with our [GlassNavItem] model so [AppShell]
/// doesn't need two separate item lists, and adds the full-width backdrop
/// blur ramp behind it.
///
/// The blur has to live here rather than come from the package:
/// [GlassTabBar.bottom] exposes no blur parameter at all — its own
/// back-blur is hardcoded to `blur: 3` internally (documented there as a
/// "subtle frosted back-blur"), which is close enough to nothing that
/// content scrolling under the bar stayed fully sharp on device. Every
/// blur change made for Android went into [GlassNavBar], which iOS never
/// builds, so iOS had no blur on any tab. Same [ProgressiveBlur] and same
/// Stack shape as [GlassNavBar] uses, so both platforms share one
/// top-to-bottom ramp; only the strength differs (heavier on iOS, where
/// the glass pill itself is more transparent than our Android surface).
///
/// Public (rather than library-private like the rest of this file's helpers)
/// only so a widget test can pump it directly: [AppShell] picks between this
/// and [GlassNavBar] on `Platform.isIOS`, which flutter_test can't flip, so
/// an iOS-only rendering regression is otherwise invisible to the suite —
/// exactly how the missing blur above went unnoticed for several commits.
@visibleForTesting
class IosGlassTabBar extends StatelessWidget {
  const IosGlassTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.accent,
    required this.onTap,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final Color accent;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Stack(
      children: [
        Positioned(
          // Starts at the *pill's* own top edge, not the widget's.
          // GlassTabBar.bottom lays its pill out as a `barHeight`-tall box
          // inside `EdgeInsets.symmetric(vertical: verticalPadding)`, so the
          // widget this Stack is sized by stands [_barVerticalPadding]
          // taller than anything visible. Filling the Stack instead started
          // the ramp that far above the bar, blurring a strip of content
          // sitting in plain open space above it.
          top: _barVerticalPadding,
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(child: ProgressiveBlur(maxBlur: AppBlur.heavy)),
        ),
        _tabBar(context, l10n),
      ],
    );
  }

  /// Passed to [GlassTabBar.bottom] explicitly rather than left to its own
  /// identical default, because the blur above has to know it — a package
  /// default that drifted in an upgrade would silently pull the ramp's top
  /// edge off the pill's.
  static const double _barVerticalPadding = 20;

  Widget _tabBar(BuildContext context, AppL10n l10n) {
    return GlassTabBar.bottom(
      verticalPadding: _barVerticalPadding,
      tabs: [
        for (final item in items)
          GlassTab(
            icon: NavBadgeIcon(count: item.badgeCount, icon: Icon(item.icon)),
            activeIcon: NavBadgeIcon(
              count: item.badgeCount,
              icon: Icon(item.activeIcon),
            ),
            label: item.label,
            semanticLabel: iosTabSemanticLabel(l10n, item),
            glowColor: accent,
          ),
      ],
      selectedIndex: currentIndex,
      onTabSelected: onTap,
      // The indicator pill is a solid accent fill — pair it with white
      // icon/label (as the package's own examples do), not the same accent,
      // or the selected tab's content disappears into its own background.
      indicatorColor: accent,
      selectedIconColor: Colors.white,
      selectedLabelColor: Colors.white,
    );
  }
}
