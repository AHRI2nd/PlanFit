import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassTabBar, GlassTab;

import '../../design/glass/glass_nav_bar.dart';
import '../../design/tokens/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../schedule/application/schedule_providers.dart';
import '../todo/application/todo_providers.dart';

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
    final accent = AppColors.timeGradient(DateTime.now()).first;

    // Today's undone to-dos, surfaced as a badge on the schedule tab so a
    // pending day is visible without opening it.
    final todayTodos =
        ref.watch(todosForDayProvider(dateOnly(DateTime.now()))).asData?.value ??
            const [];
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
        icon: Icons.people_alt_outlined,
        activeIcon: Icons.people_alt,
        label: l10n.tabSocial,
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
          ? _IosGlassTabBar(
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
/// doesn't need two separate item lists.
class _IosGlassTabBar extends StatelessWidget {
  const _IosGlassTabBar({
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
    return GlassTabBar.bottom(
      tabs: [
        for (final item in items)
          GlassTab(
            icon: NavBadgeIcon(count: item.badgeCount, icon: Icon(item.icon)),
            activeIcon: NavBadgeIcon(
                count: item.badgeCount, icon: Icon(item.activeIcon)),
            label: item.label,
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
