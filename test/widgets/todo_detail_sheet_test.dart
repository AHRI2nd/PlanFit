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
  });

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
}
