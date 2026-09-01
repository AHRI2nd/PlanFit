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
import 'package:planfit/features/schedule/presentation/schedule_screen.dart';
import 'package:planfit/features/schedule/presentation/week_view/week_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'schedule_screen_test.mocks.dart';

/// Pins [selectedDateProvider] to a fixed date instead of its own default
/// (today) — same pattern as month_view_test.dart's `_FixedSelectedDate`.
class _FixedSelectedDate extends SelectedDate {
  _FixedSelectedDate(this._date);
  final DateTime _date;
  @override
  DateTime build() => _date;
}

/// Pins [scheduleViewProvider] to a fixed [ScheduleView] instead of its own
/// default (day) — lets each test mount [ScheduleScreen] straight into the
/// view under test without first tapping the view switcher.
class _FixedScheduleView extends ScheduleViewMode {
  _FixedScheduleView(this._view);
  final ScheduleView _view;
  @override
  ScheduleView build() => _view;
}

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
      events.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const <EventRow>[]));
    when(todos.watchOverdue(any)).thenAnswer((_) => Stream.value(const []));
    when(
      todos.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const []));
  });

  /// Pumps the full [ScheduleScreen] with [view]/[selected] pinned, and
  /// returns the [ProviderContainer] backing it so tests can read
  /// [selectedDateProvider] directly — more precise than asserting on the
  /// rendered title text, since e.g. the month title only shows year+month
  /// and can't reveal a day-of-month clamp on its own.
  Future<ProviderContainer> pumpSchedule(
    WidgetTester tester, {
    required ScheduleView view,
    required DateTime selected,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(events),
          todoDaoProvider.overrideWithValue(todos),
          selectedDateProvider.overrideWith(() => _FixedSelectedDate(selected)),
          scheduleViewProvider.overrideWith(() => _FixedScheduleView(view)),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: AppTheme.light(),
              locale: const Locale('ko'),
              localizationsDelegates: const [
                AppL10n.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppL10n.supportedLocales,
              home: const ScheduleScreen(),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  /// Flings the title row's swipe target with a decisive velocity — matches
  /// the fling convention day_view_test.dart already uses for _EventCard's
  /// own swipe-to-delete threshold (±300 primaryVelocity).
  Future<void> swipeTitle(WidgetTester tester, {required bool leftward}) async {
    await tester.fling(
      find.byKey(const Key('scheduleTitleSwipe')),
      Offset(leftward ? -400 : 400, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('title swipe navigates selectedDateProvider', () {
    testWidgets('day view: left advances by 1 day', (tester) async {
      final selected = DateTime(2026, 3, 10);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.day,
        selected: selected,
      );
      await swipeTitle(tester, leftward: true);
      expect(container.read(selectedDateProvider), DateTime(2026, 3, 11));
    });

    testWidgets('day view: right goes back 1 day', (tester) async {
      final selected = DateTime(2026, 3, 10);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.day,
        selected: selected,
      );
      await swipeTitle(tester, leftward: false);
      expect(container.read(selectedDateProvider), DateTime(2026, 3, 9));
    });

    testWidgets('week view: left advances by 7 days', (tester) async {
      final selected = DateTime(2026, 3, 10);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.week,
        selected: selected,
      );
      await swipeTitle(tester, leftward: true);
      expect(container.read(selectedDateProvider), DateTime(2026, 3, 17));
    });

    testWidgets('week view: right goes back 7 days', (tester) async {
      final selected = DateTime(2026, 3, 10);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.week,
        selected: selected,
      );
      await swipeTitle(tester, leftward: false);
      expect(container.read(selectedDateProvider), DateTime(2026, 3, 3));
    });

    testWidgets('month view: left advances by 1 month, clamping day-of-month', (
      tester,
    ) async {
      // Jan 31 -> Feb has only 28 days in 2026 (not a leap year).
      final selected = DateTime(2026, 1, 31);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.month,
        selected: selected,
      );
      await swipeTitle(tester, leftward: true);
      expect(container.read(selectedDateProvider), DateTime(2026, 2, 28));
    });

    testWidgets('month view: right goes back 1 month', (tester) async {
      final selected = DateTime(2026, 3, 15);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.month,
        selected: selected,
      );
      await swipeTitle(tester, leftward: false);
      expect(container.read(selectedDateProvider), DateTime(2026, 2, 15));
    });

    testWidgets('year view: left advances by 1 year', (tester) async {
      final selected = DateTime(2026, 3, 15);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.year,
        selected: selected,
      );
      await swipeTitle(tester, leftward: true);
      expect(container.read(selectedDateProvider), DateTime(2027, 3, 15));
    });

    testWidgets('year view: right goes back 1 year', (tester) async {
      final selected = DateTime(2026, 3, 15);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.year,
        selected: selected,
      );
      await swipeTitle(tester, leftward: false);
      expect(container.read(selectedDateProvider), DateTime(2025, 3, 15));
    });

    testWidgets(
      'year view: the year label renders exactly once — regression test '
      'for YearView duplicating a second, non-swipeable "2026" over its '
      'grid that visually shadowed the real (swipeable) title above it',
      (tester) async {
        final selected = DateTime(2026, 3, 15);
        await pumpSchedule(tester, view: ScheduleView.year, selected: selected);
        expect(find.text('2026'), findsOneWidget);
      },
    );

    testWidgets(
      'agenda view: swiping the title is a no-op (no period to page)',
      (tester) async {
        final selected = DateTime(2026, 3, 15);
        final container = await pumpSchedule(
          tester,
          view: ScheduleView.agenda,
          selected: selected,
        );
        await swipeTitle(tester, leftward: true);
        expect(container.read(selectedDateProvider), selected);
        await swipeTitle(tester, leftward: false);
        expect(container.read(selectedDateProvider), selected);
      },
    );
  });

  group('body-region swipes', () {
    // The core safety constraint: day view's body already has its own
    // horizontal-drag gestures (event-card swipe-to-delete, todo
    // Dismissible), so the title-row swipe must never fire from there.
    testWidgets('day view: swiping an event card only triggers its own delete '
        'gesture, never date navigation', (tester) async {
      final selected = DateTime(2026, 3, 10);
      final event = row(
        id: 'ev1',
        title: 'Swipe target event',
        startAt: DateTime(2026, 3, 10, 9, 0),
        endAt: DateTime(2026, 3, 10, 10, 0),
      );
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value([event]));
      when(events.delete(any)).thenAnswer((_) async {});
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.day,
        selected: selected,
      );

      await tester.ensureVisible(find.text('Swipe target event'));
      await tester.pump();
      await tester.fling(
        find.text('Swipe target event'),
        const Offset(-400, 0),
        1000,
      );
      await tester.pump();
      // Let the swipe-delete's auto-dismiss snackbar Timer finish so no
      // pending Timer trips flutter_test's teardown check.
      await tester.pump(const Duration(seconds: 5));

      expect(container.read(selectedDateProvider), selected);
      // Confirms the swipe really did hit _EventCard's own gesture (not
      // just silently doing nothing at all).
      verify(events.delete('ev1')).called(1);
    });

    testWidgets(
      // Unlike day view: week view's own body has no delete-swipe (its
      // grid's only drag gesture is long-press-to-create, a different
      // recognizer type — see week_view.dart's own `_WeekPager` doc), so
      // its body is deliberately swipeable for week navigation, not
      // excluded from it. Thoroughly covered from week_view.dart's own
      // side in week_view_test.dart; this is just the integration-level
      // confirmation that ScheduleScreen doesn't get in the way of it.
      'week view: swiping the body navigates weeks, same as the title',
      (tester) async {
        final selected = DateTime(2026, 3, 10);
        final container = await pumpSchedule(
          tester,
          view: ScheduleView.week,
          selected: selected,
        );

        await tester.fling(find.byType(WeekView), const Offset(-400, 0), 1000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(container.read(selectedDateProvider), DateTime(2026, 3, 17));
      },
    );
  });
}
