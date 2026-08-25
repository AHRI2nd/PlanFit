import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/sync_log_dao.dart';
import 'package:planfit/core/db/daos/todo_dao.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/reminders_sync/reminders_reconciler.dart';
import 'package:planfit/core/reminders_sync/reminders_service.dart';
import 'package:planfit/features/schedule/domain/ports.dart';

import 'reminders_reconciler_test.mocks.dart';

@GenerateMocks([RemindersService, TodoDao, SyncLogDao, NotificationPort])
void main() {
  late MockRemindersService service;
  late MockTodoDao dao;
  late MockSyncLogDao syncLogDao;
  late MockNotificationPort notifications;
  late RemindersReconciler reconciler;

  TodoRow row({
    required String id,
    required DateTime slotStart,
    bool hasTime = true,
    bool isDone = false,
    String? osReminderId,
    SyncStatus reminderSyncStatus = SyncStatus.pendingPush,
    String title = 'todo',
  }) {
    return TodoRow(
      id: id,
      eventId: null,
      title: title,
      slotStart: slotStart,
      slotEnd: null,
      hasTime: hasTime,
      isDone: isDone,
      sortOrder: 0,
      priority: 0,
      tags: null,
      notify: false,
      isPinned: false,
      recurrenceRule: null,
      recurrenceGroupId: null,
      osReminderId: osReminderId,
      osReminderListId: null,
      osReminderLastKnownModified: null,
      reminderSyncStatus: reminderSyncStatus,
      createdAt: DateTime(2020),
    );
  }

  setUp(() {
    service = MockRemindersService();
    dao = MockTodoDao();
    syncLogDao = MockSyncLogDao();
    notifications = MockNotificationPort();
    reconciler = RemindersReconciler(
      service: service,
      todoDao: dao,
      syncLogDao: syncLogDao,
      notifications: notifications,
    );
    when(dao.needingReminderPush()).thenAnswer((_) async => []);
    when(dao.linkedToReminders()).thenAnswer((_) async => []);
    when(service.fetchReminders()).thenAnswer((_) async => []);
    when(syncLogDao.add(any)).thenAnswer((_) async {});
    when(notifications.cancelForTodo(any)).thenAnswer((_) async {});
    when(notifications.scheduleForTodo(any)).thenAnswer((_) async {});
  });

  test('does nothing when reminders sync is disabled', () async {
    when(service.isEnabled).thenReturn(false);

    final result = await reconciler.reconcile();

    expect(result, 0);
    verifyNever(dao.needingReminderPush());
    verifyNever(dao.linkedToReminders());
  });

  group('concurrency guard', () {
    test(
      'a reconcile() call started while one is already running is a '
      'no-op, not a second overlapping run',
      () async {
        when(service.isEnabled).thenReturn(true);

        // Not awaited between the two calls — the same shape as two
        // AppLifecycleState.resumed events firing in quick succession (see
        // RemindersReconciler._reconciling's doc).
        final first = reconciler.reconcile();
        final second = reconciler.reconcile();

        expect(await second, 0);
        expect(await first, 0);
        verify(dao.needingReminderPush()).called(1);
      },
    );

    test('a later call succeeds normally once the first has finished', () async {
      when(service.isEnabled).thenReturn(true);

      await reconciler.reconcile();
      await reconciler.reconcile();

      verify(dao.needingReminderPush()).called(2);
    });
  });

  group('push', () {
    test('pushes pending rows and marks them synced', () async {
      when(service.isEnabled).thenReturn(true);
      final now = DateTime(2026, 1, 1);
      final pending = row(
        id: 't1',
        slotStart: now.add(const Duration(hours: 1)),
      );
      when(dao.needingReminderPush()).thenAnswer((_) async => [pending]);
      when(service.pushTodo(pending)).thenAnswer((_) async => 'os-1');
      when(service.targetListId).thenReturn('list-1');
      when(dao.patch(any, any)).thenAnswer((_) async {});

      final changes = await reconciler.reconcile(now: now);

      expect(changes, 1);
      final captured =
          verify(dao.patch('t1', captureAny)).captured.single
              as TodoItemsCompanion;
      expect(captured.osReminderId.value, 'os-1');
      expect(captured.reminderSyncStatus.value, SyncStatus.synced);
    });

    test(
      'a push that returns null (sync unavailable) is not counted',
      () async {
        when(service.isEnabled).thenReturn(true);
        final pending = row(id: 't1', slotStart: DateTime(2026, 1, 1));
        when(dao.needingReminderPush()).thenAnswer((_) async => [pending]);
        when(service.pushTodo(pending)).thenAnswer((_) async => null);

        final changes = await reconciler.reconcile();

        expect(changes, 0);
        verifyNever(dao.patch(any, any));
      },
    );
  });

  group('pull', () {
    test('a synced row matching the OS reminder is left untouched', () async {
      when(service.isEnabled).thenReturn(true);
      final slot = DateTime(2026, 1, 1, 9);
      final linked = row(
        id: 't1',
        slotStart: slot,
        osReminderId: 'os-1',
        reminderSyncStatus: SyncStatus.synced,
        title: 'Standup',
      );
      when(dao.linkedToReminders()).thenAnswer((_) async => [linked]);
      when(service.fetchReminders()).thenAnswer(
        (_) async => [
          OsReminder(
            osReminderId: 'os-1',
            title: 'Standup',
            isCompleted: false,
            dueDate: slot,
          ),
        ],
      );

      final changes = await reconciler.reconcile();

      expect(changes, 0);
      verifyNever(dao.patch(any, any));
    });

    test('pulls a title/completion edit made in the Reminders app', () async {
      when(service.isEnabled).thenReturn(true);
      final now = DateTime(2026, 1, 1, 12);
      final slot = DateTime(2026, 1, 1, 9);
      final linked = row(
        id: 't1',
        slotStart: slot,
        osReminderId: 'os-1',
        reminderSyncStatus: SyncStatus.synced,
        title: 'Standup',
      );
      when(dao.linkedToReminders()).thenAnswer((_) async => [linked]);
      when(service.fetchReminders()).thenAnswer(
        (_) async => [
          OsReminder(
            osReminderId: 'os-1',
            title: 'Standup (renamed)',
            isCompleted: true,
            dueDate: slot,
          ),
        ],
      );
      when(dao.patch(any, any)).thenAnswer((_) async {});
      when(dao.findById('t1')).thenAnswer(
        (_) async => row(
          id: 't1',
          slotStart: slot,
          osReminderId: 'os-1',
          reminderSyncStatus: SyncStatus.synced,
          title: 'Standup (renamed)',
          isDone: true,
        ),
      );

      final changes = await reconciler.reconcile(now: now);

      expect(changes, 1);
      final captured =
          verify(dao.patch('t1', captureAny)).captured.single
              as TodoItemsCompanion;
      expect(captured.title.value, 'Standup (renamed)');
      expect(captured.isDone.value, isTrue);
      expect(captured.completedAt.value, now);
      verify(notifications.cancelForTodo('t1')).called(1);
    });

    test('a due date cleared in the Reminders app moves the to-do into its '
        'existing day\'s no-time bucket, normalized to midnight', () async {
      when(service.isEnabled).thenReturn(true);
      final slot = DateTime(2026, 1, 1, 9);
      final linked = row(
        id: 't1',
        slotStart: slot,
        osReminderId: 'os-1',
        reminderSyncStatus: SyncStatus.synced,
      );
      when(dao.linkedToReminders()).thenAnswer((_) async => [linked]);
      when(service.fetchReminders()).thenAnswer(
        (_) async => [
          const OsReminder(
            osReminderId: 'os-1',
            title: 'todo',
            isCompleted: false,
            dueDate: null,
          ),
        ],
      );
      when(dao.patch(any, any)).thenAnswer((_) async {});
      when(dao.findById('t1')).thenAnswer(
        (_) async => row(
          id: 't1',
          slotStart: DateTime(2026, 1, 1),
          hasTime: false,
          osReminderId: 'os-1',
          reminderSyncStatus: SyncStatus.synced,
        ),
      );

      await reconciler.reconcile();

      final captured =
          verify(dao.patch('t1', captureAny)).captured.single
              as TodoItemsCompanion;
      expect(captured.hasTime.value, isFalse);
      expect(captured.slotStart.value, DateTime(2026, 1, 1));
    });

    test('a to-do deleted in the Reminders app is removed locally', () async {
      when(service.isEnabled).thenReturn(true);
      final linked = row(
        id: 't1',
        slotStart: DateTime(2026, 1, 1),
        osReminderId: 'os-1',
        reminderSyncStatus: SyncStatus.synced,
      );
      when(dao.linkedToReminders()).thenAnswer((_) async => [linked]);
      when(service.fetchReminders()).thenAnswer((_) async => []);
      when(dao.deleteById('t1')).thenAnswer((_) async {});

      final changes = await reconciler.reconcile();

      expect(changes, 1);
      verify(dao.deleteById('t1')).called(1);
      verify(notifications.cancelForTodo('t1')).called(1);
    });

    test('a still-pendingPush row is skipped by the pull scan (only push side '
        'touches it)', () async {
      when(service.isEnabled).thenReturn(true);
      final linked = row(
        id: 't1',
        slotStart: DateTime(2026, 1, 1),
        osReminderId: 'os-1',
        reminderSyncStatus: SyncStatus.pendingPush,
      );
      when(dao.linkedToReminders()).thenAnswer((_) async => [linked]);
      when(service.fetchReminders()).thenAnswer((_) async => []);

      final changes = await reconciler.reconcile();

      expect(changes, 0);
      verifyNever(dao.deleteById(any));
    });
  });
}
