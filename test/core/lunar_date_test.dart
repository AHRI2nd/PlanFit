import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/lunar/lunar_date.dart';

void main() {
  group('LunarDate.fromSolar', () {
    test('a known Lunar New Year converts to lunar 1/1', () {
      // 2024-02-10 was Korea's 설날 (Lunar New Year) — lunar New Year is,
      // by definition, always lunar month 1, day 1, so this holds
      // regardless of any specific conversion-table detail.
      final lunar = LunarDate.fromSolar(DateTime(2024, 2, 10));
      expect(lunar, isNotNull);
      expect(lunar!.year, 2024);
      expect(lunar.month, 1);
      expect(lunar.day, 1);
      expect(lunar.isLeapMonth, isFalse);
    });

    test('an ordinary date is never marked as a leap month', () {
      final lunar = LunarDate.fromSolar(DateTime(2026, 9, 3));
      expect(lunar, isNotNull);
      expect(lunar!.isLeapMonth, isFalse);
    });

    test('the first day of 2023\'s real leap month is detected correctly',
        () {
      // 2023 had a leap 2nd month (윤2월) starting 2023-03-22 — this is a
      // regression test for klc 0.1.0's own bug where its top-level
      // `isIntercalation` variable is never actually written by the
      // solar->lunar direction (see LunarDate's own doc comment on
      // _isLeapMonth) — a naive read of that global would report `false`
      // here instead of `true`.
      final lunar = LunarDate.fromSolar(DateTime(2023, 3, 22));
      expect(lunar, isNotNull);
      expect(lunar!.year, 2023);
      expect(lunar.month, 2);
      expect(lunar.day, 1);
      expect(lunar.isLeapMonth, isTrue);
    });

    test(
      'the day right before that leap month is the last day of the regular '
      'month it follows, not the leap month itself',
      () {
        final lunar = LunarDate.fromSolar(DateTime(2023, 3, 21));
        expect(lunar, isNotNull);
        expect(lunar!.month, 2);
        expect(lunar.isLeapMonth, isFalse);
      },
    );

    test('a date before klc\'s supported range returns null', () {
      expect(LunarDate.fromSolar(DateTime(1000, 1, 1)), isNull);
    });

    test('a date after klc\'s supported range returns null', () {
      expect(LunarDate.fromSolar(DateTime(2051, 1, 1)), isNull);
    });

    test('the very last supported date converts successfully', () {
      expect(LunarDate.fromSolar(DateTime(2050, 12, 31)), isNotNull);
    });
  });

  group('LunarDate.toSolar', () {
    test('round-trips an ordinary date exactly', () {
      final solar = DateTime(2026, 9, 3);
      final lunar = LunarDate.fromSolar(solar)!;
      expect(lunar.toSolar(), solar);
    });

    test('round-trips a real leap-month date exactly', () {
      final solar = DateTime(2023, 3, 22);
      final lunar = LunarDate.fromSolar(solar)!;
      expect(lunar.isLeapMonth, isTrue);
      expect(lunar.toSolar(), solar);
    });

    test('a day that doesn\'t exist in that lunar month returns null', () {
      // Lunar month 2024-1 only has 29 days (verified against klc itself).
      const invalid = LunarDate(
        year: 2024,
        month: 1,
        day: 30,
        isLeapMonth: false,
      );
      expect(invalid.toSolar(), isNull);
    });

    test(
      'a leap-month flag on a month that was never actually a leap month '
      'is silently normalized to the plain month, not rejected',
      () {
        // Month 5 was not 2023's leap month (2 was) — klc's own
        // setLunarDate silently treats this the same as isLeapMonth:false
        // rather than failing, which this documents as intentional (see
        // LunarDate.toSolar's own doc comment) rather than a bug to guard
        // against.
        const claimedLeap = LunarDate(
          year: 2023,
          month: 5,
          day: 1,
          isLeapMonth: true,
        );
        const plain = LunarDate(
          year: 2023,
          month: 5,
          day: 1,
          isLeapMonth: false,
        );
        expect(claimedLeap.toSolar(), plain.toSolar());
      },
    );

    test('an out-of-range lunar date returns null', () {
      const invalid = LunarDate(
        year: 1000,
        month: 1,
        day: 1,
        isLeapMonth: false,
      );
      expect(invalid.toSolar(), isNull);
    });
  });

  group('equality', () {
    test('two LunarDates with the same fields are equal', () {
      const a = LunarDate(year: 2026, month: 7, day: 22, isLeapMonth: false);
      const b = LunarDate(year: 2026, month: 7, day: 22, isLeapMonth: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a differing isLeapMonth makes two LunarDates unequal', () {
      const a = LunarDate(year: 2023, month: 2, day: 1, isLeapMonth: false);
      const b = LunarDate(year: 2023, month: 2, day: 1, isLeapMonth: true);
      expect(a, isNot(b));
    });
  });
}
