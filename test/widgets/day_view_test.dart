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
import 'package:planfit/features/schedule/presentation/day_view/day_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'day_view_test.mocks.dart';

@GenerateMocks([EventRepository, TodoDao])
void main() {
  late MockEventRepository events;
  late MockTodoDao todos;

  EventRow row({
    required String id,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    return EventRow(
      id: id,
      title: title,
      memo: null,
      location: null,
      startAt: startAt,
      endAt: endAt,
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
      todos.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
  });

  Future<void> pumpDay(WidgetTester tester, DateTime day) async {
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
          home: Scaffold(body: DayView(day: day)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a 2-hour event fully containing a shorter one keeps its full '
      'rendered height — not truncated to where the shorter one starts', (
    tester,
  ) async {
    final day = DateTime(2026, 3, 10);
    final long = row(
      id: 'long',
      title: 'Long',
      startAt: DateTime(2026, 3, 10, 14),
      endAt: DateTime(2026, 3, 10, 16),
    );
    final short = row(
      id: 'short',
      title: 'Short',
      startAt: DateTime(2026, 3, 10, 15),
      endAt: DateTime(2026, 3, 10, 16),
    );
    when(
      events.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value([long, short]));

    await pumpDay(tester, day);

    final longCard = tester.getSize(
      find
          .ancestor(
            of: find.text('Long'),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );

    // Long spans 14:00-16:00 — 2 hours — at DayView's own 64px/hour, its
    // rendered (minimum) height must be at least 128px, not truncated
    // down to Short's 1-hour span just because Short starts partway
    // through it.
    expect(longCard.height, greaterThanOrEqualTo(128));
  });

  testWidgets(
    'two events starting at the same time but ending differently each '
    'keep their own full height',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      final long = row(
        id: 'long',
        title: 'Long',
        startAt: DateTime(2026, 3, 10, 15),
        endAt: DateTime(2026, 3, 10, 17),
      );
      final short = row(
        id: 'short',
        title: 'Short',
        startAt: DateTime(2026, 3, 10, 15),
        endAt: DateTime(2026, 3, 10, 16),
      );
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value([long, short]));

      await pumpDay(tester, day);

      final longCard = tester.getSize(
        find
            .ancestor(
              of: find.text('Long'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );

      // Long spans 15:00-17:00 — 2 hours — regardless of Short sharing its
      // start time and ending an hour earlier.
      expect(longCard.height, greaterThanOrEqualTo(128));
    },
  );

  testWidgets(
    'swiping an event card left with enough velocity deletes it — the '
    'hand-rolled replacement for Dismissible',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      final e = row(
        id: 'e1',
        title: 'Swipe me',
        startAt: DateTime(2026, 3, 10, 2),
        endAt: DateTime(2026, 3, 10, 3),
      );
      when(events.watchBetween(any, any)).thenAnswer((_) => Stream.value([e]));
      when(events.delete(any)).thenAnswer((_) async {});

      await pumpDay(tester, day);

      await tester.fling(find.text('Swipe me'), const Offset(-400, 0), 1000);
      await tester.pump();

      verify(events.delete('e1')).called(1);

      // The delete flow shows an auto-dismissing SnackBar with its own
      // timer — let it run out before teardown, same as event_editor_
      // sheet_test.dart's truncation-snackbar tests.
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
