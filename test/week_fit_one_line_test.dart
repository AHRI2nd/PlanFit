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
}
