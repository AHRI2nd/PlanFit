import 'package:flutter/widgets.dart';

/// Spacing, radius and elevation-blur tokens on a 4pt base grid.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Comfortable page gutter.
  static const double gutter = 20;

  /// Minimum touch target (accessibility floor).
  static const double touchTarget = 48;
}

/// Corner radii — soft, continuous-feeling curves that suit the glass material.
class AppRadius {
  const AppRadius._();

  static const Radius xs = Radius.circular(10);
  static const Radius sm = Radius.circular(14);
  static const Radius md = Radius.circular(20);
  static const Radius lg = Radius.circular(28);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius cardMd = BorderRadius.all(md);
  static const BorderRadius cardLg = BorderRadius.all(lg);
  static const BorderRadius allPill = BorderRadius.all(pill);
}

/// Glass blur strengths. iOS leans heavier to read as Liquid Glass; Android
/// stays lighter and defers to tonal surfaces.
class AppBlur {
  const AppBlur._();

  static const double subtle = 8;
  static const double regular = 18;
  static const double heavy = 30;
}
