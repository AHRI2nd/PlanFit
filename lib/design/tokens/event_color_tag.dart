import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A user-chosen color for an event, stored in [Events.colorTag] either as
/// the enum's name (e.g. `"amber"`) or, for a color picked from the full
/// palette, a `#RRGGBB` hex string — distinguishable since no enum name
/// starts with `#`.
///
/// `null` means "automatic": the event card falls back to the time-of-day
/// gradient accent, which is the pre-existing default behavior.
enum EventColorTag {
  indigo,
  sky,
  amber,
  violet,
  rose,
  sage;

  Color get color => switch (this) {
        EventColorTag.indigo => AppColors.dawnIndigo,
        EventColorTag.sky => AppColors.noonSky,
        EventColorTag.amber => AppColors.dayAmber,
        EventColorTag.violet => AppColors.nightViolet,
        EventColorTag.rose => AppColors.dustyRose,
        EventColorTag.sage => AppColors.sageGreen,
      };

  static EventColorTag? tryParse(String? raw) {
    if (raw == null) return null;
    for (final tag in EventColorTag.values) {
      if (tag.name == raw) return tag;
    }
    return null;
  }

  /// The color an event card should render with: a custom hex color or a
  /// preset tag if set, otherwise the time-of-day gradient accent at
  /// [fallbackTime].
  static Color resolve(String? rawTag, DateTime fallbackTime) {
    final custom = parseHex(rawTag);
    if (custom != null) return custom;
    return tryParse(rawTag)?.color ?? AppColors.timeGradient(fallbackTime).first;
  }

  /// Parses a `#RRGGBB` or `#AARRGGBB` string. Returns null for anything else
  /// (including preset tag names, which aren't hex).
  static Color? parseHex(String? raw) {
    if (raw == null || !raw.startsWith('#')) return null;
    final cleaned = raw.substring(1);
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(cleaned.length == 6 ? value | 0xFF000000 : value);
  }

  /// Renders [color] as the `#RRGGBB` form [parseHex] understands (alpha
  /// dropped — event color tags are always fully opaque).
  static String toHex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
