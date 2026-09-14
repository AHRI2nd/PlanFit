import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/date_math.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/schedule/domain/ports.dart';
import 'package:planfit/features/schedule/domain/recurrence.dart';
import 'package:planfit/features/todo/application/todo_providers.dart';

import 'todo_controller_test.mocks.dart';

@GenerateMocks([NotificationPort, RemindersPort])
void main() {
  late AppDatabase db;
  late MockNotificationPort notifications;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notifications = MockNotificationPort();
    when(notifications.scheduleForTodo(any)).thenAnswer((_) async {});
    when(notifications.cancelForTodo(any)).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationPortProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  TodoController controller() => container.read(todoControllerProvider);

  group('add', () {
    test(
      'schedules a notification when hasTime and notify default on',
      () async {
        final slot = DateTime.now().add(const Duration(hours: 2));
        await controller().add(title: 'Call dentist', slotStart: slot);

        final row = (await db.todoDao.all()).single;
        expect(row.notify, isTrue);
        verify(notifications.scheduleForTodo(row)).called(1);
        verifyNever(notifications.cancelForTodo(any));
      },
    );

    test('does not schedule when hasTime is false', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Someday', slotStart: slot, hasTime: false);

      final row = (await db.todoDao.all()).single;
      expect(row.notify, isFalse);
      verifyNever(notifications.scheduleForTodo(any));
    });

    test(
      'an explicit notify: false overrides the hasTime-based default',
      () async {
        final slot = DateTime.now().add(const Duration(hours: 2));
        await controller().add(
          title: 'Quiet reminder',
          slotStart: slot,
          notify: false,
        );

        final row = (await db.todoDao.all()).single;
        expect(row.notify, isFalse);
        verifyNever(notifications.scheduleForTodo(any));
      },
    );

    test('a yearly-repeating to-do with no explicit end date still repeats '
        'when its default window crosses a leap day — regression test: the '
        'old flat "start + 365 days" default landed exactly one day short '
        'of a leap-year anniversary, materializing only the original row '
        "and silently never repeating at all", () async {
      // 2028 is a leap year (Feb 29 falls between this start and its
      // 2028-06-15 anniversary), making the true gap 366 days.
      final slot = DateTime(2027, 6, 15, 9);
      await controller().add(
        title: 'Anniversary',
        slotStart: slot,
        frequency: RecurrenceFrequency.yearly,
      );

      final rows = await db.todoDao.all();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.slotStart).toSet(), {
        DateTime(2027, 6, 15, 9),
        DateTime(2028, 6, 15, 9),
      });
      // Both rows share one recurrenceGroupId — same materialized-series
      // convention as recurring events.
      expect(rows.map((r) => r.recurrenceGroupId).toSet(), hasLength(1));
    });
  });

  group('toggle', () {
    test('marking done cancels the notification', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      clearInteractions(notifications);

      await controller().toggle(row.id, true);

      verify(notifications.cancelForTodo(row.id)).called(1);
      verifyNever(notifications.scheduleForTodo(any));
    });

    test('un-marking a still-future done to-do re-schedules it', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      await controller().toggle(row.id, true);
      clearInteractions(notifications);

      await controller().toggle(row.id, false);

      verify(notifications.scheduleForTodo(any)).called(1);
    });
  });

  group('notification sync is best-effort', () {
    // Regression tests: syncTodoNotification used to have no error handling
    // at all, unlike every other notification/calendar/reminder side-effect
    // in this codebase — a thrown PlatformException (a real, known failure
    // mode of flutter_local_notifications on some Android OEMs/versions)
    // would have propagated out of these calls uncaught, even though the
    // to-do's own data write had already committed successfully.
    test('toggle still commits the done state even if cancelling the '
        'notification throws', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      when(
        notifications.cancelForTodo(row.id),
      ).thenThrow(Exception('platform channel unavailable'));

      await controller().toggle(row.id, true);

      expect((await db.todoDao.findById(row.id))?.isDone, isTrue);
    });

    test('add still creates the to-do even if scheduling its notification '
        'throws', () async {
      when(
        notifications.scheduleForTodo(any),
      ).thenThrow(Exception('platform channel unavailable'));
      final slot = DateTime.now().add(const Duration(hours: 2));

      await controller().add(title: 'Call dentist', slotStart: slot);

      expect((await db.todoDao.all()).single.title, 'Call dentist');
    });
  });

  group('setNotify', () {
    test('turning notify off cancels an already-scheduled to-do', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      clearInteractions(notifications);

      await controller().setNotify(row.id, false);

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.notify, isFalse);
      verify(notifications.cancelForTodo(row.id)).called(1);
    });
  });

  group('updateTitle', () {
    // Regression test: updateTitle used to build a title-only companion and
    // hand it to TodoDao.upsert (insertOnConflictUpdate), which validates
    // as if for a fresh insert — a companion missing e.g. slotStart threw
    // InvalidDataException before ever reaching the database, so a to-do's
    // title could never actually be edited via any path in the app. Fixed
    // by routing through TodoDao.patch (a real partial UPDATE) instead,
    // matching every other setter in this class.
    test('persists a new title without throwing', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;

      await controller().updateTitle(row.id, 'Call the dentist tomorrow');

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.title, 'Call the dentist tomorrow');
    });

    test('leaves every other column untouched', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(
        title: 'Call dentist',
        slotStart: slot,
        priority: 2,
        tags: 'health',
      );
      final row = (await db.todoDao.all()).single;

      await controller().updateTitle(row.id, 'Renamed');

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.slotStart, row.slotStart);
      expect(updated?.priority, 2);
      expect(updated?.tags, 'health');
    });
  });

  group('setPinned', () {
    test('persists the pinned flag', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;

      await controller().setPinned(row.id, true);

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.isPinned, isTrue);
    });

    test('unpinning clears the flag', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      await controller().setPinned(row.id, true);

      await controller().setPinned(row.id, false);

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.isPinned, isFalse);
    });
  });

  group('setAdditionalReminders', () {
    test('persists the joined offsets and re-syncs the notification', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      clearInteractions(notifications);

      await controller().setAdditionalReminders(row.id, {60, 1440});

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.additionalReminderMinutes, '60,1440');
      verify(notifications.scheduleForTodo(any)).called(1);
    });

    test('an empty set clears the column back to null', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      await controller().setAdditionalReminders(row.id, {60});

      await controller().setAdditionalReminders(row.id, {});

      final updated = await db.todoDao.findById(row.id);
      expect(updated?.additionalReminderMinutes, isNull);
    });
  });

  group('reorder', () {
    test(
      'moving the first item to the end rewrites sortOrder for all three',
      () async {
        final slot = DateTime.now().add(const Duration(hours: 2));
        await controller().add(title: 'A', slotStart: slot, hasTime: false);
        await controller().add(title: 'B', slotStart: slot, hasTime: false);
        await controller().add(title: 'C', slotStart: slot, hasTime: false);
        final rows = await db.todoDao.all();
        final a = rows.firstWhere((r) => r.title == 'A');
        final b = rows.firstWhere((r) => r.title == 'B');
        final c = rows.firstWhere((r) => r.title == 'C');

        // onReorderItem semantics: dragging index 0 to the end of a
        // 3-item list reports newIndex 2 (already adjusted, unlike the
        // deprecated onReorder).
        await controller().reorder([a, b, c], 0, 2);

        final updatedB = await db.todoDao.findById(b.id);
        final updatedC = await db.todoDao.findById(c.id);
        final updatedA = await db.todoDao.findById(a.id);
        expect(updatedB?.sortOrder, 0);
        expect(updatedC?.sortOrder, 1);
        expect(updatedA?.sortOrder, 2);
      },
    );

    test('the new order is reflected by a fresh query afterward', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'A', slotStart: slot, hasTime: false);
      await controller().add(title: 'B', slotStart: slot, hasTime: false);
      final rows = await db.todoDao.all();
      final a = rows.firstWhere((r) => r.title == 'A');
      final b = rows.firstWhere((r) => r.title == 'B');

      await controller().reorder([a, b], 0, 1);

      final start = DateTime(slot.year, slot.month, slot.day);
      final requeried = await db.todoDao.between(
        start,
        start.add(const Duration(days: 1)),
      );
      final byId = {for (final r in requeried) r.id: r};
      expect(byId[b.id]?.sortOrder, lessThan(byId[a.id]!.sortOrder));
    });

    test('two reorders driven from the same pre-drag snapshot never leave two '
        'items sharing a sortOrder — regression test: onReorderItem is a '
        'bare, non-awaited callback, so a second drag firing before the '
        "first's writes land (and the widget rebuilds with fresh data) "
        'calls reorder() with the same stale list both times; the old '
        "implementation only wrote an item's sortOrder when it differed "
        "from that (possibly stale) snapshot's own value, which could skip "
        "a write and leave an earlier call's leftover value in place — "
        'producing a genuine duplicate even with the two calls fully '
        'sequential (not interleaved)', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'A', slotStart: slot, hasTime: false);
      await controller().add(title: 'B', slotStart: slot, hasTime: false);
      await controller().add(title: 'C', slotStart: slot, hasTime: false);
      final rows = await db.todoDao.all();
      final a = rows.firstWhere((r) => r.title == 'A'); // sortOrder 0
      final b = rows.firstWhere((r) => r.title == 'B'); // sortOrder 1
      final c = rows.firstWhere((r) => r.title == 'C'); // sortOrder 2
      final staleSnapshot = [a, b, c];

      // Both calls see the identical pre-drag snapshot — exactly what
      // happens when a second drag starts before the first's rebuild.
      await controller().reorder(staleSnapshot, 1, 2);
      await controller().reorder(staleSnapshot, 0, 1);

      final finalRows = await db.todoDao.all();
      final sortOrders = finalRows.map((r) => r.sortOrder).toList();
      expect(
        sortOrders.toSet(),
        hasLength(sortOrders.length),
        reason:
            'two to-dos ended up sharing the same sortOrder: '
            '${finalRows.map((r) => (r.title, r.sortOrder))}',
      );
    });

    test('two overlapping (unawaited) reorder calls are serialized, never '
        "interleaving each other's writes", () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'A', slotStart: slot, hasTime: false);
      await controller().add(title: 'B', slotStart: slot, hasTime: false);
      await controller().add(title: 'C', slotStart: slot, hasTime: false);
      final rows = await db.todoDao.all();
      final a = rows.firstWhere((r) => r.title == 'A');
      final b = rows.firstWhere((r) => r.title == 'B');
      final c = rows.firstWhere((r) => r.title == 'C');
      final snapshot = [a, b, c];

      // Fire both without awaiting between them — mirrors
      // ReorderableListView.onReorderItem's own fire-and-forget shape.
      final first = controller().reorder(snapshot, 1, 2);
      final second = controller().reorder(snapshot, 0, 1);
      await Future.wait([first, second]);

      final finalRows = await db.todoDao.all();
      final sortOrders = finalRows.map((r) => r.sortOrder).toList();
      expect(sortOrders.toSet(), hasLength(sortOrders.length));
    });
  });

  group('todoTagsProvider invalidation', () {
    test('setTags makes a brand-new tag show up in the picker without a '
        'restart — regression test: todoTagsProvider is a plain '
        'FutureProvider that computes once and never refreshes; nothing '
        'invalidated it, so a newly-typed tag never appeared in the tag '
        'picker for the rest of the session', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'A', slotStart: slot, hasTime: false);
      final a = (await db.todoDao.all()).single;

      // Read once to seed the FutureProvider's cache, the same way the
      // real tag-picker UI's first build would.
      expect(await container.read(todoTagsProvider.future), isEmpty);

      await controller().setTags(a.id, 'urgent');

      expect(await container.read(todoTagsProvider.future), ['urgent']);
    });

    test("a tag whose only to-do is deleted stops showing up — same "
        'invalidation, the removal side', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'A', slotStart: slot, hasTime: false);
      final a = (await db.todoDao.all()).single;
      await controller().setTags(a.id, 'urgent');
      expect(await container.read(todoTagsProvider.future), ['urgent']);

      await controller().remove(a.id);

      expect(await container.read(todoTagsProvider.future), isEmpty);
    });

    test('a tag set at creation time is picked up immediately too', () async {
      expect(await container.read(todoTagsProvider.future), isEmpty);

      await controller().add(
        title: 'A',
        slotStart: DateTime.now().add(const Duration(hours: 2)),
        hasTime: false,
        tags: 'work',
      );

      expect(await container.read(todoTagsProvider.future), ['work']);
    });
  });

  group('pruneCompleted', () {
    test(
      'deletes a completed to-do older than retention, cancels its notification',
      () async {
        final slot = DateTime.now().subtract(const Duration(days: 10));
        await db.todoDao.upsert(
          TodoItemsCompanion.insert(
            id: 'old-done',
            title: const Value('Old task'),
            slotStart: slot,
            isDone: const Value(true),
            completedAt: Value(
              DateTime.now().subtract(const Duration(days: 8)),
            ),
          ),
        );
        clearInteractions(notifications);

        final count = await controller().pruneCompleted(
          const Duration(days: 7),
        );

        expect(count, 1);
        expect(await db.todoDao.findById('old-done'), isNull);
        verify(notifications.cancelForTodo('old-done')).called(1);
      },
    );

    test('leaves a recently-completed to-do alone', () async {
      final slot = DateTime.now();
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'recent-done',
          title: const Value('Recent task'),
          slotStart: slot,
          isDone: const Value(true),
          completedAt: Value(DateTime.now().subtract(const Duration(hours: 1))),
        ),
      );

      final count = await controller().pruneCompleted(const Duration(days: 7));

      expect(count, 0);
      expect(await db.todoDao.findById('recent-done'), isNotNull);
    });

    test('leaves a not-done to-do alone regardless of age', () async {
      final slot = DateTime.now().subtract(const Duration(days: 30));
      await controller().add(title: 'Still open', slotStart: slot);

      final count = await controller().pruneCompleted(const Duration(days: 7));

      expect(count, 0);
    });
  });

  /// `removeSeriesFrom` — "delete this occurrence and every future one" —
  /// had no test anywhere in the suite at any level, despite being the most
  /// destructive action the app offers and the one whose blast radius the
  /// user can't see before confirming it. `confirmAndDeleteTodo` routes
  /// every swipe-to-delete in the app into it.
  group('removeSeriesFrom', () {
    /// A daily series plus, deliberately, two things it must not touch: an
    /// unrelated series and a one-off on the same days.
    Future<List<TodoRow>> seedSeries() async {
      await controller().add(
        title: 'Standup',
        slotStart: DateTime(2026, 3, 10, 9),
        frequency: RecurrenceFrequency.daily,
        recurrenceUntil: DateTime(2026, 3, 14),
      );
      await controller().add(
        title: 'Other series',
        slotStart: DateTime(2026, 3, 10, 15),
        frequency: RecurrenceFrequency.daily,
        recurrenceUntil: DateTime(2026, 3, 14),
      );
      await controller().add(
        title: 'One-off',
        slotStart: DateTime(2026, 3, 12, 11),
      );
      final standup =
          (await db.todoDao.all()).where((t) => t.title == 'Standup').toList()
            ..sort((a, b) => a.slotStart.compareTo(b.slotStart));
      expect(standup.length, greaterThan(2), reason: 'need a tail to cut');
      return standup;
    }

    test('removes the given occurrence and every later one in its series, '
        'and nothing before it', () async {
      final standup = await seedSeries();

      await controller().removeSeriesFrom(standup[1]);

      final left = (await db.todoDao.all()).map((t) => t.id).toSet();
      expect(left, contains(standup.first.id));
      for (final gone in standup.skip(1)) {
        expect(left, isNot(contains(gone.id)));
      }
    });

    test('leaves other series and one-off to-dos on the same days alone — '
        'the cut is scoped by recurrenceGroupId, not by date', () async {
      final standup = await seedSeries();
      final untouched = (await db.todoDao.all())
          .where((t) => t.title != 'Standup')
          .map((t) => t.id)
          .toSet();

      await controller().removeSeriesFrom(standup[1]);

      final left = (await db.todoDao.all()).map((t) => t.id).toSet();
      expect(left.containsAll(untouched), isTrue);
    });

    test('returns every row it removed, so undo can restore the whole tail '
        'rather than only the occurrence that was swiped', () async {
      final standup = await seedSeries();
      final cut = standup.skip(1).map((t) => t.id).toSet();

      final removed = await controller().removeSeriesFrom(standup[1]);

      expect(removed.map((r) => r.todo.id).toSet(), cut);

      for (final r in removed) {
        await controller().restore(r);
      }
      final left = (await db.todoDao.all()).map((t) => t.id).toSet();
      expect(left.containsAll(standup.map((t) => t.id)), isTrue);
    });

    test("carries each removed row's subtasks, which cascade on delete and "
        'would otherwise be gone for good the moment undo ran', () async {
      final standup = await seedSeries();
      await controller().addSubtask(standup[1].id, 'Prep notes');
      await controller().addSubtask(standup[1].id, 'Send agenda');

      final removed = await controller().removeSeriesFrom(standup[1]);
      expect(
        (await db.todoDao.allSubtasks()).where(
          (s) => s.todoId == standup[1].id,
        ),
        isEmpty,
      );

      final bundle = removed.firstWhere((r) => r.todo.id == standup[1].id);
      expect(bundle.subtasks.map((s) => s.title), [
        'Prep notes',
        'Send agenda',
      ]);

      for (final r in removed) {
        await controller().restore(r);
      }
      expect(
        (await db.todoDao.allSubtasks())
            .where((s) => s.todoId == standup[1].id)
            .map((s) => s.title),
        ['Prep notes', 'Send agenda'],
      );
    });

    test(
      'falls back to a single-row delete for a to-do with no series',
      () async {
        await controller().add(
          title: 'One-off',
          slotStart: DateTime(2026, 3, 12, 11),
        );
        final row = (await db.todoDao.all()).single;

        final removed = await controller().removeSeriesFrom(row);

        expect(removed.map((r) => r.todo.id), [row.id]);
        expect(await db.todoDao.all(), isEmpty);
      },
    );
  });

  /// Changing a to-do's date had no path at all before this — the day
  /// list's trailing chip edits the time and nothing edited the day, so a
  /// to-do on the wrong date could only be deleted and retyped.
  group('updateDate', () {
    test(
      'moves a timed to-do to another day, keeping its time of day',
      () async {
        await controller().add(
          title: 'Call dentist',
          slotStart: DateTime(2026, 3, 10, 14, 30),
        );
        final row = (await db.todoDao.all()).single;

        await controller().updateDate(row.id, DateTime(2026, 4, 2));

        final moved = (await db.todoDao.all()).single;
        expect(moved.slotStart, DateTime(2026, 4, 2, 14, 30));
        expect(moved.hasTime, isTrue);
      },
    );

    test('leaves a no-time to-do without a time — the trap that makes this '
        'its own method rather than updateTime with a recomposed date, '
        'since updateSlotStart forces hasTime on', () async {
      await controller().add(
        title: 'Sometime Tuesday',
        slotStart: DateTime(2026, 3, 10),
        hasTime: false,
      );
      final row = (await db.todoDao.all()).single;
      expect(row.hasTime, isFalse);

      await controller().updateDate(row.id, DateTime(2026, 4, 2));

      final moved = (await db.todoDao.all()).single;
      expect(moved.hasTime, isFalse);
      expect(
        moved.slotStart,
        DateTime(2026, 4, 2),
        reason:
            "a no-time to-do normalizes to the new day's midnight, the same "
            'as clearTime does, or its stale clock time becomes an invisible '
            'sort key ahead of sortOrder',
      );
    });

    test(
      're-syncs the reminder, so a moved to-do alerts on its new day',
      () async {
        final soon = DateTime.now().add(const Duration(hours: 2));
        await controller().add(title: 'Call dentist', slotStart: soon);
        final row = (await db.todoDao.all()).single;
        clearInteractions(notifications);

        await controller().updateDate(row.id, addCalendarDays(soon, 1));

        verify(notifications.scheduleForTodo(any)).called(1);
      },
    );

    test('does nothing for an id that no longer exists', () async {
      await controller().updateDate('gone', DateTime(2026, 4, 2));
      expect(await db.todoDao.all(), isEmpty);
    });
  });

  group('remove / restore', () {
    test('remove cancels the notification', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      clearInteractions(notifications);

      await controller().remove(row.id);

      verify(notifications.cancelForTodo(row.id)).called(1);
    });

    test('restore re-schedules a notify-on to-do', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      final removed = await controller().remove(row.id);
      clearInteractions(notifications);

      await controller().restore(removed.single);

      verify(notifications.scheduleForTodo(any)).called(1);
    });

    test('restore preserves additionalReminderMinutes', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      await controller().setAdditionalReminders(row.id, {60});
      final removed = await controller().remove(row.id);

      await controller().restore(removed.single);

      final restored = await db.todoDao.findById(row.id);
      expect(restored?.additionalReminderMinutes, '60');
    });

    test('restore preserves isPinned', () async {
      final slot = DateTime.now().add(const Duration(hours: 2));
      await controller().add(title: 'Call dentist', slotStart: slot);
      final row = (await db.todoDao.all()).single;
      await controller().setPinned(row.id, true);
      final removed = await controller().remove(row.id);

      await controller().restore(removed.single);

      final restored = await db.todoDao.findById(row.id);
      expect(restored?.isPinned, isTrue);
    });
  });

  group('refillNotifications', () {
    test('schedules notify-on to-dos inside the window', () async {
      final slot = DateTime.now().add(const Duration(days: 1));
      await controller().add(title: 'Water plants', slotStart: slot);
      clearInteractions(notifications);

      await controller().refillNotifications();

      verify(notifications.scheduleForTodo(any)).called(1);
    });

    test(
      'skips a done to-do even if it is notify-on and in the window',
      () async {
        final slot = DateTime.now().add(const Duration(days: 1));
        await controller().add(title: 'Water plants', slotStart: slot);
        final row = (await db.todoDao.all()).single;
        await controller().toggle(row.id, true);
        clearInteractions(notifications);

        await controller().refillNotifications();

        verifyNever(notifications.scheduleForTodo(any));
      },
    );
  });

  group('_syncReminder push-failure revert', () {
    // Its own db/container/mocks — a reminders port that reports enabled
    // shouldn't leak into the other groups above, which don't stub it at
    // all.
    late AppDatabase remDb;
    late MockRemindersPort reminders;
    late ProviderContainer remContainer;

    setUp(() {
      remDb = AppDatabase(NativeDatabase.memory());
      reminders = MockRemindersPort();
      when(reminders.isEnabled).thenReturn(true);
      remContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(remDb),
          notificationPortProvider.overrideWithValue(notifications),
          remindersPortProvider.overrideWithValue(reminders),
        ],
      );
    });

    tearDown(() {
      remContainer.dispose();
      remDb.close();
    });

    TodoController remController() => remContainer.read(todoControllerProvider);

    Future<String> addAndSync() async {
      when(reminders.pushTodo(any)).thenAnswer((_) async => 'os-1');
      final slot = DateTime.now().add(const Duration(hours: 2));
      await remController().add(title: 'Buy milk', slotStart: slot);
      final row = (await remDb.todoDao.all()).single;
      expect(row.reminderSyncStatus, SyncStatus.synced);
      return row.id;
    }

    test(
      'a re-push returning null on an already-synced row reverts it to '
      'pendingPush instead of leaving it stuck at synced — regression '
      'test: leaving it at synced made the next RemindersReconciler pass '
      'treat this edit as a genuine Reminders-app change and pull the '
      'stale pre-edit values back over it, silently discarding the edit',
      () async {
        final id = await addAndSync();

        when(reminders.pushTodo(any)).thenAnswer((_) async => null);
        await remController().toggle(id, true);

        final row = await remDb.todoDao.findById(id);
        expect(row?.reminderSyncStatus, SyncStatus.pendingPush);
      },
    );

    test('a re-push throwing on an already-synced row reverts it to '
        'pendingPush the same way', () async {
      final id = await addAndSync();

      when(reminders.pushTodo(any)).thenThrow(Exception('EventKit error'));
      await remController().toggle(id, true);

      final row = await remDb.todoDao.findById(id);
      expect(row?.reminderSyncStatus, SyncStatus.pendingPush);
    });

    test(
      "a fresh row's first push failing stays pendingPush (no spurious "
      'revert needed, and no crash from patching a status it already has)',
      () async {
        when(reminders.pushTodo(any)).thenAnswer((_) async => null);
        final slot = DateTime.now().add(const Duration(hours: 2));
        await remController().add(title: 'New todo', slotStart: slot);

        final row = (await remDb.todoDao.all()).single;
        expect(row.reminderSyncStatus, SyncStatus.pendingPush);
      },
    );
  });
}
