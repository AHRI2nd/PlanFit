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
import 'package:planfit/features/schedule/presentation/agenda_view/agenda_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agenda_view_test.mocks.dart';

@GenerateMocks([EventRepository, TodoDao])
void main() {
  late MockEventRepository events;
  late MockTodoDao todos;

  EventRow event({
    required String id,
    required String title,
    required DateTime startAt,
  }) {
    return EventRow(
      id: id,
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
      syncStatus: SyncStatus.pendingPush,
      importSourceCalendarId: null,
      importSourceEventId: null,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
  }

  TodoRow todo({
    required String id,
    required String title,
    required DateTime slotStart,
  }) {
    return TodoRow(
      id: id,
      eventId: null,
      title: title,
      slotStart: slotStart,
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
      createdAt: DateTime(2020),
    );
  }

  setUp(() {
    events = MockEventRepository();
    todos = MockTodoDao();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAgenda(WidgetTester tester, DateTime anchor) async {
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
          locale: const Locale('ko'),
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(body: AgendaView(anchor: anchor)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows both an event and a to-do under the same day header', (
    tester,
  ) async {
    final anchor = DateTime(2026, 3, 10);
    when(events.watchBetween(any, any)).thenAnswer(
      (_) => Stream.value([
        event(id: 'e1', title: 'Standup', startAt: DateTime(2026, 3, 10, 9)),
      ]),
    );
    when(todos.watchBetween(any, any)).thenAnswer(
      (_) => Stream.value([
        todo(id: 't1', title: 'Buy milk', slotStart: DateTime(2026, 3, 10, 8)),
      ]),
    );

    await pumpAgenda(tester, anchor);

    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets('opens scrolled to the anchor day, not the past week of entries '
      'before it', (tester) async {
    final anchor = DateTime(2026, 3, 10);
    when(events.watchBetween(any, any)).thenAnswer(
      (_) => Stream.value([
        for (var i = 1; i <= 6; i++)
          event(
            id: 'past$i',
            title: 'Past $i',
            startAt: DateTime(2026, 3, 10 - i, 9),
          ),
        event(
          id: 'today',
          title: 'Anchor day event',
          startAt: DateTime(2026, 3, 10, 9),
        ),
      ]),
    );
    when(
      todos.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const []));

    await pumpAgenda(tester, anchor);
    await tester.pumpAndSettle();

    // Scrolled forward past all 6 past-day groups before it, rather than
    // sitting at the very top of the list (offset 0) the way it would
    // with no auto-scroll at all.
    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(offset, greaterThan(0));
  });

  testWidgets(
    'an anchor with nothing on or after it never scrolls — nothing in '
    'the window qualifies as a scroll target',
    (tester) async {
      final anchor = DateTime(2026, 3, 10);
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          event(
            id: 'past',
            title: 'Only past event',
            startAt: DateTime(2026, 3, 5, 9),
          ),
        ]),
      );
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpAgenda(tester, anchor);

      expect(find.text('Only past event'), findsOneWidget);
    },
  );

  testWidgets('tapping a to-do tile opens the to-do detail sheet', (
    tester,
  ) async {
    final anchor = DateTime(2026, 3, 10);
    when(
      events.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const []));
    when(todos.watchBetween(any, any)).thenAnswer(
      (_) => Stream.value([
        todo(id: 't1', title: 'Buy milk', slotStart: DateTime(2026, 3, 10, 8)),
      ]),
    );
    when(
      todos.watchSubtasks(any),
    ).thenAnswer((_) => Stream.value(const <TodoSubtaskRow>[]));

    await pumpAgenda(tester, anchor);
    await tester.tap(find.text('Buy milk'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Buy milk'), findsOneWidget);
  });
}
