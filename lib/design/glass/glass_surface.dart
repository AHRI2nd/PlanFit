import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// The core "Liquid Glass" material: a blurred backdrop, a saturation-lifting
/// tint, a hairline rim and a soft specular highlight sweeping across the top —
/// the three ingredients Apple's iOS 26 glass is built from, assembled with
/// [BackdropFilter] so it works on every platform Flutter targets.
///
/// This is deliberately the [BackdropFilter] approximation everywhere,
/// including iOS — `liquid_glass_widgets`' shader-based [GlassCard] was tried
/// here for real refraction, but its `useOwnLayer` blur leaks past its own
/// card bounds into unrelated content when several instances sit inside a
/// scrolling [ListView] (confirmed on-device: hero text far outside any card
/// went blurry). The nav bar is the one place real Liquid Glass is used (see
/// [AppShell]/`_IosGlassTabBar`) — it's a single, non-scrolling instance,
/// which is the case that actually renders correctly.
///
/// On iOS the blur and highlight run heavier so it reads as true Liquid Glass;
/// on Android the effect is dialed back and leans on the tint, closer to a
/// Material tonal surface. That intensity split lives in [_glassProfile].
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.cardLg,
    this.padding = EdgeInsets.zero,
    this.blur,
    this.tint,
    this.showHighlight = true,
    this.border = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  /// Blur sigma. Defaults to the platform profile when null.
  final double? blur;

  /// Overrides the palette glass tint (e.g. to pick up the time accent).
  final Color? tint;
  final bool showHighlight;
  final bool border;

  bool get _isApplePlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  ({double blur, double highlight, double tintBoost}) get _glassProfile =>
      _isApplePlatform
          ? (blur: AppBlur.heavy, highlight: 0.35, tintBoost: 1.0)
          : (blur: AppBlur.regular, highlight: 0.16, tintBoost: 1.25);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final profile = _glassProfile;
    final effectiveBlur = blur ?? profile.blur;
    final tintColor = Color.alphaBlend(
      (tint ?? palette.glassTint),
      Colors.transparent,
    );

    // The dark palette's surfaces are already near-black, so the same
    // highlight alpha that reads as a subtle sheen on light glass turns into
    // a visible white wash in dark mode — dial it down hard there.
    final highlightColor = palette.isDark
        ? Colors.white.withValues(alpha: profile.highlight * 0.35)
        : Colors.white.withValues(alpha: profile.highlight * 1.1);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: tintColor,
            border: border
                ? Border.all(color: palette.glassBorder, width: 1)
                : null,
          ),
          child: Stack(
            children: [
              if (showHighlight)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            highlightColor,
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
