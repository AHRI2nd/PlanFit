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
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/presentation/date_strip.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'date_strip_test.mocks.dart';

@GenerateMocks([EventRepository, TodoDao])
void main() {
  late MockEventRepository events;
  late MockTodoDao todos;

  EventRow row({required String id, required DateTime startAt}) {
    return EventRow(
      id: id,
      title: id,
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

  setUp(() {
    events = MockEventRepository();
    todos = MockTodoDao();
    SharedPreferences.setMockInitialValues({});
    when(
      events.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const <EventRow>[]));
    when(
      todos.watchOverdue(any),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
  });

  Future<ProviderContainer> pumpStrip(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        eventRepositoryProvider.overrideWithValue(events),
        todoDaoProvider.overrideWithValue(todos),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
          home: const Scaffold(body: DateStrip()),
        ),
      ),
    );
    // The initial center-on-selected jump runs from a post-frame callback.
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('tapping a nearby day selects it', (tester) async {
    final container = await pumpStrip(tester);
    final before = container.read(selectedDateProvider);
    final target = before.add(const Duration(days: 2));

    await tester.tap(find.byKey(ValueKey(target)));
    await tester.pump();

    expect(container.read(selectedDateProvider), target);
  });

  testWidgets('a day with an event shows a dot, a plain day does not', (
    tester,
  ) async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final withEvent = today.add(const Duration(days: 1));
    final withoutEvent = today.add(const Duration(days: 2));
    when(
      events.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value([row(id: 'e1', startAt: withEvent)]));

    await pumpStrip(tester);

    expect(find.byKey(ValueKey('dot-$withEvent')), findsOneWidget);
    expect(find.byKey(ValueKey('dot-$withoutEvent')), findsNothing);
  });
}
