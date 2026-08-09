import 'package:flutter/material.dart';

/// Collapses animation durations to zero when the OS "reduce motion"
/// accessibility setting is on, instead of every `Animated*` widget and
/// manual `.animateTo`/`.nextPage` call needing its own check.
extension MotionContext on BuildContext {
  Duration motionDuration(Duration duration) =>
      MediaQuery.of(this).disableAnimations ? Duration.zero : duration;
}
