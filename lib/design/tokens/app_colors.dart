import 'package:flutter/material.dart';

/// PlanFit color tokens.
///
/// The identity is "a day as a river of time": a quiet ink/paper base with a
/// single time-of-day gradient accent that shifts from dawn indigo through
/// midday amber to night violet. Everything else stays disciplined so the
/// gradient — and the glass that refracts it — stays the one memorable thing.
class AppColors {
  const AppColors._();

  // --- Brand accents: the day's arc ---
  static const Color dawnIndigo = Color(0xFF4B5FD6);
  static const Color dayAmber = Color(0xFFF2A65A);
  static const Color nightViolet = Color(0xFF7C5CBF);
  static const Color noonSky = Color(0xFF52B6C4);

  // --- Extra event-tag hues (outside the day's-arc family, for user choice) ---
  static const Color dustyRose = Color(0xFFE597B0);
  static const Color sageGreen = Color(0xFF7FA88F);

  /// Fixed color for auto-imported holiday events (see
  /// `HolidayCalendarService`) — stored as a `#RRGGBB` `colorTag` (via
  /// `EventColorTag.toHex`) rather than added to the [EventColorTag] enum
  /// itself, since a holiday's color is never something the user picks;
  /// it's applied programmatically so a holiday reads as visually distinct
  /// from any user-chosen preset across every view that colors events by
  /// `colorTag`.
  static const Color holidayRed = Color(0xFFC0392B);

  // --- Ink (dark surfaces / light text) ---
  static const Color deepInk = Color(0xFF0E1116);
  static const Color ink800 = Color(0xFF161A22);
  static const Color ink700 = Color(0xFF1E2330);

  // --- Paper (light surfaces / dark text) ---
  static const Color softPaper = Color(0xFFF5F3EE);
  static const Color paper100 = Color(0xFFFBFAF6);
  static const Color paper200 = Color(0xFFEBE7DE);

  /// The time-of-day accent gradient stops for a given moment.
  ///
  /// Used behind the home hero and the day-view timeline so the background
  /// literally moves with the clock.
  static List<Color> timeGradient(DateTime at) {
    final t = at.hour + at.minute / 60.0; // 0..24
    // Anchor colors around the day's arc, then blend between the two nearest.
    const stops = <(double, Color)>[
      (0, nightViolet),
      (5, dawnIndigo),
      (9, noonSky),
      (13, dayAmber),
      (18, dayAmber),
      (21, nightViolet),
      (24, nightViolet),
    ];
    Color base = nightViolet;
    for (var i = 0; i < stops.length - 1; i++) {
      final (h0, c0) = stops[i];
      final (h1, c1) = stops[i + 1];
      if (t >= h0 && t <= h1) {
        final f = h1 == h0 ? 0.0 : (t - h0) / (h1 - h0);
        base = Color.lerp(c0, c1, f)!;
        break;
      }
    }
    final second = Color.lerp(base, nightViolet, 0.45)!;
    return [base, second];
  }
}

/// Semantic, theme-aware color tokens exposed to widgets via [ThemeExtension].
///
/// Widgets read `Theme.of(context).extension<AppPalette>()!` (or the
/// `context.palette` helper) instead of hard-coding hex values, so light and
/// dark stay in lockstep.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.hairline,
    required this.accent,
    required this.danger,
    required this.glassTint,
    required this.glassBorder,
    required this.onGlass,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color hairline;

  /// The current time-of-day accent (single, dynamic).
  final Color accent;

  /// Destructive-action red — split per theme (unlike most tokens here,
  /// which reuse the same hex both ways) because a single value can't clear
  /// WCAG AA 4.5:1 text contrast against both a light and a dark background.
  final Color danger;

  /// Tint painted over a blurred backdrop to build the glass material.
  final Color glassTint;
  final Color glassBorder;

  /// Foreground color that reads well on top of glass over the gradient.
  final Color onGlass;

  final bool isDark;

  static const AppPalette light = AppPalette(
    background: AppColors.softPaper,
    surface: AppColors.paper100,
    surfaceRaised: Colors.white,
    ink: Color(0xFF1A1D24),
    inkSoft: Color(0xFF565B66),
    // 4.53:1 on softPaper (was 969AA3 at 2.54:1 — failed WCAG AA for text).
    inkFaint: Color(0xFF6B6F7A),
    hairline: Color(0x14000000),
    accent: AppColors.dawnIndigo,
    // 4.52:1 on softPaper (was E5646E at 2.97:1 — failed WCAG AA for text).
    danger: Color(0xFFD72432),
    glassTint: Color(0x40FFFFFF),
    glassBorder: Color(0x33FFFFFF),
    onGlass: Color(0xFF1A1D24),
    isDark: false,
  );

  static const AppPalette dark = AppPalette(
    background: AppColors.deepInk,
    surface: AppColors.ink800,
    surfaceRaised: AppColors.ink700,
    ink: Color(0xFFF3F1EC),
    inkSoft: Color(0xFFA7ABB5),
    // 4.52:1 on deepInk (was 6B6F7A at 3.76:1 — failed WCAG AA for text).
    inkFaint: Color(0xFF777C88),
    hairline: Color(0x1AFFFFFF),
    accent: AppColors.dawnIndigo,
    // 5.75:1 on deepInk — already passed, unchanged.
    danger: Color(0xFFE5646E),
    glassTint: Color(0x33141A24),
    glassBorder: Color(0x26FFFFFF),
    onGlass: Color(0xFFF3F1EC),
    isDark: true,
  );

  /// Returns a copy whose [accent] tracks the given moment.
  AppPalette withTimeAccent(DateTime at) =>
      copyWith(accent: AppColors.timeGradient(at).first);

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? hairline,
    Color? accent,
    Color? danger,
    Color? glassTint,
    Color? glassBorder,
    Color? onGlass,
    bool? isDark,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkFaint: inkFaint ?? this.inkFaint,
      hairline: hairline ?? this.hairline,
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      onGlass: onGlass ?? this.onGlass,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      onGlass: Color.lerp(onGlass, other.onGlass, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Ergonomic access: `context.palette` and `context.textThemeX`.
extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
