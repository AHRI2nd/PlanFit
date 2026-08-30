import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/features/schedule/domain/day_clock_geometry.dart';

void main() {
  final day = DateTime(2026, 3, 10);

  EventRow event({
    required String id,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    return EventRow(
      id: id,
      title: id,
      memo: null,
      location: null,
      startAt: startAt,
      endAt: endAt,
      isAllDay: false,
      colorTag: null,
      notify: true,
      reminderMinutesBefore: 0,
      additionalReminderMinutes: null,
      recurrenceRule: null,
      recurrenceGroupId: null,
      osCalendarId: null,
      osEventId: null,
      osLastKnownModified: null,
      syncStatus: SyncStatus.pendingPush,
      importSourceCalendarId: null,
      importSourceEventId: null,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
  }

  group('clampedMinutesOfDay', () {
    test('a plain in-day time returns its own minute offset', () {
      expect(clampedMinutesOfDay(day, DateTime(2026, 3, 10, 6, 30)), 390);
    });

    test('a time before this day clamps to 0', () {
      expect(clampedMinutesOfDay(day, DateTime(2026, 3, 9, 22)), 0);
    });

    test('a time at or past the next midnight clamps to 1440', () {
      expect(clampedMinutesOfDay(day, DateTime(2026, 3, 11, 3)), 1440);
      expect(clampedMinutesOfDay(day, DateTime(2026, 3, 11)), 1440);
    });
  });

  group('angleForMinutes', () {
    test('midnight points straight up (-π/2)', () {
      expect(angleForMinutes(0), closeTo(-math.pi / 2, 1e-9));
    });

    test('noon (halfway through the day) is a half turn from midnight', () {
      expect(angleForMinutes(720), closeTo(math.pi / 2, 1e-9));
    });

    test('6 hours in is a quarter turn clockwise from midnight', () {
      expect(angleForMinutes(360), closeTo(0, 1e-9));
    });
  });

  group('layoutClockArcs', () {
    test('a lone event spans exactly its own start/end angles', () {
      final e = event(
        id: 'a',
        startAt: DateTime(2026, 3, 10, 6),
        endAt: DateTime(2026, 3, 10, 9),
      );
      final arcs = layoutClockArcs(day, [e]);

      expect(arcs, hasLength(1));
      expect(arcs.single.startAngle, closeTo(angleForMinutes(360), 1e-9));
      // A 3-hour span (180 of 1440 minutes) is 1/8 of a full turn.
      expect(arcs.single.sweepAngle, closeTo(math.pi / 4, 1e-9));
      expect(arcs.single.ringStart, 0);
      expect(arcs.single.ringEnd, 1);
    });

    test(
      'two overlapping events split the ring band the same way cascadeEvents '
      'splits timeline columns',
      () {
        final a = event(
          id: 'a',
          startAt: DateTime(2026, 3, 10, 9),
          endAt: DateTime(2026, 3, 10, 11),
        );
        final b = event(
          id: 'b',
          startAt: DateTime(2026, 3, 10, 10),
          endAt: DateTime(2026, 3, 10, 12),
        );
        final arcs = layoutClockArcs(day, [a, b]);

        expect(arcs, hasLength(2));
        final bands = arcs.map((c) => (c.ringStart, c.ringEnd)).toSet();
        expect(bands, {(0.0, 0.5), (0.5, 1.0)});
      },
    );

    test('an event that starts the day before and ends the day after clamps to '
        'the full 24-hour sweep, not a negative/wrapped one', () {
      final e = event(
        id: 'a',
        startAt: DateTime(2026, 3, 9, 20),
        endAt: DateTime(2026, 3, 11, 4),
      );
      final arcs = layoutClockArcs(day, [e]);

      expect(arcs, hasLength(1));
      expect(arcs.single.startAngle, closeTo(angleForMinutes(0), 1e-9));
      expect(arcs.single.sweepAngle, closeTo(2 * math.pi, 1e-9));
    });

    test('an event entirely clamped away (e.g. ends exactly at this day\'s '
        'midnight) is dropped rather than producing a zero-width arc', () {
      final e = event(
        id: 'a',
        startAt: DateTime(2026, 3, 9, 22),
        endAt: DateTime(2026, 3, 10),
      );
      expect(layoutClockArcs(day, [e]), isEmpty);
    });
  });

  group('hitTestClockArcs', () {
    test('a point inside the arc\'s angle and ring band hits it', () {
      final e = event(
        id: 'a',
        startAt: DateTime(2026, 3, 10, 6),
        endAt: DateTime(2026, 3, 10, 9),
      );
      final arcs = layoutClockArcs(day, [e]);

      final hit = hitTestClockArcs(arcs, angleForMinutes(450), 0.5);
      expect(hit?.id, 'a');
    });

    test('a point outside the arc\'s angular span misses', () {
      final e = event(
        id: 'a',
        startAt: DateTime(2026, 3, 10, 6),
        endAt: DateTime(2026, 3, 10, 9),
      );
      final arcs = layoutClockArcs(day, [e]);

      expect(hitTestClockArcs(arcs, angleForMinutes(720), 0.5), isNull);
    });

    test('a point in the right angle but wrong ring band misses', () {
      final a = event(
        id: 'a',
        startAt: DateTime(2026, 3, 10, 9),
        endAt: DateTime(2026, 3, 10, 11),
      );
      final b = event(
        id: 'b',
        startAt: DateTime(2026, 3, 10, 10),
        endAt: DateTime(2026, 3, 10, 12),
      );
      final arcs = layoutClockArcs(day, [a, b]);
      final innerArc = arcs.firstWhere((c) => c.ringStart == 0);
      final outerArc = arcs.firstWhere((c) => c.ringStart == 0.5);

      // 10:30, inside both events' overlap window.
      final angle = angleForMinutes(630);
      expect(hitTestClockArcs(arcs, angle, 0.25)?.id, innerArc.event.id);
      expect(hitTestClockArcs(arcs, angle, 0.75)?.id, outerArc.event.id);
    });

    test('a query angle outside [0, 2π) (e.g. the raw angle for minute 1440, '
        'the same position on the dial as minute 0 but a different raw '
        'radian value) still matches, proving the angle gets normalized '
        'before comparing', () {
      final e = event(
        id: 'a',
        startAt: DateTime(2026, 3, 9, 23),
        endAt: DateTime(2026, 3, 10, 1),
      );
      final arcs = layoutClockArcs(day, [e]);

      expect(hitTestClockArcs(arcs, angleForMinutes(1440), 0.5)?.id, 'a');
    });
  });

  ClockArc arcWithSweep(double sweep) => ClockArc(
    event: event(
      id: 'a',
      startAt: day,
      endAt: day.add(const Duration(minutes: 30)),
    ),
    startAngle: 0,
    sweepAngle: sweep,
    ringStart: 0,
    ringEnd: 1,
  );

  group('arcLabelChordWidth', () {
    test('a half-circle sweep at a 100px radius has a 200px chord (its own '
        'diameter)', () {
      expect(
        arcLabelChordWidth(arcWithSweep(math.pi), 100),
        closeTo(200, 1e-9),
      );
    });

    test('a small sweep is well approximated by radius * sweepAngle '
        '(small-angle approximation)', () {
      expect(
        arcLabelChordWidth(arcWithSweep(0.1), 100),
        closeTo(100 * 0.1, 0.2),
      );
    });
  });

  group('arcFitsLabel', () {
    test('a ring band thinner than the minimum never fits a label, no matter '
        'how wide the arc itself is', () {
      final arc = arcWithSweep(math.pi); // a huge sweep — plenty of chord
      expect(
        arcFitsLabel(
          arc: arc,
          midRadius: 200,
          bandWidth: 5,
          minBandWidth: 10,
          minChordWidth: 32,
        ),
        isFalse,
      );
    });

    test(
      'a narrow (short-duration) arc does not fit even with a thick band',
      () {
        final arc = arcWithSweep(0.02); // a tiny sweep — barely any chord
        expect(
          arcFitsLabel(
            arc: arc,
            midRadius: 100,
            bandWidth: 40,
            minBandWidth: 10,
            minChordWidth: 32,
          ),
          isFalse,
        );
      },
    );

    test('a wide-enough arc with a thick-enough band fits', () {
      final arc = arcWithSweep(math.pi / 2);
      expect(
        arcFitsLabel(
          arc: arc,
          midRadius: 100,
          bandWidth: 40,
          minBandWidth: 10,
          minChordWidth: 32,
        ),
        isTrue,
      );
    });
  });
}
