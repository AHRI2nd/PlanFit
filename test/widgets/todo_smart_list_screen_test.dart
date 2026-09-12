import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/todo_dao.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/design/widgets/adaptive_bottom_sheet.dart'
    show kFloatingNavBarClearance;
import 'package:planfit/features/schedule/domain/ports.dart';
import 'package:planfit/features/todo/presentation/todo_smart_list_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'todo_smart_list_screen_test.mocks.dart';

// This screen has no single day to scope an inline add row to (unlike the
// day view's own HourlyTodoList) — it previously had no add affordance at
// all. These tests cover the FAB it gained: it opens a quick-add sheet, and
// submitting a title there actually creates the to-do and closes the sheet.
@GenerateMocks([TodoDao, NotificationPort, RemindersPort])
void main() {
  late MockTodoDao todos;
  late MockNotificationPort notifications;
  late MockRemindersPort reminders;

  setUp(() {
    todos = MockTodoDao();
    notifications = MockNotificationPort();
    reminders = MockRemindersPort();
    SharedPreferences.setMockInitialValues({});
    when(
      todos.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
    when(
      todos.watchOverdue(any),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
    when(
      todos.watchByMinPriority(any),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
    when(
      todos.watchPinned(),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
    when(todos.allTags()).thenAnswer((_) async => const <String>[]);
    // TodoController.add's _syncNotification/_syncReminder short-circuit on
    // a null row, keeping this test focused on the one write path it's
    // actually checking — same trick todo_detail_sheet_test.dart uses.
    when(todos.findById(any)).thenAnswer((_) async => null);
    when(todos.upsert(any)).thenAnswer((_) async {});
    when(notifications.cancelForTodo(any)).thenAnswer((_) async {});
    when(reminders.deleteTodo(any)).thenAnswer((_) async {});
    // Reminders sync stays off in these tests, same as it does with the
    // real RemindersService before the user ever opts in — TodoController
    // checks this before touching any other RemindersPort method.
    when(reminders.isEnabled).thenReturn(false);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    SmartListInitialTab initialTab = SmartListInitialTab.today,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          todoDaoProvider.overrideWithValue(todos),
          notificationPortProvider.overrideWithValue(notifications),
          remindersPortProvider.overrideWithValue(reminders),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          // Pinned so the test doesn't depend on the host machine's locale.
          locale: const Locale('ko'),
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: TodoSmartListScreen(initialTab: initialTab),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the FAB opens the quick-add sheet', (tester) async {
    await pumpScreen(tester);

    expect(find.text('할 일 추가'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('할 일 추가'), findsOneWidget);
  });

  testWidgets(
    'submitting a title in the quick-add sheet creates the to-do and closes the sheet',
    (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Buy milk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final captured =
          verify(todos.upsert(captureAny)).captured.single
              as TodoItemsCompanion;
      expect(captured.title.value, 'Buy milk');
      expect(find.text('할 일 추가'), findsNothing);
    },
  );

  testWidgets("a row's to-do checkbox has a tappable area of at least 44x44 — "
      'regression test for a hit box that used to be a 20px icon plus 4px '
      'of padding (~28x28), under the accessibility floor', (tester) async {
    final today = DateTime(2026, 3, 10);
    final todo = TodoRow(
      id: 't1',
      eventId: null,
      title: 'Buy milk',
      slotStart: today.add(const Duration(hours: 9)),
      slotEnd: null,
      hasTime: true,
      isDone: false,
      sortOrder: 0,
      priority: 0,
      tags: null,
      notify: false,
      isPinned: false,
      recurrenceRule: null,
      recurrenceGroupId: null,
      reminderSyncStatus: SyncStatus.pendingPush,
      createdAt: today,
    );
    when(todos.watchBetween(any, any)).thenAnswer((_) => Stream.value([todo]));

    await pumpScreen(tester);

    final hitArea = find.ancestor(
      of: find.byIcon(Icons.radio_button_unchecked),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 44 && w.height == 44,
      ),
    );
    expect(hitArea, findsOneWidget);
    final size = tester.getSize(hitArea);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets(
    "the list's bottom padding, and the FAB's own bottom offset, clear the "
    "floating glass nav bar — regression test: this screen (unlike "
    "schedule_screen.dart) had neither, so both sat behind the nav bar "
    'inside the same AppShell',
    (tester) async {
      final today = DateTime(2026, 3, 10);
      when(todos.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          TodoRow(
            id: 't1',
            eventId: null,
            title: 'Buy milk',
            slotStart: today.add(const Duration(hours: 9)),
            slotEnd: null,
            hasTime: true,
            isDone: false,
            sortOrder: 0,
            priority: 0,
            tags: null,
            notify: false,
            isPinned: false,
            recurrenceRule: null,
            recurrenceGroupId: null,
            reminderSyncStatus: SyncStatus.pendingPush,
            createdAt: today,
          ),
        ]),
      );
      await pumpScreen(tester);

      final list = tester.widget<ListView>(find.byType(ListView));
      final padding = list.padding! as EdgeInsets;
      expect(padding.bottom, kFloatingNavBarClearance);

      final fabPadding = tester.widget<Padding>(
        find.ancestor(
          of: find.byType(FloatingActionButton),
          matching: find.byType(Padding),
        ),
      );
      expect(
        (fabPadding.padding as EdgeInsets).bottom,
        kFloatingNavBarClearance,
      );
    },
  );

  group('swipe-to-delete', () {
    // Regression coverage: this screen used to have no way to delete a
    // to-do at all — the row was a plain InkWell with no Dismissible.
    late TodoRow todo;

    setUp(() {
      final today = DateTime(2026, 3, 10);
      todo = TodoRow(
        id: 't1',
        eventId: null,
        title: 'Buy milk',
        slotStart: today.add(const Duration(hours: 9)),
        slotEnd: null,
        hasTime: true,
        isDone: false,
        sortOrder: 0,
        priority: 0,
        tags: null,
        notify: false,
        isPinned: false,
        recurrenceRule: null,
        recurrenceGroupId: null,
        reminderSyncStatus: SyncStatus.pendingPush,
        createdAt: today,
      );
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value([todo]));
      // Overrides the outer setUp's findById->null stub (that one exists so
      // TodoController.add's own post-write sync short-circuits harmlessly
      // for the add-flow tests above) — the delete flow needs the real row
      // back so TodoController.remove doesn't bail out early.
      when(todos.findById(any)).thenAnswer((_) async => todo);
      when(todos.watchSubtasks(any)).thenAnswer((_) => Stream.value(const []));
      when(todos.deleteById(any)).thenAnswer((_) async {});
    });

    testWidgets('swiping a one-off to-do deletes it immediately, no dialog', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.drag(find.text('Buy milk'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('반복 할 일 삭제'), findsNothing);
      verify(todos.deleteById('t1')).called(1);
      // showAutoDismissSnackBar arms its own real Timer(snackBar.duration,
      // ...) (see snackbar_x.dart) — flutter_test's own invariant check
      // fails a test that ends with a pending Timer, so let it fire before
      // the test tears down (same pattern as holiday_calendar_source
      // _screen_test.dart's own snackbar tests).
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets(
      'swiping a recurring to-do asks this-only vs this-and-future before '
      'deleting',
      (tester) async {
        todo = todo.copyWith(recurrenceGroupId: const Value('series-1'));
        when(
          todos.watchBetween(any, any),
        ).thenAnswer((_) => Stream.value([todo]));
        when(
          todos.seriesFrom(any, any),
        ).thenAnswer((_) => Future.value([todo]));

        await pumpScreen(tester);

        await tester.drag(find.text('Buy milk'), const Offset(-500, 0));
        await tester.pumpAndSettle();

        expect(find.text('이 항목만 삭제'), findsOneWidget);
        await tester.tap(find.text('이 항목만 삭제'));
        await tester.pumpAndSettle();

        verify(todos.deleteById('t1')).called(1);
        verifyNever(todos.seriesFrom(any, any));
        // See the "one-off" test's own comment on why this is needed.
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });

  group('multi-select', () {
    // Regression coverage: this screen used to have no bulk-action path at
    // all, unlike the day view's own HourlyTodoList (long-press to select,
    // then complete/delete several to-dos at once).
    late TodoRow milk;
    late TodoRow eggs;

    setUp(() {
      final today = DateTime(2026, 3, 10);
      TodoRow row(String id, String title) => TodoRow(
        id: id,
        eventId: null,
        title: title,
        slotStart: today.add(const Duration(hours: 9)),
        slotEnd: null,
        hasTime: true,
        isDone: false,
        sortOrder: 0,
        priority: 0,
        tags: null,
        notify: false,
        isPinned: false,
        recurrenceRule: null,
        recurrenceGroupId: null,
        reminderSyncStatus: SyncStatus.pendingPush,
        createdAt: today,
      );
      milk = row('t1', 'Buy milk');
      eggs = row('t2', 'Buy eggs');
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value([milk, eggs]));
      when(todos.findById('t1')).thenAnswer((_) async => milk);
      when(todos.findById('t2')).thenAnswer((_) async => eggs);
      when(todos.watchSubtasks(any)).thenAnswer((_) => Stream.value(const []));
      when(todos.setDone(any, any)).thenAnswer((_) async {});
      when(todos.deleteById(any)).thenAnswer((_) async {});
    });

    testWidgets(
      'long-pressing a row enters selection mode, pre-selecting that row '
      'and replacing the tab chips with the selection toolbar',
      (tester) async {
        await pumpScreen(tester);

        expect(find.text('1개 선택됨'), findsNothing);
        await tester.longPress(find.text('Buy milk'));
        await tester.pump();

        expect(find.text('1개 선택됨'), findsOneWidget);
      },
    );

    testWidgets('tapping a second row while already selecting adds it to the '
        'selection, and the bulk-complete button completes every selected '
        'to-do', (tester) async {
      await pumpScreen(tester);

      await tester.longPress(find.text('Buy milk'));
      await tester.pump();
      await tester.tap(find.text('Buy eggs'));
      await tester.pump();
      expect(find.text('2개 선택됨'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pump();

      verify(todos.setDone('t1', true)).called(1);
      verify(todos.setDone('t2', true)).called(1);
      // Bulk actions exit selection mode afterward — back to the tab
      // chips, toolbar gone.
      expect(find.text('2개 선택됨'), findsNothing);
    });

    testWidgets(
      'the bulk-delete button removes every selected to-do at once, with '
      'a single combined undo snackbar',
      (tester) async {
        await pumpScreen(tester);

        await tester.longPress(find.text('Buy milk'));
        await tester.pump();
        await tester.tap(find.text('Buy eggs'));
        await tester.pump();

        await tester.tap(find.byIcon(Icons.delete_outline).last);
        await tester.pump();

        verify(todos.deleteById('t1')).called(1);
        verify(todos.deleteById('t2')).called(1);
        expect(find.textContaining('개를 삭제했어요'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('the cancel button exits selection mode without changing '
        'anything', (tester) async {
      await pumpScreen(tester);

      await tester.longPress(find.text('Buy milk'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('1개 선택됨'), findsNothing);
      verifyNever(todos.setDone(any, any));
      verifyNever(todos.deleteById(any));
    });
  });

  testWidgets(
    'opening with initialTab: overdue lands directly on the 기한 지남 tab — '
    "the home screen's overdue-backlog link relies on this to jump straight "
    'there instead of opening on 오늘 and requiring an extra tap',
    (tester) async {
      await pumpScreen(tester, initialTab: SmartListInitialTab.overdue);

      expect(find.text('기한 지난 할 일이 없어요'), findsOneWidget);
      expect(find.text('오늘 할 일이 없어요'), findsNothing);
    },
  );
}
