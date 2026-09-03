import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/tokens/app_colors.dart';

void main() {
  group('contrastRatio', () {
    test('black on white is the maximum, 21:1', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.01));
    });

    test('a color against itself is always 1:1', () {
      expect(contrastRatio(AppColors.dayAmber, AppColors.dayAmber), 1.0);
    });

    test('is symmetric — order of the two colors does not matter', () {
      final a = contrastRatio(AppColors.dawnIndigo, Colors.white);
      final b = contrastRatio(Colors.white, AppColors.dawnIndigo);
      expect(a, b);
    });
  });

  group('legibleOn', () {
    test('returns the color unchanged when it already clears the ratio', () {
      // Confirmed elsewhere in this app's own doc comments: dawnIndigo
      // clears 4.5:1 on softPaper.
      final result = legibleOn(
        const Color(0xFFF5F3EE),
        AppColors.dawnIndigo,
      );
      expect(result, AppColors.dawnIndigo);
    });

    test(
      'darkens a color that fails contrast on a light background, until it '
      "actually passes — regression test for exactly what wasn't happening "
      'anywhere before: dayAmber as literal text color measured 1.82:1 on '
      "softPaper, far below WCAG AA's 4.5:1 floor for normal text",
      () {
        const softPaper = Color(0xFFF5F3EE);
        expect(contrastRatio(AppColors.dayAmber, softPaper), lessThan(4.5));

        final adjusted = legibleOn(softPaper, AppColors.dayAmber);

        expect(contrastRatio(adjusted, softPaper), greaterThanOrEqualTo(4.5));
        // Same hue family, not just "some color that happens to pass" —
        // legibleOn only moves lightness, not hue/saturation.
        final originalHue = HSLColor.fromColor(AppColors.dayAmber).hue;
        final adjustedHue = HSLColor.fromColor(adjusted).hue;
        expect((adjustedHue - originalHue).abs(), lessThan(1.0));
      },
    );

    test('lightens a color that fails contrast on a dark background', () {
      const deepInk = Color(0xFF0E1116);
      final adjusted = legibleOn(deepInk, AppColors.dayAmber);
      expect(contrastRatio(adjusted, deepInk), greaterThanOrEqualTo(4.5));
    });

    test('every EventColorTag-family hue clears 4.5:1 on both theme '
        'backgrounds once adjusted', () {
      for (final hue in [
        AppColors.dawnIndigo,
        AppColors.dayAmber,
        AppColors.nightViolet,
        AppColors.noonSky,
        AppColors.dustyRose,
        AppColors.sageGreen,
      ]) {
        for (final background in [
          const Color(0xFFF5F3EE), // softPaper
          const Color(0xFF0E1116), // deepInk
        ]) {
          final adjusted = legibleOn(background, hue);
          expect(
            contrastRatio(adjusted, background),
            greaterThanOrEqualTo(4.5),
            reason: '$hue on $background should clear 4.5:1 once adjusted',
          );
        }
      }
    });
  });

  group('bestTextOn', () {
    test('picks white on a dark fill', () {
      expect(
        bestTextOn(AppColors.nightViolet, dark: const Color(0xFF1A1D24)),
        Colors.white,
      );
    });

    test(
      'picks the dark option on a light fill — regression test: a chip '
      "whose fill is a light hue (amber, sky, rose) unconditionally used "
      "white label text, which reads poorly against those specifically",
      () {
        const ink = Color(0xFF1A1D24);
        expect(bestTextOn(AppColors.dayAmber, dark: ink), ink);
      },
    );
  });
}
