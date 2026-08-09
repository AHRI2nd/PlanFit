import 'package:flutter/material.dart';

/// Type scale for PlanFit.
///
/// Uses the platform's native UI font (SF Pro on iOS, Roboto on Android) so the
/// app reads as at-home on each OS, but treats *time* as the protagonist: clock
/// numerals are large, tightly tracked and use tabular figures so digits never
/// jitter as the minutes tick.
class AppTypography {
  const AppTypography._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Oversized clock numerals for the home hero and day-view rail.
  static const TextStyle clock = TextStyle(
    fontSize: 56,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.5,
    fontFeatures: _tabular,
  );

  /// Medium time labels next to events.
  static const TextStyle clockSmall = TextStyle(
    fontSize: 15,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    fontFeatures: _tabular,
  );

  static TextTheme textTheme(Color ink, Color inkSoft) {
    TextStyle s(
      double size,
      FontWeight weight, {
      double height = 1.25,
      double spacing = 0,
      Color? color,
      bool tabular = false,
    }) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: spacing,
          color: color ?? ink,
          fontFeatures: tabular ? _tabular : null,
        );

    return TextTheme(
      displayLarge: s(40, FontWeight.w700, height: 1.05, spacing: -1.0),
      displayMedium: s(32, FontWeight.w700, height: 1.08, spacing: -0.6),
      headlineMedium: s(26, FontWeight.w700, height: 1.15, spacing: -0.4),
      headlineSmall: s(22, FontWeight.w600, height: 1.2, spacing: -0.2),
      titleLarge: s(19, FontWeight.w600, height: 1.25),
      titleMedium: s(16, FontWeight.w600, height: 1.3),
      bodyLarge: s(16, FontWeight.w400, height: 1.45, color: ink),
      bodyMedium: s(14, FontWeight.w400, height: 1.45, color: inkSoft),
      labelLarge: s(14, FontWeight.w600, height: 1.2, spacing: 0.1),
      labelMedium: s(12, FontWeight.w600, height: 1.2, spacing: 0.4),
      labelSmall: s(11, FontWeight.w600, height: 1.2, spacing: 0.6),
    );
  }
}
