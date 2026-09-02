import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/date_math.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/todo_dao.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/design/tokens/event_color_tag.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'month_view_test.mocks.dart';

/// Pins [selectedDateProvider] to a fixed, safely-mid-month date instead of
/// its own default (today) — MonthView also embeds a `compact` [DayView]
/// for whichever day is selected, and today's own date drifts as the suite
/// runs on different days, risking a multi-day event's span crossing a
/// month boundary depending on when in the month the test happens to run.
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

  EventRow multiDayEvent({
    required String id,
    required DateTime startAt,
    required DateTime endAt,
    required String colorTag,
  }) {
    return EventRow(
      id: id,
      title: id,
      memo: null,
      location: null,
      startAt: startAt,
      endAt: endAt,
      isAllDay: true,
      colorTag: colorTag,
      notify: false,
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

  EventRow singleDayEvent({
    required String id,
    required DateTime day,
    String? colorTag,
  }) {
    return EventRow(
      id: id,
      title: id,
      memo: null,
      location: null,
      startAt: day,
      endAt: day.add(const Duration(hours: 1)),
      isAllDay: false,
      colorTag: colorTag,
      notify: false,
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
    when(todos.watchOverdue(any)).thenAnswer((_) => Stream.value(const []));
    when(
      todos.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const []));
  });

  Future<void> pumpMonth(WidgetTester tester, DateTime selected) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(events),
          todoDaoProvider.overrideWithValue(todos),
          selectedDateProvider.overrideWith(() => _FixedSelectedDate(selected)),
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
          home: const Scaffold(body: MonthView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets(
    'a multi-day all-day event renders its own colorTag as a bar across the '
    'days it spans',
    (tester) async {
      final eventStart = DateTime(2026, 3, 10);
      // A different day than the event's own start/span, same month —
      // just keeps this test's selection independent of the span under
      // test, unrelated to a selected day's own marker (see the dedicated
      // regression test below for that).
      final selectedDay = DateTime(2026, 3, 20);
      const tag = '#3388CC';
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          multiDayEvent(
            id: 'trip',
            startAt: eventStart,
            endAt: addCalendarDays(eventStart, 3),
            colorTag: tag,
          ),
        ]),
      );

      await pumpMonth(tester, selectedDay);

      final expectedColor = EventColorTag.resolve(tag, eventStart);
      // The month grid's own bar Container (height: 4, per month_view.dart)
      // — filtered on that exact height too, not just color, since the
      // selected day's embedded compact DayView renders this same event's
      // color again on its own 3×30 accent strip, which would otherwise
      // false-positive-match on color alone.
      final bars = tester.widgetList<Container>(find.byType(Container)).where((
        c,
      ) {
        final decoration = c.decoration;
        return decoration is BoxDecoration &&
            decoration.color == expectedColor &&
            c.constraints?.maxHeight == 4;
      });

      // One bar per day cell the 3-day event actually spans.
      expect(bars, hasLength(3));
    },
  );

  testWidgets(
    "a selected day's collapsed event dot keeps its real color instead of "
    'turning white — regression test for the marker being invisible '
    "against the cell's own (plain) background once selected: the accent "
    'selection circle only wraps the day number, never the whole cell, so '
    'a marker positioned below it never actually sits on that circle',
    (tester) async {
      final day = DateTime(2026, 3, 15);
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([singleDayEvent(id: 'e1', day: day)]),
      );

      // Select the very day the event is on — exactly the scenario that
      // used to turn the marker white.
      await pumpMonth(tester, day);

      final dots = tester.widgetList<Container>(find.byType(Container)).where(
        (c) {
          final decoration = c.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle &&
              c.constraints?.maxWidth == monthCollapsedDotSize;
        },
      );

      expect(dots, hasLength(1));
      expect(
        (dots.first.decoration as BoxDecoration).color,
        isNot(Colors.white),
      );
    },
  );

  testWidgets(
    "the collapsed summary shows one dot per event, each in that event's "
    'own color, instead of collapsing straight to a single generic dot — '
    'up to _monthCollapsedMaxDots (4)',
    (tester) async {
      final day = DateTime(2026, 3, 15);
      const tags = ['#3388CC', '#CC3388', '#88CC33'];
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          for (var i = 0; i < tags.length; i++)
            singleDayEvent(id: 'e$i', day: day, colorTag: tags[i]),
        ]),
      );

      await pumpMonth(tester, DateTime(2026, 3, 1));

      final dots = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) {
            final decoration = c.decoration;
            return decoration is BoxDecoration &&
                decoration.shape == BoxShape.circle &&
                c.constraints?.maxWidth == monthCollapsedDotSize;
          })
          .toList();

      expect(dots, hasLength(tags.length));
      final dotColors = dots
          .map((c) => (c.decoration as BoxDecoration).color)
          .toSet();
      final expectedColors = tags
          .map((t) => EventColorTag.resolve(t, day))
          .toSet();
      expect(dotColors, expectedColors);
      // No "+N" overflow text should render — there's room for one dot per
      // event at this count.
      expect(find.text('+${tags.length}'), findsNothing);
    },
  );

  testWidgets(
    'the collapsed summary switches to a "+N" count once a day has more '
    'events than fit as individual dots',
    (tester) async {
      final day = DateTime(2026, 3, 15);
      const eventCount = 5; // one more than _monthCollapsedMaxDots (4)
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          for (var i = 0; i < eventCount; i++)
            singleDayEvent(id: 'e$i', day: day),
        ]),
      );

      await pumpMonth(tester, DateTime(2026, 3, 1));

      expect(find.text('+$eventCount'), findsOneWidget);
      final dots = tester.widgetList<Container>(find.byType(Container)).where(
        (c) {
          final decoration = c.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle &&
              c.constraints?.maxWidth == monthCollapsedDotSize;
        },
      );
      expect(
        dots,
        isEmpty,
        reason: 'once over the dot cap, no individual dots should render',
      );
    },
  );

  group('expanded list mode (row dragged tall enough for a real list)', () {
    /// Mirrors MonthCalendarRowHeight's own persistence key — pre-seeding
    /// SharedPreferences with it is the simplest way to get the grid into
    /// expanded-list mode for these tests, without needing a whole
    /// override-the-notifier ceremony.
    const rowHeightPrefsKey = 'schedule.monthCalendarRowHeight';

    /// The events.watchBetween mock below answers with the same fixed list
    /// for *any* date range (the `any, any` matchers don't check the actual
    /// range), so the selected day's own embedded compact DayView ends up
    /// "seeing" these same events too, alongside the month grid's own
    /// (correctly day-bucketed) cell — rendering each title twice, in two
    /// different text styles. Matching on the month list row's own style
    /// (not just the string) disambiguates a cell's real row from that
    /// unrelated duplicate.
    Finder monthListText(String data) => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == data &&
          (w.style?.fontSize == 9 || w.style?.fontSize == 8),
    );

    /// maxMonthRowHeight clamps the row height down to whatever the
    /// available viewport can fit rowCount rows into — the default test
    /// surface is short enough that a 6-row month wouldn't actually reach
    /// MonthCalendarRowHeight.max even after seeding that value into
    /// SharedPreferences below. A tall, generous viewport keeps that clamp
    /// out of the way so these tests exercise the true max row height.
    void useTallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// Sets up [eventCount] single-day events on one day, seeds the row
    /// height, pumps, and returns which of the events' own titles rendered
    /// (as a Set, order-independent) — the shared setup all three tests
    /// below build on.
    Future<Set<String>> pumpWithEvents(
      WidgetTester tester,
      int eventCount,
    ) async {
      useTallViewport(tester);
      SharedPreferences.setMockInitialValues({
        rowHeightPrefsKey: MonthCalendarRowHeight.max,
      });
      final day = DateTime(2026, 3, 15);
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          for (var i = 0; i < eventCount; i++)
            singleDayEvent(id: 'e$i', day: day),
        ]),
      );

      await pumpMonth(tester, DateTime(2026, 3, 1));

      return {
        for (var i = 0; i < eventCount; i++)
          if (monthListText('e$i').evaluate().isNotEmpty) 'e$i',
      };
    }

    testWidgets(
      'shows an accurate "+1" the moment even a single item is left over '
      '— regression test for two earlier, opposite failures: reserving a '
      'whole row for the hint made "+1" mathematically unreachable '
      '(jumping straight from "+2" to everything shown, revealing 2 at '
      'once instead of 1), and squeezing that one extra item in by '
      'shrinking every row\'s text made "+2" itself disappear too',
      (tester) async {
        // At the max row height, monthEventListCapacity is 5 for a
        // typical column width — 6 events is exactly one more than that.
        final shownTitles = await pumpWithEvents(tester, 6);

        // Every item up to capacity gets its own row now — the hint rides
        // along on the last one instead of costing a row of its own.
        expect(shownTitles, {'e0', 'e1', 'e2', 'e3', 'e4'});
        expect(monthListText('+1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'stays accurate at "+2", not "+3", when two items are genuinely '
      'left over',
      (tester) async {
        final shownTitles = await pumpWithEvents(tester, 7);

        expect(shownTitles, {'e0', 'e1', 'e2', 'e3', 'e4'});
        expect(monthListText('+2'), findsOneWidget);
        expect(monthListText('+3'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

  });
}
