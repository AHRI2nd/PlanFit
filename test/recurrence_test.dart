import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/lunar/lunar_date.dart';
import 'package:planfit/features/schedule/domain/recurrence.dart';

void main() {
  group('RecurrenceExpansion.occurrences', () {
    test('none returns exactly the original occurrence', () {
      final start = DateTime(2026, 7, 20, 9);
      final end = DateTime(2026, 7, 20, 10);
      final result = RecurrenceExpansion.occurrences(
        start: start,
        end: end,
        frequency: RecurrenceFrequency.none,
        until: start,
      );
      expect(result, [(start, end)]);
    });

    test('daily steps by one day and preserves duration', () {
      final start = DateTime(2026, 7, 20, 9);
      final end = DateTime(2026, 7, 20, 10, 30);
      final until = DateTime(2026, 7, 23);
      final result = RecurrenceExpansion.occurrences(
        start: start,
        end: end,
        frequency: RecurrenceFrequency.daily,
        until: until,
      );
      expect(result.length, 4); // 20, 21, 22, 23
      for (final (s, e) in result) {
        expect(e.difference(s), const Duration(hours: 1, minutes: 30));
      }
      expect(result.first.$1, start);
      expect(result.last.$1, DateTime(2026, 7, 23, 9));
    });

    test('weekly steps by seven days', () {
      final start = DateTime(2026, 7, 6, 15); // a Monday
      final end = start.add(const Duration(hours: 1));
      final until = DateTime(2026, 7, 27);
      final result = RecurrenceExpansion.occurrences(
        start: start,
        end: end,
        frequency: RecurrenceFrequency.weekly,
        until: until,
      );
      expect(result.map((o) => o.$1.day), [6, 13, 20, 27]);
    });

    test('monthly preserves day-of-month across a year boundary', () {
      final start = DateTime(2026, 11, 15, 9);
      final end = start.add(const Duration(hours: 1));
      final until = DateTime(2027, 2, 1);
      final result = RecurrenceExpansion.occurrences(
        start: start,
        end: end,
        frequency: RecurrenceFrequency.monthly,
        until: until,
      );
      expect(result.map((o) => (o.$1.year, o.$1.month, o.$1.day)), [
        (2026, 11, 15),
        (2026, 12, 15),
        (2027, 1, 15),
      ]);
    });

    test(
      'monthly clamps to the target month\'s last day instead of overflowing',
      () {
        // Jan 31 → Feb has no 31st. Plain DateTime(y, 2, 31) normalizes to
        // Mar 3 instead of clamping — this pins the fix for that.
        final start = DateTime(2026, 1, 31, 9);
        final end = start.add(const Duration(hours: 1));
        final until = DateTime(2026, 4, 30);
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.monthly,
          until: until,
        );
        expect(result.map((o) => (o.$1.month, o.$1.day)), [
          (1, 31),
          (2, 28), // 2026 is not a leap year
          (3, 31), // back to 31 once the month has one again
          (4, 30),
        ]);
      },
    );

    test('monthly preserves the time-of-day through the clamp', () {
      final start = DateTime(2026, 1, 31, 14, 45);
      final end = start.add(const Duration(hours: 1));
      final result = RecurrenceExpansion.occurrences(
        start: start,
        end: end,
        frequency: RecurrenceFrequency.monthly,
        until: DateTime(2026, 2, 28),
      );
      expect(result.last.$1, DateTime(2026, 2, 28, 14, 45));
    });

    test('yearly clamps Feb 29 to Feb 28 in a non-leap target year', () {
      final start = DateTime(2024, 2, 29, 9); // 2024 is a leap year
      final end = start.add(const Duration(hours: 1));
      final until = DateTime(2027, 3, 1);
      final result = RecurrenceExpansion.occurrences(
        start: start,
        end: end,
        frequency: RecurrenceFrequency.yearly,
        until: until,
      );
      expect(result.map((o) => (o.$1.year, o.$1.month, o.$1.day)), [
        (2024, 2, 29),
        (2025, 2, 28),
        (2026, 2, 28),
        (2027, 2, 28),
      ]);
    });

    test('yearly steps by one year', () {
      final start = DateTime(2026, 3, 5, 9);
      final end = start.add(const Duration(hours: 1));
      final until = DateTime(2029, 3, 5);
      final result = RecurrenceExpansion.occurrences(
        start: start,
        end: end,
        frequency: RecurrenceFrequency.yearly,
        until: until,
      );
      expect(result.map((o) => o.$1.year), [2026, 2027, 2028, 2029]);
    });

    test('caps at maxOccurrences even with a far-future until', () {
      final start = DateTime(2026, 1, 1);
      final end = start.add(const Duration(hours: 1));
      final until = DateTime(2100, 1, 1);
      final result = RecurrenceExpansion.occurrences(
        start: start,
        end: end,
        frequency: RecurrenceFrequency.daily,
        until: until,
      );
      expect(result.length, RecurrenceExpansion.maxOccurrences);
    });

    test('until before start yields a single occurrence', () {
      final start = DateTime(2026, 7, 20);
      final end = start.add(const Duration(hours: 1));
      final result = RecurrenceExpansion.occurrences(
        start: start,
        end: end,
        frequency: RecurrenceFrequency.weekly,
        until: DateTime(2026, 7, 1),
      );
      expect(result, [(start, end)]);
    });

    group('yearlyLunar', () {
      test(
        'a lunar birthday lands on a genuinely different solar date each '
        'year, unlike plain yearly — verified against LunarDate directly, '
        'not a memorized table',
        () {
          // 음력 2024-3-15 — verified via LunarDate(...).toSolar() directly.
          final start = DateTime(2024, 4, 23, 9);
          final end = start.add(const Duration(hours: 1));
          final result = RecurrenceExpansion.occurrences(
            start: start,
            end: end,
            frequency: RecurrenceFrequency.yearlyLunar,
            count: 6,
          );
          expect(result.map((o) => (o.$1.year, o.$1.month, o.$1.day)), [
            (2024, 4, 23),
            (2025, 4, 12),
            (2026, 5, 1),
            (2027, 4, 21),
            (2028, 4, 9),
            (2029, 4, 28),
          ]);
          // Every occurrence still resolves to lunar month 3, day 15 — the
          // whole point of anchoring on the lunar date instead of the solar
          // one.
          for (final o in result) {
            final lunar = LunarDate.fromSolar(o.$1)!;
            expect((lunar.month, lunar.day), (3, 15));
          }
          // The time-of-day carries across every occurrence, same as every
          // other frequency.
          expect(result.every((o) => o.$1.hour == 9), isTrue);
        },
      );

      test(
        'an anchor on a leap month falls back to that month\'s plain '
        '(non-leap) occurrence starting the very next year — a leap month '
        "doesn't recur yearly, so there's nothing else \"매년\" on one "
        'could mean most years',
        () {
          // 2023's real leap month is 2 (윤2월), day 1 = solar 2023-03-22 —
          // verified directly against klc earlier in this session.
          final start = DateTime(2023, 3, 22, 8);
          final end = start.add(const Duration(hours: 1));
          final result = RecurrenceExpansion.occurrences(
            start: start,
            end: end,
            frequency: RecurrenceFrequency.yearlyLunar,
            count: 4,
          );
          expect(result.map((o) => (o.$1.year, o.$1.month, o.$1.day)), [
            (2023, 3, 22),
            (2024, 3, 10),
            (2025, 2, 28),
            (2026, 3, 19),
          ]);
          final firstLunar = LunarDate.fromSolar(result[0].$1)!;
          expect(firstLunar.isLeapMonth, isTrue);
          for (final o in result.skip(1)) {
            final lunar = LunarDate.fromSolar(o.$1)!;
            expect(lunar.month, 2);
            expect(lunar.day, 1);
            expect(lunar.isLeapMonth, isFalse);
          }
        },
      );

      test(
        'a day-30 anchor clamps to 29 in a year whose target month is only '
        '29 days, instead of terminating the whole series there — '
        'regression test: this used to be indistinguishable from running '
        "out of klc's range entirely, ending the series decades early the "
        'first time a 30-day anchor hit an ordinary 29-day year (which '
        'happens to roughly half of all lunar months, routinely)',
        () {
          final start = DateTime(2025, 12, 19, 8); // lunar 2025-10-30
          final end = start.add(const Duration(hours: 1));
          final result = RecurrenceExpansion.occurrences(
            start: start,
            end: end,
            frequency: RecurrenceFrequency.yearlyLunar,
            count: 8,
          );
          // All 8 requested occurrences exist — the old bug stopped after
          // just 4 (years 2025-2028), the last one before the first 29-day
          // year.
          expect(result.length, 8);
          expect(result.map((o) => (o.$1.year, o.$1.month, o.$1.day)), [
            (2025, 12, 19),
            (2026, 12, 8),
            (2027, 11, 27),
            (2028, 12, 15),
            (2029, 12, 4),
            (2030, 11, 24),
            (2031, 12, 13),
            (2032, 12, 2),
          ]);
          // The lunar month stays 10 throughout; the day clamps to 29 for
          // the three years (2029-2031) whose month 10 is only 29 days,
          // and returns to the anchor's own 30 the moment a 30-day year
          // comes back around — never drifting to a different month.
          final lunarDays = [
            for (final o in result) LunarDate.fromSolar(o.$1)!,
          ];
          expect(lunarDays.every((l) => l.month == 10), isTrue);
          expect(
            lunarDays.map((l) => l.day),
            [30, 30, 30, 30, 29, 29, 29, 30],
          );
        },
      );

      test(
        'stops (rather than crashing or looping) once stepping past the '
        "solar year 2050 — klc's own supported range runs out there",
        () {
          final start = DateTime(2049, 6, 1, 9);
          final end = start.add(const Duration(hours: 1));
          final result = RecurrenceExpansion.occurrences(
            start: start,
            end: end,
            frequency: RecurrenceFrequency.yearlyLunar,
            count: 10,
          );
          expect(result.length, lessThan(10));
          expect(result.every((o) => o.$1.year <= 2050), isTrue);
        },
      );
    });

    group('byWeekdays', () {
      test('repeats on every selected weekday, not just the start day', () {
        final start = DateTime(2026, 7, 6, 15); // a Monday
        final end = start.add(const Duration(hours: 1));
        final until = DateTime(2026, 7, 19); // two full weeks
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.weekly,
          until: until,
          // Monday + Wednesday + Friday.
          byWeekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
        );
        expect(result.map((o) => o.$1.day), [6, 8, 10, 13, 15, 17]);
      });

      test('always includes the start day even if not in byWeekdays', () {
        final start = DateTime(2026, 7, 6, 15); // a Monday
        final end = start.add(const Duration(hours: 1));
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.weekly,
          until: DateTime(2026, 7, 6),
          byWeekdays: {DateTime.friday},
        );
        expect(result, [(start, end)]);
      });

      test('preserves the time-of-day and duration on every occurrence', () {
        final start = DateTime(2026, 7, 6, 9, 30);
        final end = start.add(const Duration(minutes: 45));
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.weekly,
          until: DateTime(2026, 7, 10),
          byWeekdays: {DateTime.monday, DateTime.friday},
        );
        for (final (s, e) in result) {
          expect((s.hour, s.minute), (9, 30));
          expect(e.difference(s), const Duration(minutes: 45));
        }
      });

      test('caps at maxOccurrences with a far-future until', () {
        final start = DateTime(2026, 1, 5, 9); // a Monday
        final end = start.add(const Duration(hours: 1));
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.weekly,
          until: DateTime(2100, 1, 1),
          byWeekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
        );
        expect(result.length, RecurrenceExpansion.maxOccurrences);
      });

      test('an empty set falls back to the original same-weekday behavior', () {
        final start = DateTime(2026, 7, 6, 15); // a Monday
        final end = start.add(const Duration(hours: 1));
        final until = DateTime(2026, 7, 27);
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.weekly,
          until: until,
          byWeekdays: {},
        );
        expect(result.map((o) => o.$1.day), [6, 13, 20, 27]);
      });

      test('is ignored for a non-weekly frequency', () {
        final start = DateTime(2026, 7, 6, 9);
        final end = start.add(const Duration(hours: 1));
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.daily,
          until: DateTime(2026, 7, 8),
          byWeekdays: {DateTime.friday},
        );
        expect(result.map((o) => o.$1.day), [6, 7, 8]);
      });
    });

    group('count', () {
      test('generates exactly count occurrences, ignoring any date bound', () {
        final start = DateTime(2026, 7, 20, 9);
        final end = start.add(const Duration(hours: 1));
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.daily,
          count: 5,
        );
        expect(result.length, 5);
        expect(result.map((o) => o.$1.day), [20, 21, 22, 23, 24]);
      });

      test('clamps a count above maxOccurrences down to the cap', () {
        final start = DateTime(2026, 1, 1);
        final end = start.add(const Duration(hours: 1));
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.daily,
          count: 500,
        );
        expect(result.length, RecurrenceExpansion.maxOccurrences);
      });

      test('a count of 1 returns just the original occurrence', () {
        final start = DateTime(2026, 7, 20, 9);
        final end = start.add(const Duration(hours: 1));
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.weekly,
          count: 1,
        );
        expect(result, [(start, end)]);
      });

      test('combines with byWeekdays to count matching weekdays, not days', () {
        final start = DateTime(2026, 7, 6, 9); // a Monday
        final end = start.add(const Duration(hours: 1));
        final result = RecurrenceExpansion.occurrences(
          start: start,
          end: end,
          frequency: RecurrenceFrequency.weekly,
          count: 4,
          byWeekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
        );
        expect(result.length, 4);
        expect(result.map((o) => o.$1.day), [6, 8, 10, 13]);
      });
    });
  });

  group('RecurrenceExpansion.isTruncated', () {
    test('false for a non-recurring event', () {
      final start = DateTime(2026, 1, 1);
      expect(
        RecurrenceExpansion.isTruncated(
          start: start,
          frequency: RecurrenceFrequency.none,
          until: DateTime(2030),
        ),
        isFalse,
      );
    });

    test('false when the series ends well within the 200-occurrence cap', () {
      final start = DateTime(2026, 1, 1);
      expect(
        RecurrenceExpansion.isTruncated(
          start: start,
          frequency: RecurrenceFrequency.weekly,
          until: start.add(const Duration(days: 30)),
        ),
        isFalse,
      );
    });

    test('true when a daily series over a year outruns the 200-day cap', () {
      final start = DateTime(2026, 1, 1);
      expect(
        RecurrenceExpansion.isTruncated(
          start: start,
          frequency: RecurrenceFrequency.daily,
          until: start.add(const Duration(days: 365)),
        ),
        isTrue,
      );
    });

    test('matches occurrences() actually stopping short of until', () {
      final start = DateTime(2026, 1, 1);
      final until = start.add(const Duration(days: 365));
      final result = RecurrenceExpansion.occurrences(
        start: start,
        end: start,
        frequency: RecurrenceFrequency.daily,
        until: until,
      );
      final lastGenerated = result.last.$1;
      final stoppedShort = DateTime(
        lastGenerated.year,
        lastGenerated.month,
        lastGenerated.day,
      ).isBefore(DateTime(until.year, until.month, until.day));
      expect(
        RecurrenceExpansion.isTruncated(
          start: start,
          frequency: RecurrenceFrequency.daily,
          until: until,
        ),
        stoppedShort,
      );
    });

    group('byWeekdays', () {
      test('false when the series ends well within the cap', () {
        final start = DateTime(2026, 7, 6); // a Monday
        expect(
          RecurrenceExpansion.isTruncated(
            start: start,
            frequency: RecurrenceFrequency.weekly,
            until: start.add(const Duration(days: 30)),
            byWeekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
          ),
          isFalse,
        );
      });

      test('true when three-times-a-week over two years outruns the cap', () {
        final start = DateTime(2026, 1, 5); // a Monday
        expect(
          RecurrenceExpansion.isTruncated(
            start: start,
            frequency: RecurrenceFrequency.weekly,
            until: start.add(const Duration(days: 730)),
            byWeekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
          ),
          isTrue,
        );
      });
    });

    group('count', () {
      test('false when the requested count is within the cap', () {
        expect(
          RecurrenceExpansion.isTruncated(
            start: DateTime(2026, 1, 1),
            frequency: RecurrenceFrequency.daily,
            count: 50,
          ),
          isFalse,
        );
      });

      test('true when the requested count exceeds the cap', () {
        expect(
          RecurrenceExpansion.isTruncated(
            start: DateTime(2026, 1, 1),
            frequency: RecurrenceFrequency.daily,
            count: 500,
          ),
          isTrue,
        );
      });

      test('false when the requested count exactly equals the cap', () {
        expect(
          RecurrenceExpansion.isTruncated(
            start: DateTime(2026, 1, 1),
            frequency: RecurrenceFrequency.daily,
            count: RecurrenceExpansion.maxOccurrences,
          ),
          isFalse,
        );
      });
    });
  });

  group('RecurrenceExpansion.toRruleString', () {
    test('renders FREQ and a UTC UNTIL stamp', () {
      final rrule = RecurrenceExpansion.toRruleString(
        RecurrenceFrequency.weekly,
        until: DateTime.utc(2026, 12, 31, 23, 59, 59),
      );
      expect(rrule, 'FREQ=WEEKLY;UNTIL=20261231T235959Z');
    });

    test('adds a sorted BYDAY part for a weekly byWeekdays selection', () {
      final rrule = RecurrenceExpansion.toRruleString(
        RecurrenceFrequency.weekly,
        until: DateTime.utc(2026, 12, 31, 23, 59, 59),
        byWeekdays: {DateTime.friday, DateTime.monday, DateTime.wednesday},
      );
      expect(rrule, 'FREQ=WEEKLY;UNTIL=20261231T235959Z;BYDAY=MO,WE,FR');
    });

    test('ignores byWeekdays for a non-weekly frequency', () {
      final rrule = RecurrenceExpansion.toRruleString(
        RecurrenceFrequency.daily,
        until: DateTime.utc(2026, 12, 31, 23, 59, 59),
        byWeekdays: {DateTime.friday},
      );
      expect(rrule, 'FREQ=DAILY;UNTIL=20261231T235959Z');
    });

    test('an empty byWeekdays set omits BYDAY', () {
      final rrule = RecurrenceExpansion.toRruleString(
        RecurrenceFrequency.weekly,
        until: DateTime.utc(2026, 12, 31, 23, 59, 59),
        byWeekdays: {},
      );
      expect(rrule, 'FREQ=WEEKLY;UNTIL=20261231T235959Z');
    });

    test('renders COUNT instead of UNTIL when count is given', () {
      final rrule = RecurrenceExpansion.toRruleString(
        RecurrenceFrequency.daily,
        count: 10,
      );
      expect(rrule, 'FREQ=DAILY;COUNT=10');
    });

    test('combines COUNT with BYDAY for a weekly byWeekdays selection', () {
      final rrule = RecurrenceExpansion.toRruleString(
        RecurrenceFrequency.weekly,
        count: 12,
        byWeekdays: {DateTime.tuesday, DateTime.thursday},
      );
      expect(rrule, 'FREQ=WEEKLY;COUNT=12;BYDAY=TU,TH');
    });
  });
}
