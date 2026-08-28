import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/features/schedule/domain/event_overlap.dart';

void main() {
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

  group('cascadeEvents', () {
    test('a lone event gets siblingCount 1 and index 0', () {
      final result = cascadeEvents([
        event(
          id: 'a',
          startAt: DateTime(2026, 1, 1, 9),
          endAt: DateTime(2026, 1, 1, 10),
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.single.index, 0);
      expect(result.single.siblingCount, 1);
    });

    test('non-overlapping events each get their own cluster of one', () {
      final result = cascadeEvents([
        event(
          id: 'a',
          startAt: DateTime(2026, 1, 1, 9),
          endAt: DateTime(2026, 1, 1, 10),
        ),
        event(
          id: 'b',
          startAt: DateTime(2026, 1, 1, 10),
          endAt: DateTime(2026, 1, 1, 11),
        ),
      ]);

      // Half-open: b starts exactly when a ends, so they don't overlap.
      for (final c in result) {
        expect(c.siblingCount, 1);
        expect(c.index, 0);
      }
    });

    test(
      'two events at the exact same time cascade as a cluster of two, '
      'in start order',
      () {
        final result = cascadeEvents([
          event(
            id: 'b',
            startAt: DateTime(2026, 1, 1, 9),
            endAt: DateTime(2026, 1, 1, 10),
          ),
          event(
            id: 'a',
            startAt: DateTime(2026, 1, 1, 9),
            endAt: DateTime(2026, 1, 1, 10),
          ),
        ]);

        expect(result.map((c) => c.event.id), ['a', 'b']);
        expect(result.map((c) => c.index), [0, 1]);
        expect(result.every((c) => c.siblingCount == 2), isTrue);
      },
    );

    test(
      'a transitive chain (A overlaps B, B overlaps C, A does not overlap '
      'C) still cascades all three together',
      () {
        final a = event(
          id: 'a',
          startAt: DateTime(2026, 1, 1, 9),
          endAt: DateTime(2026, 1, 1, 10),
        );
        final b = event(
          id: 'b',
          startAt: DateTime(2026, 1, 1, 9, 30),
          endAt: DateTime(2026, 1, 1, 10, 30),
        );
        final c = event(
          id: 'c',
          startAt: DateTime(2026, 1, 1, 10),
          endAt: DateTime(2026, 1, 1, 11),
        );

        final result = cascadeEvents([c, a, b]);

        expect(result.map((r) => r.event.id), ['a', 'b', 'c']);
        expect(result.map((r) => r.siblingCount), [3, 3, 3]);
        expect(result.map((r) => r.index), [0, 1, 2]);
      },
    );

    test('is painted in ascending-start order across separate clusters', () {
      final result = cascadeEvents([
        event(
          id: 'late-cluster',
          startAt: DateTime(2026, 1, 1, 14),
          endAt: DateTime(2026, 1, 1, 15),
        ),
        event(
          id: 'early-a',
          startAt: DateTime(2026, 1, 1, 9),
          endAt: DateTime(2026, 1, 1, 10),
        ),
        event(
          id: 'early-b',
          startAt: DateTime(2026, 1, 1, 9),
          endAt: DateTime(2026, 1, 1, 10),
        ),
      ]);

      expect(result.map((r) => r.event.id), [
        'early-a',
        'early-b',
        'late-cluster',
      ]);
      expect(result.last.siblingCount, 1);
    });
  });
}
