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
import 'package:planfit/features/todo/presentation/todo_detail_sheet.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'todo_detail_sheet_test.mocks.dart';

// Covers two bugs this sheet had, found together while chasing one report:
// 1. title/tags only persisted on onSubmitted/onTapOutside, so swiping the
//    sheet down or the Android back gesture (a bare Navigator pop, neither
//    of which fires those callbacks) silently lost whatever was typed.
// 2. Independently of #1, a title edit never actually reached the database
//    on ANY path (submit included) — TodoController.updateTitle built a
//    title-only companion and handed it to TodoDao.upsert
//    (insertOnConflictUpdate), which validates as if for a fresh insert and
//    throws InvalidDataException on a companion missing e.g. slotStart. The
//    write's Future was never awaited by the UI, so this failure was a
//    silent, uncaught exception — title edits have likely never worked.
// These tests drive the pop-without-submit path (proving #1's PopScope
// flush fires) and assert on TodoDao.patch, the real partial-update method
// #2's fix routes through instead of upsert.
@GenerateMocks([TodoDao])
void main() {
  late MockTodoDao todos;

  TodoRow todo({String title = 'Buy milk'}) {
    final now = DateTime(2026, 3, 10, 9);
    return TodoRow(
      id: 't1',
      eventId: null,
      title: title,
      slotStart: now,
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
      createdAt: now,
    );
  }

  setUp(() {
    todos = MockTodoDao();
    SharedPreferences.setMockInitialValues({});
    when(
      todos.watchSubtasks(any),
    ).thenAnswer((_) => Stream.value(const <TodoSubtaskRow>[]));
    // `_syncNotification`/`_syncReminder` (triggered by updateTitle) both
    // short-circuit on a null row, so this keeps the test focused on the
    // one write path it's actually checking.
    when(todos.findById(any)).thenAnswer((_) async => null);
    when(todos.patch(any, any)).thenAnswer((_) async {});
    when(todos.setTags(any, any)).thenAnswer((_) async {});
    when(todos.setPinned(any, any)).thenAnswer((_) async {});
    when(todos.setPriority(any, any)).thenAnswer((_) async {});
    when(todos.upsertSubtask(any)).thenAnswer((_) async {});
    when(todos.deleteSubtask(any)).thenAnswer((_) async {});
  });

  // Korean strings pinned via pumpSheetHost's `locale: const Locale('ko')` —
  // matches app_ko.arb directly rather than routing through AppL10n, since
  // these tests don't otherwise need a BuildContext of their own.
  const failureMessage = '저장하지 못했어요. 다시 시도해주세요';

  Future<void> pumpSheetHost(WidgetTester tester, TodoRow initial) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          todoDaoProvider.overrideWithValue(todos),
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
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showTodoDetailSheet(context, initial),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editing the title then popping the sheet without submitting still saves it',
    (tester) async {
      final t = todo();
      await pumpSheetHost(tester, t);

      await tester.enterText(find.byType(TextField).first, 'Buy oat milk');
      // Deliberately just a bare pop — no receiveAction/submit, no
      // tapOutside — mirroring what swipe-to-dismiss and the back gesture
      // actually invoke under the hood. A single pump is enough for
      // PopScope's synchronous flush callback to run; deliberately not
      // pumpAndSettle so the close animation's real time can't accidentally
      // let the debounce timer fire too and make the assertion ambiguous
      // about which mechanism actually saved it.
      Navigator.of(tester.element(find.byType(TextField).first)).pop();
      await tester.pump();

      final captured =
          verify(todos.patch(t.id, captureAny)).captured.single
              as TodoItemsCompanion;
      expect(captured.title.value, 'Buy oat milk');
    },
  );

  testWidgets(
    'editing tags then popping the sheet without submitting still saves them',
    (tester) async {
      final t = todo();
      await pumpSheetHost(tester, t);

      await tester.enterText(find.byType(TextField).at(1), 'home, urgent');
      Navigator.of(tester.element(find.byType(TextField).at(1))).pop();
      await tester.pump();

      verify(todos.setTags(t.id, 'home, urgent')).called(1);
    },
  );

  group('pin toggle', () {
    testWidgets('persists the flip when the save succeeds', (tester) async {
      final t = todo();
      await pumpSheetHost(tester, t);
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
      expect(find.text(failureMessage), findsNothing);
      verify(todos.setPinned(t.id, true)).called(1);
    });

    testWidgets(
      'reverts the icon and shows a SnackBar when the save fails',
      (tester) async {
        final t = todo();
        when(
          todos.setPinned(any, any),
        ).thenThrow(Exception('disk full'));
        await pumpSheetHost(tester, t);
        expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

        await tester.tap(find.byIcon(Icons.push_pin_outlined));
        // One pump for the optimistic setState, a second for the
        // catch block's revert setState to land.
        await tester.pump();
        await tester.pump();

        // Reverted back to the pre-tap (unpinned) icon, not left showing
        // the optimistic (pinned) one the DB write never actually made.
        expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
        expect(find.byIcon(Icons.push_pin), findsNothing);
        expect(find.text(failureMessage), findsOneWidget);
        // Flush showAutoDismissSnackBar's own real Timer — flutter_test
        // fails a test that ends with one still pending (see
        // holiday_calendar_source_screen_test.dart for the same pattern).
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });

  group('priority chip', () {
    testWidgets('persists the new priority when the save succeeds', (
      tester,
    ) async {
      final t = todo();
      await pumpSheetHost(tester, t);

      await tester.tap(find.widgetWithText(ChoiceChip, '높음'));
      await tester.pump();
      await tester.pump();

      expect(find.text(failureMessage), findsNothing);
      verify(todos.setPriority(t.id, 3)).called(1);
    });

    testWidgets(
      'reverts to the previous chip and shows a SnackBar when the save '
      'fails',
      (tester) async {
        final t = todo();
        when(
          todos.setPriority(any, any),
        ).thenThrow(Exception('disk full'));
        await pumpSheetHost(tester, t);

        // Fixture starts at priority 0 ("없음") — select "높음" instead.
        await tester.tap(find.widgetWithText(ChoiceChip, '높음'));
        await tester.pump();
        await tester.pump();

        final none = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, '없음'),
        );
        final high = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, '높음'),
        );
        expect(none.selected, isTrue);
        expect(high.selected, isFalse);
        expect(find.text(failureMessage), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });

  group('add subtask', () {
    testWidgets(
      'leaves the typed text in place and shows a SnackBar when the save '
      'fails',
      (tester) async {
        final t = todo();
        when(
          todos.upsertSubtask(any),
        ).thenThrow(Exception('disk full'));
        await pumpSheetHost(tester, t);

        final subtaskField = find.byType(TextField).last;
        await tester.enterText(subtaskField, 'Buy eggs');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.pump();

        // Not cleared — the user's typed text survives a failed add.
        expect(find.text('Buy eggs'), findsOneWidget);
        expect(find.text(failureMessage), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });

  group('remove subtask', () {
    testWidgets('shows a SnackBar when the removal fails', (tester) async {
      final t = todo();
      final subtask = TodoSubtaskRow(
        id: 's1',
        todoId: t.id,
        title: 'Buy eggs',
        isDone: false,
        sortOrder: 0,
        createdAt: DateTime(2026, 3, 10, 9),
      );
      when(
        todos.watchSubtasks(t.id),
      ).thenAnswer((_) => Stream.value([subtask]));
      when(
        todos.deleteSubtask(any),
      ).thenThrow(Exception('disk full'));
      await pumpSheetHost(tester, t);
      expect(find.text('Buy eggs'), findsOneWidget);

      await tester.drag(find.text('Buy eggs'), const Offset(-500, 0));
      // Dismissible needs its dismiss + resize animations to actually run
      // to completion before `onDismissed` fires — a bare pump() or two
      // isn't enough (unlike the pin/priority cases above, whose
      // setState-driven UI updates land within a frame or two).
      await tester.pumpAndSettle();

      expect(find.text(failureMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
