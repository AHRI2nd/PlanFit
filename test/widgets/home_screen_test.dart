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
import 'package:planfit/features/home/presentation/home_screen.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen_test.mocks.dart';

@GenerateMocks([EventRepository, TodoDao])
void main() {
  late MockEventRepository events;
  late MockTodoDao todos;

  setUp(() async {
    events = MockEventRepository();
    todos = MockTodoDao();
    SharedPreferences.setMockInitialValues({});

    // HomeScreen's empty-state cards only need these to resolve — every
    // watch* the screen (and its _WeeklyStats/_TodayTodos children) can
    // reach gets a default empty stream so a test can override just the
    // one it cares about.
    when(
      events.watchUpcoming(any, limit: anyNamed('limit')),
    ).thenAnswer((_) => Stream.value(const <EventRow>[]));
    when(
      events.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const <EventRow>[]));
    when(
      todos.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
  });

  Future<void> pumpHome(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(events),
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
          home: const HomeScreen(),
        ),
      ),
    );
    // Time-driven pieces (the clock, the weekly bar's entrance animation)
    // never settle on their own — a couple of frames is enough for the
    // empty-state cards to build.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows every empty state when there is no data', (tester) async {
    await pumpHome(tester);

    // The merged today feed (events + to-dos) shows one empty state now,
    // not the two separate ones the old _UpcomingList/_TodayTodos cards had.
    expect(find.text('오늘은 예정된 일정도, 할 일도 없어요'), findsOneWidget);
    expect(find.text('이번 주는 아직 조용하네요'), findsOneWidget);
  });

  testWidgets('renders an upcoming event\'s title once data arrives', (
    tester,
  ) async {
    final now = DateTime.now();
    final event = EventRow(
      id: 'e1',
      title: 'Team sync',
      memo: null,
      startAt: now.add(const Duration(hours: 1)),
      endAt: now.add(const Duration(hours: 2)),
      isAllDay: false,
      notify: true,
      reminderMinutesBefore: 0,
      colorTag: null,
      recurrenceRule: null,
      recurrenceGroupId: null,
      osCalendarId: null,
      osEventId: null,
      osLastKnownModified: null,
      syncStatus: SyncStatus.pendingPush,
      createdAt: now,
      updatedAt: now,
    );
    when(
      events.watchUpcoming(any, limit: anyNamed('limit')),
    ).thenAnswer((_) => Stream.value([event]));

    await pumpHome(tester);

    expect(find.text('Team sync'), findsOneWidget);
    expect(find.text('오늘은 예정된 일정도, 할 일도 없어요'), findsNothing);
  });

  testWidgets(
    "renders today's to-do title once data arrives, interleaved with events",
    (tester) async {
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
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value([todo]));

      await pumpHome(tester);

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('오늘은 예정된 일정도, 할 일도 없어요'), findsNothing);
    },
  );
}
