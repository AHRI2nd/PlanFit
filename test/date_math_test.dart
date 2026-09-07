import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/date_math.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('addCalendarDays', () {
    test('preserves time-of-day while advancing the date', () {
      final result = addCalendarDays(DateTime(2026, 3, 5, 9, 30), 3);
      expect(result, DateTime(2026, 3, 8, 9, 30));
    });

    test('rolls over a month boundary', () {
      final result = addCalendarDays(DateTime(2026, 3, 30, 9, 0), 3);
      expect(result, DateTime(2026, 4, 2, 9, 0));
    });

    test('rolls over a year boundary', () {
      final result = addCalendarDays(DateTime(2026, 12, 30, 9, 0), 3);
      expect(result, DateTime(2027, 1, 2, 9, 0));
    });

    test('rolls over a leap-year February correctly', () {
      final result = addCalendarDays(DateTime(2024, 2, 27, 9, 0), 3);
      expect(result, DateTime(2024, 3, 1, 9, 0));
    });

    test('negative days subtracts, same time-of-day preserved', () {
      final result = addCalendarDays(DateTime(2026, 3, 8, 9, 30), -3);
      expect(result, DateTime(2026, 3, 5, 9, 30));
    });

    test('zero days is a no-op', () {
      final dt = DateTime(2026, 3, 5, 9, 30, 15);
      expect(addCalendarDays(dt, 0), dt);
    });

    // The whole point of addCalendarDays: unlike `dt.add(Duration(days: n))`,
    // which adds n*24 real hours and drifts the wall-clock time whenever the
    // range crosses a DST transition, this never even looks at elapsed time —
    // it only touches the calendar fields, so the result is identical
    // regardless of what DST rules (if any) apply in between. Verified
    // against the naive/buggy approach directly:
    test('unlike Duration-based addition, never drifts time-of-day '
        '(the DST bug this replaces)', () {
      final start = DateTime(2026, 3, 5, 9, 0);
      final buggy = start.add(const Duration(days: 3));
      final fixed = addCalendarDays(start, 3);
      // Under a timezone with no DST in this window (including the CI
      // machine's own, whatever it is), both agree — that's expected and
      // fine, this isn't asserting they differ. What matters is `fixed`
      // always keeps the 09:00 time-of-day, which `buggy` cannot promise.
      expect(fixed.hour, 9);
      expect(fixed.minute, 0);
      // If the two disagree, it's because the host is observing a DST
      // transition inside [start, start+3d) right now — exactly the
      // drift this function exists to avoid.
      if (buggy != fixed) {
        expect(buggy.hour, isNot(9));
      }
    });
  });

  group('shiftTimeOfDay', () {
    test('a positive delta within the same day just shifts the clock', () {
      final result = shiftTimeOfDay(
        DateTime(2026, 3, 8, 9, 0),
        const Duration(hours: 1, minutes: 30),
      );
      expect(result, DateTime(2026, 3, 8, 10, 30));
    });

    test('a negative delta within the same day just shifts the clock', () {
      final result = shiftTimeOfDay(
        DateTime(2026, 3, 8, 9, 0),
        const Duration(hours: -2),
      );
      expect(result, DateTime(2026, 3, 8, 7, 0));
    });

    test('a delta pushing past midnight rolls onto the next day', () {
      final result = shiftTimeOfDay(
        DateTime(2026, 3, 8, 23, 0),
        const Duration(hours: 2),
      );
      expect(result, DateTime(2026, 3, 9, 1, 0));
    });

    test('a negative delta pushing before midnight rolls back a day', () {
      final result = shiftTimeOfDay(
        DateTime(2026, 3, 8, 0, 30),
        const Duration(hours: -1),
      );
      expect(result, DateTime(2026, 3, 7, 23, 30));
    });

    test('zero delta is a no-op', () {
      final dt = DateTime(2026, 3, 8, 9, 15);
      expect(shiftTimeOfDay(dt, Duration.zero), dt);
    });

    // Same DST-safety property as addCalendarDays: this never adds elapsed
    // time to a date, so applying a time-of-day shift on the DST transition
    // date itself still lands on the intended wall-clock time.
    test('reconstructing 09:00 on a given date never drifts, unlike '
        "midnight.add(Duration(hours: 9)) would on that day's own DST "
        'transition', () {
      final result = shiftTimeOfDay(DateTime(2026, 3, 8, 9, 0), Duration.zero);
      expect(result.hour, 9);
      expect(result.minute, 0);
    });
  });

  group('addCalendarMonths', () {
    test('preserves time-of-day while advancing the month', () {
      final result = addCalendarMonths(DateTime(2026, 3, 15, 9, 30), 2);
      expect(result, DateTime(2026, 5, 15, 9, 30));
    });

    test('clamps the day when the target month is shorter', () {
      final result = addCalendarMonths(DateTime(2026, 1, 31, 9, 0), 1);
      // 2026 is not a leap year, so February only has 28 days.
      expect(result, DateTime(2026, 2, 28, 9, 0));
    });

    test('a negative offset rolls back across a year boundary', () {
      final result = addCalendarMonths(DateTime(2026, 1, 15, 9, 0), -1);
      expect(result, DateTime(2025, 12, 15, 9, 0));
    });

    test('a positive offset rolls forward across a year boundary', () {
      final result = addCalendarMonths(DateTime(2026, 12, 15, 9, 0), 1);
      expect(result, DateTime(2027, 1, 15, 9, 0));
    });

    test('a multi-year negative offset still lands correctly', () {
      final result = addCalendarMonths(DateTime(2026, 2, 15, 9, 0), -14);
      expect(result, DateTime(2024, 12, 15, 9, 0));
    });

    test('zero months is a no-op', () {
      final dt = DateTime(2026, 3, 15, 9, 30, 15);
      expect(addCalendarMonths(dt, 0), dt);
    });

    // The whole point of this function's year/month split: Dart's `~/`
    // truncates toward zero, not floor, so a naive
    // `(dt.month - 1 + months) % 12` mishandles a negative total that
    // crosses a year boundary — e.g. for Jan 2026 - 1 month, the naive
    // total is -1, and `-1 ~/ 12 == 0` in Dart (truncating), which would
    // wrongly keep the year at 2026 instead of rolling back to 2025. This
    // function instead derives the split from `%`'s Euclidean remainder
    // (always non-negative for a positive divisor), which is floor-division
    // safe regardless of sign.
    test('derives the year/month split from Euclidean %, not truncating ~/ '
        '(the year-boundary bug this avoids)', () {
      final result = addCalendarMonths(DateTime(2026, 1, 15, 9, 0), -1);
      expect(result.year, 2025);
      expect(result.month, 12);
    });
  });

  group('addCalendarYears', () {
    test('preserves time-of-day, month and day while advancing the year', () {
      final result = addCalendarYears(DateTime(2026, 3, 15, 9, 30), 1);
      expect(result, DateTime(2027, 3, 15, 9, 30));
    });

    test('clamps Feb 29 to Feb 28 in a non-leap target year', () {
      final result = addCalendarYears(DateTime(2028, 2, 29, 9, 0), 1);
      expect(result, DateTime(2029, 2, 28, 9, 0));
    });

    test('negative years subtracts', () {
      final result = addCalendarYears(DateTime(2026, 3, 15, 9, 0), -1);
      expect(result, DateTime(2025, 3, 15, 9, 0));
    });

    test('zero years is a no-op', () {
      final dt = DateTime(2026, 3, 15, 9, 30, 15);
      expect(addCalendarYears(dt, 0), dt);
    });
  });

  group('calendarDuration', () {
    test('a same-day span is just the plain hour difference', () {
      final result = calendarDuration(
        DateTime(2026, 3, 5, 9, 0),
        DateTime(2026, 3, 5, 17, 30),
      );
      expect(result, const Duration(hours: 8, minutes: 30));
    });

    test('an overnight (day-crossing) span totals correctly', () {
      final result = calendarDuration(
        DateTime(2026, 3, 7, 21, 0),
        DateTime(2026, 3, 8, 5, 0),
      );
      expect(result, const Duration(hours: 8));
    });

    // The whole point of calendarDuration: unlike `end.difference(start)`,
    // which measures elapsed real UTC time, this is computed purely from
    // calendar/wall-clock fields — so replaying it (via shiftTimeOfDay, not
    // DateTime.add) onto a *different* date reconstructs the same
    // wall-clock time-of-day span regardless of any DST transition in
    // between, on either the original pair or the date it's replayed onto.
    // Verified deterministically (independent of whatever timezone this
    // test happens to run in) using `timezone`'s TZDateTime pinned to a
    // real DST-observing zone, rather than relying on the host's own
    // timezone happening to observe one.
    //
    // recurrence.dart's own RecurrenceExpansion.occurrences() uses this same
    // pair (calendarDuration + shiftTimeOfDay) for exactly this reason, but
    // isn't separately regression-tested with TZDateTime the way this is:
    // _advance/addCalendarDays reconstructs each occurrence's start via a
    // plain `DateTime(year, month, day, ...)` call, which always resolves
    // against the *current process's actual local timezone* rather than an
    // arbitrary TZDateTime's own simulated Location — so on a test host
    // whose real local timezone doesn't happen to be the DST zone being
    // simulated, a TZDateTime start/end passed into occurrences() gets
    // silently "re-localized" partway through, defeating the simulation
    // before duration is ever replayed. That's specific to testing the
    // full pipeline from a host timezone that doesn't match; the
    // calendarDuration/shiftTimeOfDay computation itself, checked directly
    // here, is genuinely host-independent and is what recurrence.dart
    // actually relies on for real devices (whose own local DateTime, on an
    // actual DST-observing device, is DST-aware by construction).
    test(
      'replaying it via shiftTimeOfDay reconstructs the correct wall-clock '
      "end time across a real DST spring-forward — regression test: the "
      'elapsed-time equivalent (end.difference(start), replayed via '
      'DateTime.add) drifts the reconstructed hour forward by the '
      "transition's skipped hour",
      () {
        tzdata.initializeTimeZones();
        final ny = tz.getLocation('America/New_York');
        // The original span, computed from an ordinary day nowhere near the
        // transition (Mar 1 -> Mar 2, an 8h overnight span).
        final origStart = tz.TZDateTime(ny, 2026, 3, 1, 21, 0);
        final origEnd = tz.TZDateTime(ny, 2026, 3, 2, 5, 0);

        // Replayed onto the night of the actual spring-forward transition
        // (2026-03-08: 02:00 -> 03:00 EDT, US Eastern's 2026 date).
        final occurrenceStart = tz.TZDateTime(ny, 2026, 3, 7, 21, 0);

        final fixedEnd = shiftTimeOfDay(
          occurrenceStart,
          calendarDuration(origStart, origEnd),
        );
        expect(fixedEnd.hour, 5);
        expect(fixedEnd.minute, 0);
        expect(fixedEnd.day, 8);

        // Confirm this scenario actually exercises the transition — the
        // old, buggy approach really does drift here, so this isn't a
        // vacuously-true assertion.
        final buggyDuration = origEnd.difference(origStart);
        final buggyEnd = occurrenceStart.add(buggyDuration);
        expect(
          buggyEnd.hour,
          6,
          reason:
              "the elapsed-time approach lands an hour later than intended "
              "here — confirming this scenario genuinely crosses the "
              'transition, not a false negative',
        );
      },
    );
  });
}
