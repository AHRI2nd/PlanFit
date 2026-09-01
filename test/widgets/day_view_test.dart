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
import 'package:planfit/features/schedule/presentation/day_view/day_clock_view.dart';
import 'package:planfit/features/schedule/presentation/day_view/day_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'day_view_test.mocks.dart';

/// Pins [selectedDateProvider] to a fixed date instead of its own default
/// (today) — same pattern week_view_test.dart's `_FixedSelectedDate` uses,
/// needed so a swipe that snaps back to the same day (no page change, so
/// nothing writes to the provider) can be asserted against a known value
/// rather than "whatever today happens to be."
class _FixedSelectedDate extends SelectedDate {
  _FixedSelectedDate(this._date);
  final DateTime _date;
  @override
  DateTime build() => _date;
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
    String? location,
  }) {
    return EventRow(
      id: id,
      title: title,
      memo: null,
      location: location,
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

  Future<ProviderContainer> pumpDay(
    WidgetTester tester,
    DateTime day, {
    bool compact = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(events),
          todoDaoProvider.overrideWithValue(todos),
          selectedDateProvider.overrideWith(() => _FixedSelectedDate(day)),
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
              home: Scaffold(
                body: DayView(day: day, compact: compact),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
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
            matching: find.byType(RepaintBoundary),
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
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );

      // Long spans 15:00-17:00 — 2 hours — regardless of Short sharing its
      // start time and ending an hour earlier.
      expect(longCard.height, greaterThanOrEqualTo(128));
    },
  );

  testWidgets('a short event with a location gets enough extra height for its '
      'location row, no overflow', (tester) async {
    // Regression test — found via manual testing: a 1-hour event with a
    // location clamped to the (location-unaware) minimum card height
    // threw a real "RenderFlex overflowed by 10.0 pixels", not just a
    // debug-banner cosmetic one.
    final day = DateTime(2026, 3, 10);
    final e = row(
      id: 'e1',
      title: 'Coffee',
      startAt: DateTime(2026, 3, 10, 9),
      endAt: DateTime(2026, 3, 10, 10),
      location: '1234 Main St',
    );
    when(events.watchBetween(any, any)).thenAnswer((_) => Stream.value([e]));

    await pumpDay(tester, day);

    expect(tester.takeException(), isNull);
    final card = tester.getSize(
      find
          .ancestor(
            of: find.text('Coffee'),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    expect(card.height, greaterThanOrEqualTo(100));
  });

  testWidgets(
    // _EventCard's own swipe-to-delete was removed in favor of freeing the
    // whole all-day/timeline area for swipe-to-navigate instead — deleting
    // an event now only happens from the edit sheet's own delete button.
    'swiping an event card no longer deletes it — that horizontal drag is '
    'now the day-navigation surface',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      final e = row(
        id: 'e1',
        title: 'Swipe me',
        startAt: DateTime(2026, 3, 10, 2),
        endAt: DateTime(2026, 3, 10, 3),
      );
      when(events.watchBetween(any, any)).thenAnswer((_) => Stream.value([e]));

      final container = await pumpDay(tester, day);

      await tester.fling(find.text('Swipe me'), const Offset(-400, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      verifyNever(events.delete(any));
      // The swipe navigates the day instead, same as swiping anywhere else
      // in this all-day/timeline area.
      expect(container.read(selectedDateProvider), DateTime(2026, 3, 11));
    },
  );

  group('swiping the all-day/timeline area navigates by whole days', () {
    testWidgets('a left fling advances to the next day', (tester) async {
      final day = DateTime(2026, 3, 10);
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      final container = await pumpDay(tester, day);

      await tester.fling(
        find.byKey(const Key('dayContentSwipe')),
        const Offset(-400, 0),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(selectedDateProvider), DateTime(2026, 3, 11));
    });

    testWidgets('a right fling goes back to the previous day', (tester) async {
      final day = DateTime(2026, 3, 10);
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      final container = await pumpDay(tester, day);

      await tester.fling(
        find.byKey(const Key('dayContentSwipe')),
        const Offset(400, 0),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(selectedDateProvider), DateTime(2026, 3, 9));
    });

    // The core UX fix this pager exists for — see _DayContentPager's own
    // doc: a real PageView, so a slow drag (no meaningful velocity) still
    // pages once it's dragged past roughly half the viewport, and
    // magnet-snaps *back* to the original day if released short of that.
    testWidgets('a slow drag past roughly half the page width still advances a '
        'day, with no meaningful velocity', (tester) async {
      final day = DateTime(2026, 3, 10);
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      final container = await pumpDay(tester, day);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('dayContentSwipe'))),
      );
      for (var i = 0; i < 15; i++) {
        await gesture.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(container.read(selectedDateProvider), DateTime(2026, 3, 11));
    });

    testWidgets(
      'a short drag that never crosses the halfway point snaps back to '
      'the same day',
      (tester) async {
        final day = DateTime(2026, 3, 10);
        when(
          events.watchBetween(any, any),
        ).thenAnswer((_) => Stream.value(const []));

        final container = await pumpDay(tester, day);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('dayContentSwipe'))),
        );
        await gesture.moveBy(const Offset(-80, 0));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(container.read(selectedDateProvider), day);
      },
    );

    // The compact embedded instance under MonthView's calendar grid is a
    // preview, not a navigable view of its own — it shouldn't silently
    // move selectedDateProvider (which MonthView's own grid selection also
    // drives) out from under whatever the grid says is selected.
    testWidgets('compact:true does not swipe-navigate', (tester) async {
      final day = DateTime(2026, 3, 10);
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      final container = await pumpDay(tester, day, compact: true);

      expect(find.byKey(const Key('dayContentSwipe')), findsNothing);
      await tester.fling(find.byType(DayView), const Offset(-400, 0), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // selectedDateProvider was never touched at all — still its pinned
      // starting value, not day±1.
      expect(container.read(selectedDateProvider), day);
    });
  });

  testWidgets(
    'the to-dos header "+" focuses the inline add field, no scrolling by hand',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpDay(tester, day);

      // Empty day, no to-dos yet — the inline add field is the only
      // TextField DayView renders at all.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isFalse);

      await tester.tap(find.byTooltip('할 일 추가'));
      await tester.pump();

      final refocused = tester.widget<TextField>(find.byType(TextField));
      expect(refocused.focusNode!.hasFocus, isTrue);
    },
  );

  testWidgets(
    'the clock layout preference switches a full DayView to DayClockView',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          row(
            id: 'e',
            title: 'Lunch',
            startAt: DateTime(2026, 3, 10, 12),
            endAt: DateTime(2026, 3, 10, 13),
          ),
        ]),
      );
      SharedPreferences.setMockInitialValues({
        'schedule.dayViewLayoutMode': 'clock',
      });

      await pumpDay(tester, day);

      expect(find.byType(DayClockView), findsOneWidget);
      // The dial itself carries no title text (see DayClockView's own
      // doc) — DayClockLegend, rendered right below it, is where "Lunch"
      // actually has to show up. The dial is a square sized off the test
      // surface's own (much wider-than-a-phone) width, so the legend sits
      // past the ListView's lazy-build cache until scrolled into view —
      // exactly the same "tall square dial" reality a real phone has too,
      // just more pronounced at the test surface's default size.
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();

      expect(find.byType(DayClockLegend), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a title in the clock legend opens the same editor an arc tap '
    'would',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      final lunch = row(
        id: 'e1',
        title: 'Lunch',
        startAt: DateTime(2026, 3, 10, 12),
        endAt: DateTime(2026, 3, 10, 13),
      );
      final dinner = row(
        id: 'e2',
        title: 'Dinner',
        startAt: DateTime(2026, 3, 10, 19),
        endAt: DateTime(2026, 3, 10, 20),
      );
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value([lunch, dinner]));
      SharedPreferences.setMockInitialValues({
        'schedule.dayViewLayoutMode': 'clock',
      });

      await pumpDay(tester, day);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();

      // Both titles show, sorted by start time.
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);

      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();

      // showEventEditor for an existing event opens its title pre-filled
      // into the editor's own text field.
      expect(find.widgetWithText(TextField, 'Dinner'), findsOneWidget);
    },
  );

  testWidgets(
    'compact:true keeps the timeline even when the clock layout is the '
    'saved preference — the embedded month-view instance never shows the '
    'dial',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          row(
            id: 'e',
            title: 'Lunch',
            startAt: DateTime(2026, 3, 10, 12),
            endAt: DateTime(2026, 3, 10, 13),
          ),
        ]),
      );
      SharedPreferences.setMockInitialValues({
        'schedule.dayViewLayoutMode': 'clock',
      });

      await pumpDay(tester, day, compact: true);

      expect(find.byType(DayClockView), findsNothing);
    },
  );
}
