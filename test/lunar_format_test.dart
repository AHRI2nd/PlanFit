import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/lunar/lunar_date.dart';
import 'package:planfit/core/lunar/lunar_format.dart';
import 'package:planfit/l10n/app_localizations.dart';

void main() {
  final ko = lookupAppL10n(const Locale('ko'));
  final en = lookupAppL10n(const Locale('en'));

  const regular = LunarDate(year: 2023, month: 7, day: 22, isLeapMonth: false);
  const leap = LunarDate(year: 2023, month: 7, day: 22, isLeapMonth: true);

  group('short', () {
    test('a regular month reads plainly, in each locale', () {
      expect(LunarFmt.short(ko, regular), '음력 7월 22일');
      expect(LunarFmt.short(en, regular), 'Lunar 7/22');
    });

    test('a leap month uses the leap-specific label, not just the same '
        'month/day with a marker appended', () {
      expect(LunarFmt.short(ko, leap), '음력 윤7월 22일');
      expect(LunarFmt.short(en, leap), 'Lunar 7/22 (leap)');
    });
  });

  group('compact', () {
    test('a regular month is just digits', () {
      expect(LunarFmt.compact(ko, regular), '7.22');
      expect(LunarFmt.compact(en, regular), '7/22');
    });

    test('a leap month prefixes the short leap marker ahead of the same '
        'digits', () {
      expect(LunarFmt.compact(ko, leap), '윤7.22');
      expect(LunarFmt.compact(en, leap), 'L7/22');
    });
  });

  group('cell', () {
    test('the 1st of the month shows the full compact month.day', () {
      const firstOfMonth = LunarDate(
        year: 2023,
        month: 7,
        day: 1,
        isLeapMonth: false,
      );
      expect(LunarFmt.cell(ko, firstOfMonth), '7.1');
    });

    test('any other day of a regular month shows only its own day number', () {
      expect(LunarFmt.cell(ko, regular), '22');
      expect(LunarFmt.cell(en, regular), '22');
    });

    test(
      'a non-1st day of a leap month still carries the leap marker alone — '
      'otherwise it would read identically to the same day number in the '
      'regular month of the same number that follows it',
      () {
        expect(LunarFmt.cell(ko, leap), '윤22');
        expect(LunarFmt.cell(en, leap), 'L22');
      },
    );

    test('the 1st of a leap month shows the leap-marked compact month.day, '
        'not the plain one', () {
      const firstOfLeapMonth = LunarDate(
        year: 2023,
        month: 7,
        day: 1,
        isLeapMonth: true,
      );
      expect(LunarFmt.cell(ko, firstOfLeapMonth), '윤7.1');
    });
  });
}
