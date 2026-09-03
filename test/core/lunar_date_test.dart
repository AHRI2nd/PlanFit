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

  group('LunarDate.leapMonthOf', () {
    test('returns the correct leap month for a year known to have one', () {
      // Verified against klc directly earlier — 2023's leap month is 2.
      expect(LunarDate.leapMonthOf(2023), 2);
    });

    test('returns null for a year with no leap month', () {
      expect(LunarDate.leapMonthOf(2026), isNull);
    });

    test('returns null outside klc\'s supported range', () {
      expect(LunarDate.leapMonthOf(1000), isNull);
      expect(LunarDate.leapMonthOf(2100), isNull);
    });
  });

  group('LunarDate.monthsInYear', () {
    test('returns 12 for an ordinary year', () {
      expect(LunarDate.monthsInYear(2026), 12);
    });

    test(
      "stops short of 12 for 2050, klc's own upper boundary — regression "
      "test: lunar_date_picker.dart's month wheel used to always offer all "
      "12 months regardless of year, so picking 2050 + month 12 (both "
      "individually reachable) landed on a month with no valid day 1 at "
      "all, silently falling back to a fake 29-day range and leaving "
      '"Done" a no-op once pressed',
      () {
        final count = LunarDate.monthsInYear(2050);
        expect(count, lessThan(12));
        // The returned month is genuinely usable...
        expect(LunarDate.daysInMonth(2050, count, false), isNotNull);
        // ...and one past it genuinely is not, confirming this is the real
        // boundary and not just an arbitrary smaller number.
        expect(LunarDate.daysInMonth(2050, count + 1, false), isNull);
      },
    );

    test('falls back to 12 outside klc\'s supported range', () {
      expect(LunarDate.monthsInYear(1000), 12);
      expect(LunarDate.monthsInYear(2100), 12);
    });
  });

  group('LunarDate.daysInMonth', () {
    test('returns 29 or 30 for an ordinary month', () {
      final days = LunarDate.daysInMonth(2026, 7, false);
      expect(days, anyOf(29, 30));
    });

    test('returns the real leap month\'s day count', () {
      final days = LunarDate.daysInMonth(2023, 2, true);
      expect(days, anyOf(29, 30));
    });

    test('returns null when asked for a leap month that year never had', () {
      expect(LunarDate.daysInMonth(2023, 5, true), isNull);
    });

    test('returns null for an out-of-range year or month', () {
      expect(LunarDate.daysInMonth(1000, 1, false), isNull);
      expect(LunarDate.daysInMonth(2026, 13, false), isNull);
    });

    test(
      'every day it returns for a month actually round-trips through '
      'toSolar — regression test for klc\'s raw day-count table overshooting '
      "what's really convertible right at the edge of its own supported "
      'range (year 2050, where klc\'s table trails off mid-month rather '
      'than on a clean month boundary): the old implementation trusted that '
      'raw count directly, so it could claim e.g. 30 days for a month where '
      'only the first 18 actually convert, silently breaking any UI that '
      "trusted this to know which days are safe to offer",
      () {
        for (final (year, month, isLeap) in [
          (2026, 7, false),
          (2023, 2, true),
          (2050, 11, false),
          (2050, 12, false),
        ]) {
          final days = LunarDate.daysInMonth(year, month, isLeap);
          if (days == null) continue;
          for (var d = 1; d <= days; d++) {
            final solar = LunarDate(
              year: year,
              month: month,
              day: d,
              isLeapMonth: isLeap,
            ).toSolar();
            expect(
              solar,
              isNotNull,
              reason: 'day $d of $year-$month(leap=$isLeap) should convert',
            );
          }
        }
      },
    );
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
