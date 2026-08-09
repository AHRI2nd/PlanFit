import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/tokens/app_colors.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';

/// WCAG relative luminance / contrast ratio — used to lock in the AA fixes
/// made to [AppPalette.inkFaint] and [AppPalette.danger] (see the doc
/// comments on those fields) so a future edit can't silently regress them.
double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppPalette contrast (WCAG AA)', () {
    test('light.inkFaint clears 4.5:1 on light.background', () {
      expect(
        _contrast(AppPalette.light.inkFaint, AppPalette.light.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark.inkFaint clears 4.5:1 on dark.background', () {
      expect(
        _contrast(AppPalette.dark.inkFaint, AppPalette.dark.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light.danger clears 4.5:1 on light.background', () {
      expect(
        _contrast(AppPalette.light.danger, AppPalette.light.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark.danger clears 4.5:1 on dark.background', () {
      expect(
        _contrast(AppPalette.dark.danger, AppPalette.dark.background),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('dateOnly', () {
    test('strips the time component', () {
      final result = dateOnly(DateTime(2026, 7, 20, 14, 33, 9));
      expect(result, DateTime(2026, 7, 20));
    });
  });

  group('startOfWeek', () {
    // 2026-07-30 is a Thursday.
    final thursday = DateTime(2026, 7, 30);
    final sunday = DateTime(2026, 7, 26);
    final monday = DateTime(2026, 7, 27);
    final saturday = DateTime(2026, 8, 1);

    test('defaults to Monday as the first day', () {
      expect(startOfWeek(thursday), DateTime(2026, 7, 27));
    });

    test('a Sunday belongs to the week that started the prior Monday', () {
      expect(startOfWeek(sunday), DateTime(2026, 7, 20));
    });

    test('Sunday-start treats Sunday itself as day one', () {
      expect(startOfWeek(sunday, startWeekday: DateTime.sunday), sunday);
    });

    test('Sunday-start walks a Monday back to the previous Sunday', () {
      expect(startOfWeek(monday, startWeekday: DateTime.sunday), sunday);
    });

    test('Sunday-start walks a Saturday back to that week\'s Sunday', () {
      expect(startOfWeek(saturday, startWeekday: DateTime.sunday), sunday);
    });
  });

  group('timeGradient', () {
    test('returns two stops that shift across the day', () {
      final morning = AppColors.timeGradient(DateTime(2026, 7, 20, 8));
      final evening = AppColors.timeGradient(DateTime(2026, 7, 20, 20));
      expect(morning.length, 2);
      expect(evening.length, 2);
      expect(morning.first, isNot(evening.first));
    });
  });
}
