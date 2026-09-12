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
import 'package:planfit/features/schedule/domain/ports.dart';
import 'package:planfit/features/todo/presentation/quick_add_todo_sheet.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quick_add_todo_field_test.mocks.dart';

// QuickAddTodoField is shared verbatim by HourlyTodoList, the home screen,
// and QuickAddTodoSheet — those call sites' own tests exercise the common
// "type a title, submit, it's created" path, but none of them cover the
// [day]-scoped behavior (the "added to another day" snackbar, resetting
// picks when the anchor day itself changes) that only this widget's own
// doc actually specifies.
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
    when(todos.findById(any)).thenAnswer((_) async => null);
    when(todos.upsert(any)).thenAnswer((_) async {});
    when(notifications.cancelForTodo(any)).thenAnswer((_) async {});
    when(reminders.deleteTodo(any)).thenAnswer((_) async {});
    when(reminders.isEnabled).thenReturn(false);
  });

  Future<void> pumpField(
    WidgetTester tester, {
    DateTime? day,
    VoidCallback? onAdded,
    bool forceOptionsExpanded = false,
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
          locale: const Locale('ko'),
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: QuickAddTodoField(
              day: day,
              onAdded: onAdded,
              forceOptionsExpanded: forceOptionsExpanded,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'typing a title and submitting creates the to-do, clears the field, '
    'and calls onAdded',
    (tester) async {
      var added = false;
      await pumpField(tester, onAdded: () => added = true);

      await tester.enterText(find.byType(TextField).first, 'Buy milk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final captured =
          verify(todos.upsert(captureAny)).captured.single
              as TodoItemsCompanion;
      expect(captured.title.value, 'Buy milk');
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      expect(added, isTrue);
    },
  );

  testWidgets(
    'a "내일 오후 3시" phrase in the title overrides the date/time chips, '
    'and only the remaining text becomes the title',
    (tester) async {
      final now = DateTime.now();
      await pumpField(tester);

      await tester.enterText(
        find.byType(TextField).first,
        '내일 오후 3시 병원',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final captured =
          verify(todos.upsert(captureAny)).captured.single
              as TodoItemsCompanion;
      expect(captured.title.value, '병원');
      final slotStart = captured.slotStart.value;
      // "내일" is relative to whenever the test actually runs (parseQuickAdd
      // reads DateTime.now() itself) — pin down just the parsed time-of-day,
      // which is what this test is actually about, rather than the date.
      expect(slotStart.hour, 15);
      expect(slotStart.minute, 0);
      // Sanity: still resolves to a day after "now" was captured above,
      // not today.
      expect(slotStart.isAfter(now), isTrue);
      // No day was given, so the parsed date differs from the auto
      // "today" anchor and _submit's own snackbar fires — let its real
      // Timer run out before the test tears down (see snackbar_x.dart).
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'when a day is given, no date chip renders — the day itself is that '
    "chip's job; only the time chip remains",
    (tester) async {
      await pumpField(tester, day: DateTime(2026, 3, 10));
      expect(find.byTooltip('날짜'), findsNothing);

      await pumpField(tester, day: null);
      expect(find.byTooltip('날짜'), findsOneWidget);
    },
  );

  testWidgets(
    'submitting a title whose parsed date lands on a different day than '
    'the field\'s own [day] shows an "added to another day" snackbar',
    (tester) async {
      // Anchor the field on a day far from "today" so any real-world test
      // run date still parses "내일" to something else.
      final anchor = DateTime(2020, 1, 1);
      await pumpField(tester, day: anchor);

      await tester.enterText(find.byType(TextField).first, '내일 회의');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.textContaining('에 추가했어요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'forceOptionsExpanded starts with the details panel open and makes the '
    'tune toggle inert — the home screen\'s offstage measurement clone '
    "relies on this to measure the panel's true height without ever "
    'letting a user actually collapse it',
    (tester) async {
      await pumpField(tester, forceOptionsExpanded: true);

      expect(find.byIcon(Icons.tag), findsOneWidget);
      final toggle = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.expand_less),
      );
      expect(toggle.onPressed, isNull);
    },
  );
}
