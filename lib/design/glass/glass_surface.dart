import 'dart:io' show Platform;
import 'dart:math' as math;
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
    this.verticalBlurGradient = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  /// Blur sigma. Defaults to the platform profile when null. With
  /// [verticalBlurGradient], this is the strength reached at the *bottom*
  /// edge rather than a flat amount across the whole surface.
  final double? blur;

  /// Overrides the palette glass tint (e.g. to pick up the time accent).
  final Color? tint;
  final bool showHighlight;
  final bool border;

  /// Fades the blur in from ~nothing at the top edge to full strength at
  /// the bottom, instead of one flat amount everywhere — the "frosted
  /// bottom bar" look most floating nav bars use, rather than a uniform
  /// pane of glass. False everywhere except [GlassNavBar]'s own use of
  /// this surface, since a flat blur is the right, cheaper default for a
  /// card or sheet that isn't specifically a bottom-edge bar.
  final bool verticalBlurGradient;

  bool get _isApplePlatform => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

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
      child: Stack(
        children: [
          if (verticalBlurGradient)
            Positioned.fill(child: ProgressiveBlur(maxBlur: effectiveBlur))
          else
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveBlur,
                  sigmaY: effectiveBlur,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          DecoratedBox(
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
        ],
      ),
    );
  }
}

/// Approximates a blur whose strength ramps from ~0 at the top edge to
/// [maxBlur] at the bottom — used both by [GlassSurface.verticalBlurGradient]
/// (clipped to one rounded surface's own bounds) and, unclipped, as
/// [GlassNavBar]'s full-width backdrop behind the pill itself, so content
/// sliding past the pill's own left/right margins reads as blurred too,
/// not just whatever's directly behind the glass shape.
///
/// [BackdropFilter] itself has no notion of "how much" per pixel — one
/// filter, one sigma, applied flatly across its whole bounds. The standard
/// way around that (the same one behind every "frosted edge" effect in
/// native iOS/Android chrome) is to stack several equal, *flat* blurs, each
/// clipped to its own band so lower bands sit under more of them than
/// higher ones do.
///
/// A first attempt faded each layer in with a [ShaderMask] gradient instead
/// of a hard [ClipRect] band, for a smoother ramp than this version's
/// visible steps — and rendered as no blur at all (confirmed on a real
/// device: text behind the bar stayed perfectly sharp all the way to the
/// bottom edge). [ShaderMask] paints its child into its own offscreen layer
/// before applying the shader, and a [BackdropFilter] inside that layer can
/// only sample what's already been painted *within that same layer* — which
/// for a freshly-opened offscreen buffer is nothing, not the real page
/// content behind the whole bar. [ClipRect] doesn't have that problem: it
/// constrains a [BackdropFilter]'s bounds without isolating it into a new
/// layer, which is exactly what the outermost [ClipRRect] around
/// [GlassSurface] already relies on — and which [GlassNavBar]'s own bounds
/// (a plain rectangle, no rounding needed) provide just as well on their own.
///
/// Each layer here spans from its own start band down to the bottom edge
/// (not a slice of just its own band), so a later, lower-starting layer
/// paints its own additional blur on top of a region every earlier layer
/// already blurred — compounding toward the bottom rather than replacing
/// what came before. Successive Gaussian blurs compound roughly as
/// `sqrt(sum of each sigma²)`, so [layerCount] equal-strength layers all
/// active at the bottom need each sized at `maxBlur / sqrt(layerCount)` to
/// land back on [maxBlur] there rather than `layerCount × maxBlur`. More
/// layers reads as a smoother ramp (fewer, larger visible steps otherwise);
/// this keeps to a handful since each one is its own [BackdropFilter] pass
/// and this sits on a chrome element that's on-screen for the whole
/// session, not a one-off.
class ProgressiveBlur extends StatelessWidget {
  const ProgressiveBlur({super.key, required this.maxBlur});

  final double maxBlur;

  static const layerCount = 6;

  @override
  Widget build(BuildContext context) {
    final perLayer = maxBlur / math.sqrt(layerCount);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          children: [
            for (var i = 0; i < layerCount; i++)
              Positioned(
                top: height * i / layerCount,
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: perLayer,
                      sigmaY: perLayer,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
