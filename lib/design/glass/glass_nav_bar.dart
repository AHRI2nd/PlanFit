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
      // The `* 0.0` this used to carry made the pill's bottom clearance a
      // flat AppSpacing.sm regardless of the device's own gesture-nav inset
      // — dead code since the very first commit, not a later regression.
      // Scaffold's bottomNavigationBar slot doesn't strip that inset from
      // MediaQuery (unlike its body slot with extendBody: true), so it's
      // there to read; adding it back lifts the floating pill clear of a
      // gesture-navigation bar on Android instead of sitting flush against
      // it.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.sm + MediaQuery.viewPaddingOf(context).bottom,
      ),
      // GlassSurface's own default rim already draws a border, but it's
      // palette.glassBorder — tuned to read as a subtle glass edge, not to
      // separate this bar from the content scrolling underneath it. One
      // plain black outline around the whole pill (not one per button —
      // the individual tap targets are wide enough already, and a border
      // is around the tune buttons too) gives it a clear edge.
      //
      // `position: foreground` matters here: DecoratedBox paints its
      // decoration *behind* the child by default, and GlassSurface's own
      // blurred, tinted fill is fully opaque-looking across its whole
      // bounds — it painted right over a background-positioned border,
      // hiding it completely (confirmed by sampling the rendered pixels:
      // no border color anywhere along the pill's edge). Foreground paints
      // this border after GlassSurface, on top of it, so it's actually
      // visible tracing the exact shape of the blurred area underneath.
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: AppRadius.allPill,
          border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
        ),
        child: GlassSurface(
          borderRadius: AppRadius.allPill,
          tint: palette.glassTint,
          // The bar's whole point is marking the boundary between content
          // and chrome — a flat blur reads as one uniform pane sitting on
          // top, where a blur that's barely there at the top edge and
          // fully frosted by the bottom reads instead as the content
          // itself fading into the bar, the same "frosted edge" any native
          // floating bottom bar uses.
          verticalBlurGradient: true,
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
                  selected ? item.activeIcon : item.icon,
                  size: 22,
                  color: fg,
                ),
              ),
              AnimatedSize(
                duration: context.motionDuration(
                  const Duration(milliseconds: 240),
                ),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: Text(
                          item.label,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: fg),
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
