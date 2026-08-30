import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/todo_dao.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/todo/presentation/todo_smart_list_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'todo_smart_list_screen_test.mocks.dart';

// This screen has no single day to scope an inline add row to (unlike the
// day view's own HourlyTodoList) — it previously had no add affordance at
// all. These tests cover the FAB it gained: it opens a quick-add sheet, and
// submitting a title there actually creates the to-do and closes the sheet.
@GenerateMocks([TodoDao])
void main() {
  late MockTodoDao todos;

  setUp(() {
    todos = MockTodoDao();
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
  });

  Future<void> pumpScreen(WidgetTester tester) async {
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
          home: const TodoSmartListScreen(),
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

      final captured = verify(todos.upsert(captureAny)).captured.single
          as TodoItemsCompanion;
      expect(captured.title.value, 'Buy milk');
      expect(find.text('할 일 추가'), findsNothing);
    },
  );
}
