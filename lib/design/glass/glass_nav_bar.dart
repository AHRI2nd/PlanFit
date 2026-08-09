import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_motion.dart';
import '../tokens/app_spacing.dart';
import 'glass_surface.dart';

/// A single destination in the [GlassNavBar].
class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// A small count badge on the tab's icon (e.g. today's undone to-dos).
  /// Zero or negative means no badge is shown.
  final int badgeCount;
}

/// Overlays [icon] with a small red count badge — shared by both the native
/// iOS Liquid Glass tab bar and [GlassNavBar] so a badge looks identical
/// regardless of which chrome renders it. No-ops when [count] isn't positive.
class NavBadgeIcon extends StatelessWidget {
  const NavBadgeIcon({super.key, required this.icon, required this.count});

  final Widget icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return icon;
    return Badge(
      label: Text(count > 9 ? '9+' : '$count'),
      backgroundColor: context.palette.danger,
      textColor: Colors.white,
      child: icon,
    );
  }
}

/// The floating Liquid-Glass bottom navigation bar — PlanFit's signature
/// chrome. It hovers above the content on a blurred glass pill; the selected
/// destination slides a soft accent "lozenge" beneath it that refracts the
/// time-of-day color the rest of the app is tinted with.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.accent,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// The current time-of-day accent, driving the selected lozenge.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.sm + MediaQuery.viewPaddingOf(context).bottom * 0.0,
      ),
      child: GlassSurface(
        borderRadius: AppRadius.allPill,
        tint: palette.glassTint,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  item: items[i],
                  selected: i == currentIndex,
                  accent: accent,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = selected ? accent : palette.inkSoft;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allPill,
        child: AnimatedContainer(
          duration: context.motionDuration(const Duration(milliseconds: 280)),
          curve: Curves.easeOutCubic,
          height: AppSpacing.touchTarget,
          decoration: BoxDecoration(
            borderRadius: AppRadius.allPill,
            gradient: selected
                ? LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.28),
                      accent.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NavBadgeIcon(
                count: item.badgeCount,
                icon: Icon(
                    selected ? item.activeIcon : item.icon, size: 22, color: fg),
              ),
              AnimatedSize(
                duration: context.motionDuration(const Duration(milliseconds: 240)),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: Text(
                          item.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: fg),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
