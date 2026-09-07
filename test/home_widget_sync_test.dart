import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/home_widget/home_widget_sync.dart';

void main() {
  EventRow event({required String title, required DateTime startAt}) {
    return EventRow(
      id: 'e-$title',
      title: title,
      memo: null,
      location: null,
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
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
      syncStatus: SyncStatus.localOnly,
      importSourceCalendarId: null,
      importSourceEventId: null,
      createdAt: startAt,
      updatedAt: startAt,
    );
  }

  TodoRow todo({
    required String id,
    required String title,
    bool isDone = false,
    int priority = 0,
  }) {
    final now = DateTime(2026, 3, 10, 9);
    return TodoRow(
      id: id,
      eventId: null,
      title: title,
      slotStart: now,
      slotEnd: null,
      hasTime: true,
      isDone: isDone,
      sortOrder: 0,
      priority: priority,
      tags: null,
      notify: false,
      additionalReminderMinutes: null,
      recurrenceRule: null,
      recurrenceGroupId: null,
      isPinned: false,
      osReminderId: null,
      osReminderListId: null,
      osReminderLastKnownModified: null,
      reminderSyncStatus: SyncStatus.pendingPush,
      createdAt: now,
    );
  }

  // Regression coverage for the "~20 separate saveWidgetData calls, no
  // atomicity" bug: HomeWidgetSync.push now builds one JSON-encodable map
  // (via this function) and writes it in a single platform-channel call.
  // push() itself is gated behind Platform.isAndroid/isIOS, which is always
  // false when running `flutter test` on a plain dev machine, so this pure
  // builder is what's actually exercised here — push composing it into a
  // single saveWidgetData call is a one-line, by-construction guarantee
  // (down from ~20 calls) that isn't itself meaningfully unit-testable on
  // this host, same limitation already documented for other
  // Platform.isIOS/isAndroid-gated code in this codebase.
  group('buildWidgetSnapshot', () {
    test('blank placeholders fill every unused event/todo slot', () {
      final snapshot = buildWidgetSnapshot(
        upcomingEvents: const [],
        todayTodos: const [],
        now: DateTime(2026, 3, 10),
      );

      for (var i = 0; i < HomeWidgetSync.maxEvents; i++) {
        expect(snapshot['event${i}_title'], '');
        expect(snapshot['event${i}_time'], '');
        expect(snapshot['event${i}_uri'], '');
      }
      for (var i = 0; i < HomeWidgetSync.maxWidgetTodos; i++) {
        expect(snapshot['todo${i}_id'], '');
        expect(snapshot['todo${i}_title'], '');
        expect(snapshot['todo${i}_done'], false);
        expect(snapshot['todo${i}_priority'], 0);
      }
      expect(snapshot['todos_progress'], '0/0');
    });

    test('a present event fills its slot with title/time/deep-link uri', () {
      final start = DateTime(2026, 3, 10, 14, 30);
      final snapshot = buildWidgetSnapshot(
        upcomingEvents: [event(title: 'Standup', startAt: start)],
        todayTodos: const [],
        now: DateTime(2026, 3, 10),
      );

      expect(snapshot['event0_title'], 'Standup');
      expect(snapshot['event0_time'], '14:30');
      expect(
        snapshot['event0_uri'],
        HomeWidgetSync.scheduleUri(start).toString(),
      );
      // Unused slots still blank, not left over from a previous push.
      expect(snapshot['event1_title'], '');
      expect(snapshot['event2_title'], '');
    });

    test(
      'not-done to-dos sort before done ones, independent of input order',
      () {
        final snapshot = buildWidgetSnapshot(
          upcomingEvents: const [],
          todayTodos: [
            todo(id: 't-done', title: 'Already done', isDone: true),
            todo(id: 't-undone', title: 'Still to do', isDone: false),
          ],
          now: DateTime(2026, 3, 10),
        );

        expect(snapshot['todo0_id'], 't-undone');
        expect(snapshot['todo0_done'], false);
        expect(snapshot['todo1_id'], 't-done');
        expect(snapshot['todo1_done'], true);
      },
    );

    test('todos_progress counts done out of total, todos_uri points at '
        '"now"', () {
      final snapshot = buildWidgetSnapshot(
        upcomingEvents: const [],
        todayTodos: [
          todo(id: 't1', title: 'A', isDone: true),
          todo(id: 't2', title: 'B', isDone: false),
          todo(id: 't3', title: 'C', isDone: false),
        ],
        now: DateTime(2026, 3, 10),
      );

      expect(snapshot['todos_progress'], '1/3');
      expect(
        snapshot['todos_uri'],
        HomeWidgetSync.scheduleUri(DateTime(2026, 3, 10)).toString(),
      );
    });

    test('a to-do\'s priority carries through to its slot', () {
      final snapshot = buildWidgetSnapshot(
        upcomingEvents: const [],
        todayTodos: [todo(id: 't1', title: 'Important', priority: 3)],
        now: DateTime(2026, 3, 10),
      );

      expect(snapshot['todo0_priority'], 3);
    });
  });

  group('HomeWidgetSync.scheduleUri / parseScheduleDate', () {
    test('round-trips a date through the deep link uri', () {
      final day = DateTime(2026, 8, 1);
      final uri = HomeWidgetSync.scheduleUri(day);
      expect(HomeWidgetSync.parseScheduleDate(uri), day);
    });

    test('pads single-digit month and day', () {
      final uri = HomeWidgetSync.scheduleUri(DateTime(2026, 3, 5));
      expect(uri.toString(), 'planfit://schedule?date=2026-03-05');
    });

    test('parseScheduleDate rejects null, wrong scheme, and wrong host', () {
      expect(HomeWidgetSync.parseScheduleDate(null), isNull);
      expect(
        HomeWidgetSync.parseScheduleDate(
          Uri.parse('https://schedule?date=2026-08-01'),
        ),
        isNull,
      );
      expect(
        HomeWidgetSync.parseScheduleDate(Uri.parse('planfit://home')),
        isNull,
      );
    });
  });
}
