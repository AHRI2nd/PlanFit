import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// The ambient backdrop that makes "a day is a river of time" literal: a soft
/// vertical wash of the time-of-day gradient, sitting under the app's glass
/// surfaces. It settles over the scaffold background so dark and light both
/// keep their base while the accent glows through.
class TimeGradientBackground extends StatelessWidget {
  const TimeGradientBackground({
    super.key,
    required this.child,
    this.at,
    this.intensity = 1.0,
  });

  final Widget child;

  /// Moment that decides the gradient. Defaults to now.
  final DateTime? at;

  /// 0 = invisible, 1 = full strength. Day-view uses full; secondary surfaces
  /// dial it down.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = AppColors.timeGradient(at ?? DateTime.now());
    final glowAlpha = (palette.isDark ? 0.32 : 0.20) * intensity;

    return DecoratedBox(
      decoration: BoxDecoration(color: palette.background),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.first.withValues(alpha: glowAlpha),
                    colors.last.withValues(alpha: glowAlpha * 0.5),
                    palette.background.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.35, 0.72],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
