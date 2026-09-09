import 'dart:async';

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
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/presentation/search/event_search_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'event_search_screen_test.mocks.dart';

// Regression coverage for a stale-results race: _onChanged's debounce
// timer coalesces rapid keystrokes, and its generation counter stops an
// *older, still in-flight* search from clobbering a *newer* one's results
// once both resolve. But that counter was only ever bumped where a new
// search actually started — clearing the box back to empty took the
// "reset to no results" branch instead, which never touched it. A search
// still in flight when the user cleared the box kept its now-stale
// generation number, matched whatever _searchGeneration still was, and
// overwrote the just-cleared (correct) empty state once it finally
// resolved.
@GenerateMocks([EventRepository, TodoDao])
void main() {
  late MockEventRepository eventRepository;
  late MockTodoDao todoDao;

  EventRow event({String id = 'e1', String title = 'Team standup'}) {
    final now = DateTime(2026, 3, 10, 9);
    return EventRow(
      id: id,
      title: title,
      memo: null,
      location: null,
      startAt: now,
      endAt: now.add(const Duration(hours: 1)),
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
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    eventRepository = MockEventRepository();
    todoDao = MockTodoDao();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          todoDaoProvider.overrideWithValue(todoDao),
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
          home: const EventSearchScreen(),
        ),
      ),
    );
  }

  testWidgets(
    'clearing the search box while a slower search is still in flight does '
    'not let its stale results reappear once it finally resolves',
    (tester) async {
      final pending = Completer<List<EventRow>>();
      when(eventRepository.search('abc')).thenAnswer((_) => pending.future);
      when(todoDao.search('abc')).thenAnswer((_) async => <TodoRow>[]);

      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'abc');
      // Past the 250ms debounce — the search has now actually started and
      // is awaiting `pending`.
      await tester.pump(const Duration(milliseconds: 300));

      // Clear the box before that search resolves.
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      // The slow search for "abc" finally comes back.
      pending.complete([event()]);
      await tester.pump();
      await tester.pump();

      // The box is empty again; its stale result must not appear.
      expect(find.text('Team standup'), findsNothing);
    },
  );

  testWidgets('a fresh search started right after clearing still shows its own '
      'results normally — the fix only suppresses the stale one, not '
      'search itself', (tester) async {
    when(
      eventRepository.search('xyz'),
    ).thenAnswer((_) async => [event(title: 'Xylophone lesson')]);
    when(todoDao.search('xyz')).thenAnswer((_) async => <TodoRow>[]);

    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Xylophone lesson'), findsOneWidget);
  });

  testWidgets('tapping an event result closes search and opens the read-only '
      'preview over the day view it jumped to', (tester) async {
    when(
      eventRepository.search('team'),
    ).thenAnswer((_) async => [event(title: 'Team standup')]);
    when(todoDao.search('team')).thenAnswer((_) async => <TodoRow>[]);

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'team');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(find.text('Team standup'));
    await tester.pumpAndSettle();

    // The search box itself is gone (this tap closes search first, same
    // as it always has) — a lone "편집하기" button and no title-prefilled
    // TextField is what distinguishes the preview from the full editor.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('편집하기'), findsOneWidget);
  });

  testWidgets(
    'long-pressing an event result closes search and skips straight to '
    'the editor, title pre-filled',
    (tester) async {
      when(
        eventRepository.search('team'),
      ).thenAnswer((_) async => [event(title: 'Team standup')]);
      when(todoDao.search('team')).thenAnswer((_) async => <TodoRow>[]);

      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'team');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tester.longPress(find.text('Team standup'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Team standup'), findsOneWidget);
      expect(find.text('편집하기'), findsNothing);
    },
  );
}
