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

  /// Looks up one event's placement by id, for assertions that don't care
  /// about the others' order in the returned list.
  CascadedEvent placementOf(List<CascadedEvent> result, String id) =>
      result.firstWhere((c) => c.event.id == id);

  group('cascadeEvents', () {
    test('a lone event gets column 0 of 1', () {
      final result = cascadeEvents([
        event(
          id: 'a',
          startAt: DateTime(2026, 1, 1, 9),
          endAt: DateTime(2026, 1, 1, 10),
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.single.column, 0);
      expect(result.single.columnCount, 1);
    });

    test('non-overlapping events each get column 0 of 1 — half-open, so '
        'one ending exactly when the next starts doesn\'t count as overlap', () {
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

      for (final c in result) {
        expect(c.columnCount, 1);
        expect(c.column, 0);
      }
    });

    test(
      'two events at the exact same start and end split into two separate '
      'columns, never sharing one',
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

        expect(placementOf(result, 'a').columnCount, 2);
        expect(placementOf(result, 'b').columnCount, 2);
        expect(
          {placementOf(result, 'a').column, placementOf(result, 'b').column},
          {0, 1},
        );
      },
    );

    test(
      'a 2-hour event and a 1-hour event starting an hour into it never '
      'share a column — the longer one keeps its column exclusively for '
      'its own full duration',
      () {
        final long = event(
          id: 'long',
          startAt: DateTime(2026, 1, 1, 13),
          endAt: DateTime(2026, 1, 1, 15),
        );
        final short = event(
          id: 'short',
          startAt: DateTime(2026, 1, 1, 14),
          endAt: DateTime(2026, 1, 1, 15),
        );

        final result = cascadeEvents([short, long]);

        expect(placementOf(result, 'long').columnCount, 2);
        expect(
          placementOf(result, 'long').column,
          isNot(placementOf(result, 'short').column),
        );
      },
    );

    test(
      'of two events starting together, the longer one takes column 0 '
      '(leftmost)',
      () {
        final shortFirst = event(
          id: 'short',
          startAt: DateTime(2026, 1, 1, 9),
          endAt: DateTime(2026, 1, 1, 10),
        );
        final longSecond = event(
          id: 'long',
          startAt: DateTime(2026, 1, 1, 9),
          endAt: DateTime(2026, 1, 1, 11),
        );

        // Passed in an order that would trick a naive "first seen wins
        // column 0" placement into picking the short one first.
        final result = cascadeEvents([shortFirst, longSecond]);

        expect(placementOf(result, 'long').column, 0);
        expect(placementOf(result, 'short').column, 1);
      },
    );

    test(
      'a transitive chain (A overlaps B, B overlaps C, A does not overlap '
      'C) needs only 2 columns, not 3 — A and C can share one since they '
      'never actually overlap each other',
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

        expect(placementOf(result, 'a').columnCount, 2);
        expect(placementOf(result, 'b').columnCount, 2);
        expect(placementOf(result, 'c').columnCount, 2);
        expect(placementOf(result, 'a').column, placementOf(result, 'c').column);
        expect(
          placementOf(result, 'b').column,
          isNot(placementOf(result, 'a').column),
        );
      },
    );

    test('separate clusters are laid out independently', () {
      final result = cascadeEvents([
        event(
          id: 'late-solo',
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

      expect(placementOf(result, 'late-solo').columnCount, 1);
      expect(placementOf(result, 'early-a').columnCount, 2);
      expect(placementOf(result, 'early-b').columnCount, 2);
    });
  });
}
