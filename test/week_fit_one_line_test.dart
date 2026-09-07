import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/presentation/week_view/week_view.dart';

const _style = TextStyle(fontSize: 11);

double _widthOf(String s) {
  final painter = TextPainter(
    text: TextSpan(text: s, style: _style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

void main() {
  test('returns the text unchanged once it already fits', () {
    expect(fitOneLine(text: 'Hi', style: _style, maxWidth: 500), 'Hi');
  });

  test('returns the empty string unchanged', () {
    expect(fitOneLine(text: '', style: _style, maxWidth: 500), '');
  });

  test(
    'truncates with a trailing ellipsis when the text does not fit — '
    'regression test for Text\'s own maxLines/overflow: ellipsis '
    'rendering nothing at all (not even a clipped character) at the '
    'extremely narrow widths a crowded week-view column can have',
    () {
      final result = fitOneLine(
        text: '아주 긴 일정 제목입니다',
        style: _style,
        maxWidth: 30,
      );
      expect(result, isNot('아주 긴 일정 제목입니다'));
      expect(result, endsWith('…'));
    },
  );

  test('never returns a string whose own rendered width exceeds maxWidth', () {
    for (final maxWidth in [1.0, 5.0, 10.0, 20.0, 30.0, 50.0, 100.0]) {
      final result = fitOneLine(
        text: '밥먹기 회의 준비 자료 정리',
        style: _style,
        maxWidth: maxWidth,
      );
      expect(
        _widthOf(result),
        lessThanOrEqualTo(maxWidth),
        reason: 'at maxWidth $maxWidth, fitOneLine returned "$result"',
      );
    }
  });

  test(
    'returns an empty string rather than overflow when not even the '
    'ellipsis glyph itself fits',
    () {
      final result = fitOneLine(
        text: 'Anything',
        style: _style,
        maxWidth: 0.5,
      );
      expect(result, '');
    },
  );

  test('a maxWidth of zero (or less) is a no-op, not a crash', () {
    expect(fitOneLine(text: 'Hi', style: _style, maxWidth: 0), 'Hi');
    expect(fitOneLine(text: 'Hi', style: _style, maxWidth: -5), 'Hi');
  });

  test(
    'falls back to a single bare character — real content, not just a dot '
    '— when maxWidth is too narrow even for one character plus an ellipsis '
    '(the width a 2-way cascaded week-view card can actually have)',
    () {
      // Wide enough for one glyph alone, but not for glyph + ellipsis:
      // widthOf() is monotonic in codepoint count for any real font, so a
      // maxWidth strictly between the two is guaranteed to land here.
      final oneChar = _widthOf('밥');
      final oneCharPlusEllipsis = _widthOf('밥…');
      expect(oneChar, lessThan(oneCharPlusEllipsis));
      final maxWidth = (oneChar + oneCharPlusEllipsis) / 2;

      final result = fitOneLine(text: '밥먹기', style: _style, maxWidth: maxWidth);
      expect(result, '밥');
    },
  );

  group('fitLines', () {
    test('returns a single-element list once the text already fits', () {
      expect(
        fitLines(text: 'Hi', style: _style, maxWidth: 500, maxLines: 2),
        ['Hi'],
      );
    });

    test('returns the empty string unchanged', () {
      expect(
        fitLines(text: '', style: _style, maxWidth: 500, maxLines: 2),
        [''],
      );
    });

    test('a maxWidth of zero (or less) is a no-op, not a crash', () {
      expect(
        fitLines(text: 'Hi', style: _style, maxWidth: 0, maxLines: 2),
        ['Hi'],
      );
      expect(
        fitLines(text: 'Hi', style: _style, maxWidth: -5, maxLines: 2),
        ['Hi'],
      );
    });

    test('a maxLines of zero (or less) returns no lines at all', () {
      expect(
        fitLines(text: 'Hi', style: _style, maxWidth: 500, maxLines: 0),
        <String>[],
      );
      expect(
        fitLines(text: 'Hi', style: _style, maxWidth: 500, maxLines: -1),
        <String>[],
      );
    });

    test(
      'wraps overflowing text onto a real second line — regression test '
      'for Text(maxLines: 2) reporting two wrapped lines in its own layout '
      'metrics but silently painting only the first one at a cascaded '
      "card's narrow width",
      () {
        // Wide enough for two glyphs but not three, so '밥먹기' (3
        // characters) is guaranteed to need a second line.
        final twoChars = _widthOf('밥먹');
        final threeChars = _widthOf('밥먹기');
        expect(twoChars, lessThan(threeChars));
        final maxWidth = (twoChars + threeChars) / 2;

        final result = fitLines(
          text: '밥먹기',
          style: _style,
          maxWidth: maxWidth,
          maxLines: 2,
        );
        expect(result, hasLength(2));
        expect(result[0], '밥먹');
        expect(result[1], isNotEmpty);
      },
    );

    test(
      'keeps wrapping onto a third (and further) line when maxLines allows '
      'it — this is the whole point of generalizing past a fixed two-line '
      "cap: a tall event card's box should get as many lines as its own "
      'height allows, not be stuck at two',
      () {
        // One glyph per line, five glyphs of text, plenty of maxLines —
        // every glyph should end up on its own line.
        final oneChar = _widthOf('밥');
        final twoChars = _widthOf('밥먹');
        expect(oneChar, lessThan(twoChars));
        final maxWidth = (oneChar + twoChars) / 2;

        final result = fitLines(
          text: '밥먹기회의',
          style: _style,
          maxWidth: maxWidth,
          maxLines: 10,
        );
        expect(result, ['밥', '먹', '기', '회', '의']);
      },
    );

    test(
      'stops at maxLines even when more text remains, ellipsizing the '
      'last line',
      () {
        // Two glyphs per line, with more than two glyphs still left over
        // for the last line — enough room there for fitOneLine to prefer
        // a real ellipsis over its own bare-character fallback (see
        // fitOneLine's own tests for when that fallback instead applies).
        final twoChars = _widthOf('밥먹');
        final threeChars = _widthOf('밥먹기');
        expect(twoChars, lessThan(threeChars));
        final maxWidth = (twoChars + threeChars) / 2;

        final result = fitLines(
          text: '밥먹기회의록',
          style: _style,
          maxWidth: maxWidth,
          maxLines: 2,
        );
        expect(result, hasLength(2));
        expect(result[0], '밥먹');
        expect(result[1], endsWith('…'));
      },
    );

    test(
      'each line never renders wider than maxWidth, across a range of '
      'widths and line counts',
      () {
        for (final maxWidth in [1.0, 5.0, 10.0, 20.0, 30.0, 50.0, 100.0]) {
          for (final maxLines in [1, 2, 3, 5]) {
            final lines = fitLines(
              text: '밥먹기 회의 준비 자료 정리',
              style: _style,
              maxWidth: maxWidth,
              maxLines: maxLines,
            );
            expect(lines.length, lessThanOrEqualTo(maxLines));
            for (final line in lines) {
              expect(
                _widthOf(line),
                lessThanOrEqualTo(maxWidth),
                reason:
                    'at maxWidth $maxWidth / maxLines $maxLines, fitLines '
                    'returned $lines',
              );
            }
          }
        }
      },
    );

    test(
      'falls back to fitOneLine\'s own single-line result when not even '
      'one character fits on a line',
      () {
        final result = fitLines(
          text: 'Anything',
          style: _style,
          maxWidth: 0.5,
          maxLines: 2,
        );
        expect(result, [
          fitOneLine(text: 'Anything', style: _style, maxWidth: 0.5),
        ]);
      },
    );
  });

  group('lineHeightOf', () {
    test('returns a positive height for a normal style', () {
      expect(lineHeightOf(_style), greaterThan(0));
    });

    test(
      'scales with the given textScaler instead of always measuring at '
      "the default (unscaled) size — regression test: this used to "
      "construct its TextPainter with no textScaler at all, so it always "
      'measured at 1.0x regardless of the app\'s own accessibility '
      'text-scale clamp (app.dart allows up to 1.3x); the maxLines '
      "budget this feeds into then came out too generous once the "
      "actual Text widgets rendered at the real (larger) scale, needing "
      "more room than was budgeted for",
      () {
        final unscaled = lineHeightOf(_style);
        final scaled = lineHeightOf(
          _style,
          textScaler: const TextScaler.linear(1.3),
        );
        // Not an exact *1.3 check — TextPainter/font-metric rounding at
        // different scales isn't perfectly linear to the sub-pixel — just
        // that scaling actually happened, by roughly the expected amount.
        expect(scaled, greaterThan(unscaled));
        expect(scaled, closeTo(unscaled * 1.3, 1.0));
      },
    );
  });

  group('fitOneLine/fitLines respect textScaler for width fitting too', () {
    test(
      'fitOneLine truncates more aggressively at a larger scale, since '
      'each character is genuinely wider then',
      () {
        const text = 'A moderately long event title';
        const maxWidth = 80.0;
        final unscaled = fitOneLine(
          text: text,
          style: _style,
          maxWidth: maxWidth,
        );
        final scaled = fitOneLine(
          text: text,
          style: _style,
          maxWidth: maxWidth,
          textScaler: const TextScaler.linear(1.3),
        );
        expect(
          scaled.length,
          lessThan(unscaled.length),
          reason:
              'at 1.3x scale, fewer characters should fit in the same '
              'maxWidth — using the same unscaled measurement regardless '
              'of scale would return a string that renders too wide once '
              'the real (scaled) Text widget paints it',
        );
      },
    );

    test(
      'fitLines wraps onto more lines at a larger scale for the same text',
      () {
        const text = 'A moderately long event title that wraps';
        const maxWidth = 80.0;
        const maxLines = 20;
        final unscaled = fitLines(
          text: text,
          style: _style,
          maxWidth: maxWidth,
          maxLines: maxLines,
        );
        final scaled = fitLines(
          text: text,
          style: _style,
          maxWidth: maxWidth,
          maxLines: maxLines,
          textScaler: const TextScaler.linear(1.3),
        );
        expect(
          scaled.length,
          greaterThan(unscaled.length),
          reason:
              'wider (scaled) characters need more lines to fit the same '
              'text in the same maxWidth',
        );
      },
    );
  });
}
