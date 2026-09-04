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
import 'package:planfit/core/lunar/lunar_date.dart';
import 'package:planfit/core/lunar/lunar_format.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/design/tokens/app_colors.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/presentation/week_view/week_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:planfit/l10n/app_localizations_ko.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'week_view_test.mocks.dart';

/// Pins [selectedDateProvider] to a fixed date instead of its own default
/// (today) — same pattern schedule_screen_test.dart's `_FixedSelectedDate`
/// uses, needed here since the page swipe writes to this provider.
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

  EventRow event({
    required String id,
    required DateTime startAt,
    required DateTime endAt,
    bool isAllDay = false,
  }) {
    return EventRow(
      id: id,
      title: id,
      memo: null,
      location: null,
      startAt: startAt,
      endAt: endAt,
      isAllDay: isAllDay,
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
    required DateTime slotStart,
    bool isDone = false,
  }) {
    return TodoRow(
      id: id,
      eventId: null,
      title: id,
      slotStart: slotStart,
      slotEnd: null,
      hasTime: true,
      isDone: isDone,
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
    when(todos.watchOverdue(any)).thenAnswer((_) => Stream.value(const []));
  });

  Future<ProviderContainer> pumpWeek(
    WidgetTester tester,
    DateTime anchor,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(events),
          todoDaoProvider.overrideWithValue(todos),
          selectedDateProvider.overrideWith(() => _FixedSelectedDate(anchor)),
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
              home: Scaffold(body: WeekView(anchor: anchor)),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  testWidgets(
    'a day with only a non-overdue to-do gets a todoAccent header dot',
    (tester) async {
      final anchor = DateTime(2026, 3, 10); // a Tuesday
      final palette = AppTheme.light().extension<AppPalette>()!;
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));
      when(todos.watchBetween(any, any)).thenAnswer(
        (_) =>
            Stream.value([todo(id: 't1', slotStart: DateTime(2026, 3, 11, 9))]),
      );

      await pumpWeek(tester, anchor);

      final dot = tester.widgetList<Container>(find.byType(Container)).where((
        c,
      ) {
        final decoration = c.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == palette.todoAccent;
      });
      expect(dot, isNotEmpty);
    },
  );

  testWidgets('a day with only an event gets an accent header dot', (
    tester,
  ) async {
    final anchor = DateTime(2026, 3, 10);
    final palette = AppTheme.light().extension<AppPalette>()!;
    when(events.watchBetween(any, any)).thenAnswer(
      (_) => Stream.value([
        event(
          id: 'e1',
          startAt: DateTime(2026, 3, 11, 9),
          endAt: DateTime(2026, 3, 11, 10),
        ),
      ]),
    );
    when(
      todos.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const []));

    await pumpWeek(tester, anchor);

    final dot = tester.widgetList<Container>(find.byType(Container)).where((c) {
      final decoration = c.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color == palette.accent;
    });
    expect(dot, isNotEmpty);
  });

  testWidgets(
    'tapping an all-day bar in the strip opens it for editing — regression '
    'test for the strip having no tap target at all, which made a holiday '
    'or all-day event visible but unopenable',
    (tester) async {
      final anchor = DateTime(2026, 3, 10); // a Tuesday
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          event(
            id: 'Holiday',
            startAt: DateTime(2026, 3, 11),
            endAt: DateTime(2026, 3, 12),
            isAllDay: true,
          ),
        ]),
      );
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpWeek(tester, anchor);

      await tester.tap(find.text('Holiday'));
      await tester.pumpAndSettle();

      // showEventEditor for an existing event opens its title pre-filled
      // into the editor's own text field — same assertion day_view_test.dart
      // uses for its own (already-tappable) event cards.
      expect(find.widgetWithText(TextField, 'Holiday'), findsOneWidget);
    },
  );

  testWidgets(
    "a crowded time slot never lets one event card's width overlap "
    "another's — regression test for an earlier attempt at widening "
    'crowded cards that let them overlap each other instead, painting '
    "two different events' titles on top of one another",
    (tester) async {
      final anchor = DateTime(2026, 3, 10);
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          for (var i = 1; i <= 3; i++)
            event(
              id: 'e$i',
              startAt: DateTime(2026, 3, 11, 11),
              endAt: DateTime(2026, 3, 11, 14),
            ),
        ]),
      );
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpWeek(tester, anchor);

      final ranges =
          [
              for (var i = 1; i <= 3; i++)
                tester
                    .widgetList<Positioned>(
                      find.ancestor(
                        of: find.text('e$i'),
                        matching: find.byType(Positioned),
                      ),
                    )
                    .first,
            ]
            .map((p) => (left: p.left!, right: p.left! + p.width!))
            .toList()
          ..sort((a, b) => a.left.compareTo(b.left));

      for (var i = 0; i < ranges.length - 1; i++) {
        expect(
          ranges[i].right,
          lessThanOrEqualTo(ranges[i + 1].left + 0.01),
          reason:
              'card $i (spanning ${ranges[i].left}-${ranges[i].right}) '
              'overlaps the next one (starting at ${ranges[i + 1].left})',
        );
      }
    },
  );

  testWidgets(
    'a short title still renders as exactly one line, whether the event '
    'is crowded or not — each individually-painted line is its own '
    'Text(maxLines: 1, overflow: clip) (see fitLines\' own doc for why), '
    'not a single Text capped at a fixed line count',
    (tester) async {
      final anchor = DateTime(2026, 3, 10);
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          event(
            id: 'C1',
            startAt: DateTime(2026, 3, 11, 11),
            endAt: DateTime(2026, 3, 11, 14),
          ),
          event(
            id: 'C2',
            startAt: DateTime(2026, 3, 11, 11),
            endAt: DateTime(2026, 3, 11, 14),
          ),
          event(
            id: 'A1',
            startAt: DateTime(2026, 3, 12, 9),
            endAt: DateTime(2026, 3, 12, 10),
          ),
        ]),
      );
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpWeek(tester, anchor);

      for (final id in ['C1', 'C2', 'A1']) {
        expect(find.text(id), findsOneWidget);
        expect(tester.widget<Text>(find.text(id)).maxLines, 1);
      }
    },
  );

  testWidgets(
    "a crowded card's title wraps onto more lines the taller its own box "
    'is, rather than being stuck at a fixed cap — the whole point of '
    "computing maxLines from the card's real (duration-based) height "
    'instead of a constant',
    (tester) async {
      final anchor = DateTime(2026, 3, 10);
      // Same length, same (single-repeated-glyph) width per character —
      // only the two events' durations, and so their card heights,
      // differ. Distinct leading letters ('A'.../'B'...) so the two
      // cards' own rendered lines can be told apart below.
      const shortTitle = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      const longTitle = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          // 30 minutes — a short, low box.
          event(
            id: shortTitle,
            startAt: DateTime(2026, 3, 11, 11),
            endAt: DateTime(2026, 3, 11, 11, 30),
          ),
          // 4 hours — a tall box with far more room to keep wrapping.
          // Overlaps the short event above so both get cascaded
          // (columnCount > 1, i.e. the same narrow width as each other).
          event(
            id: longTitle,
            startAt: DateTime(2026, 3, 11, 11),
            endAt: DateTime(2026, 3, 11, 15),
          ),
        ]),
      );
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpWeek(tester, anchor);

      int lineCountFor(String prefix) => tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((data) => data.startsWith(prefix))
          .length;

      final shortLines = lineCountFor('A');
      final longLines = lineCountFor('B');
      expect(shortLines, greaterThanOrEqualTo(1));
      expect(
        longLines,
        greaterThan(shortLines),
        reason:
            'the 4-hour event ($longLines line(s)) should wrap onto more '
            'lines than the 30-minute one ($shortLines line(s)) since its '
            'own card is taller',
      );
    },
  );

  testWidgets(
    "the hour grid's scroll view reserves real clearance below its last "
    "hour — regression test for the floating glass nav bar (which lives "
    'outside this screen\'s own Scaffold, so nothing reserves space for it '
    'automatically) permanently covering the last couple of hours (e.g. '
    '22시+) even at max scroll extent',
    (tester) async {
      final anchor = DateTime(2026, 3, 10);
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpWeek(tester, anchor);

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      final bottomPadding = scrollView.padding?.resolve(TextDirection.ltr).bottom ?? 0;
      expect(
        bottomPadding,
        greaterThanOrEqualTo(100),
        reason:
            'day_view.dart and agenda_view.dart both reserve 140 for the '
            'same floating nav bar — a much smaller value (e.g. '
            'AppSpacing.lg = 24) leaves the last hour(s) hidden behind it',
      );
    },
  );

  testWidgets(
    'the 00시 label skips the upward shift every other hour label gets — '
    "regression test: shifting it too (like every other hour) moved it "
    "above this scroll view's own y=0, which SingleChildScrollView clips "
    'by default, permanently cutting off "오전 12시" at any scroll '
    'position. Giving the scroll view matching top padding instead (an '
    'earlier fix here) is deliberately NOT used — see this test file\'s '
    "own regression test on that for why: it broke the outer list this "
    'grid sits inside on the real Day view',
    (tester) async {
      final anchor = DateTime(2026, 3, 10);
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpWeek(tester, anchor);

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      final topPadding =
          scrollView.padding?.resolve(TextDirection.ltr).top ?? 0;
      expect(
        topPadding,
        0,
        reason:
            'this grid must stay a plain SingleChildScrollView with no '
            "extra content height of its own — see _WeekGrid's hour-label "
            'doc for the fix actually used instead',
      );

      // PageView.builder keeps neighboring weeks' pages alive too, each
      // with their own "오전 12시"/"오전 1시" — .first is this week's own
      // (built first, so first in the tree).
      final midnightShift = tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.text('오전 12시'),
              matching: find.byType(Transform),
            ),
          )
          .first
          .transform;
      expect(
        midnightShift.getTranslation().y,
        0,
        reason: "midnight's own label must not be shifted at all",
      );

      final oneAmShift = tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.text('오전 1시'),
              matching: find.byType(Transform),
            ),
          )
          .first
          .transform;
      expect(
        oneAmShift.getTranslation().y,
        -6,
        reason: 'every other hour keeps its usual -6 shift',
      );
    },
  );

  group(
    'swiping the page (header, strip, or grid) navigates by whole weeks',
    () {
      setUp(() {
        when(
          events.watchBetween(any, any),
        ).thenAnswer((_) => Stream.value(const []));
        when(
          todos.watchBetween(any, any),
        ).thenAnswer((_) => Stream.value(const []));
      });

      testWidgets('a left fling advances to next week', (tester) async {
        final anchor = DateTime(2026, 3, 10);
        final container = await pumpWeek(tester, anchor);

        await tester.fling(
          find.byKey(const Key('weekPageSwipe')),
          const Offset(-400, 0),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(container.read(selectedDateProvider), DateTime(2026, 3, 17));
      });

      testWidgets('a right fling goes back to the previous week', (
        tester,
      ) async {
        final anchor = DateTime(2026, 3, 10);
        final container = await pumpWeek(tester, anchor);

        await tester.fling(
          find.byKey(const Key('weekPageSwipe')),
          const Offset(400, 0),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(container.read(selectedDateProvider), DateTime(2026, 3, 3));
      });

      // The core UX fix this pager exists for: a real PageView, so a slow
      // drag (no meaningful velocity) still pages once it's dragged past
      // roughly half the viewport, and magnet-snaps *back* to the original
      // week if released short of that — not just a binary "did it flick
      // fast enough" jump.
      testWidgets(
        'a slow drag past roughly half the page width still advances a '
        'week, with no meaningful velocity',
        (tester) async {
          final anchor = DateTime(2026, 3, 10);
          final container = await pumpWeek(tester, anchor);

          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const Key('weekPageSwipe'))),
          );
          // Several small, evenly-paced moves totaling well past half of the
          // 800-wide test surface — a decisive total distance but nowhere
          // near a fast flick's velocity.
          for (var i = 0; i < 15; i++) {
            await gesture.moveBy(const Offset(-30, 0));
            await tester.pump(const Duration(milliseconds: 100));
          }
          await gesture.up();
          await tester.pumpAndSettle();

          expect(container.read(selectedDateProvider), DateTime(2026, 3, 17));
        },
      );

      testWidgets(
        'a short drag that never crosses the halfway point snaps back to '
        'the same week',
        (tester) async {
          final anchor = DateTime(2026, 3, 10);
          final container = await pumpWeek(tester, anchor);

          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const Key('weekPageSwipe'))),
          );
          await gesture.moveBy(const Offset(-80, 0));
          await tester.pump(const Duration(milliseconds: 100));
          await gesture.up();
          await tester.pumpAndSettle();

          expect(container.read(selectedDateProvider), anchor);
        },
      );

      testWidgets('tapping a day cell still opens that day, not a swipe', (
        tester,
      ) async {
        final anchor = DateTime(2026, 3, 10); // a Tuesday
        final container = await pumpWeek(tester, anchor);

        // Tuesday's own cell — its date number, "10".
        await tester.tap(find.text('10').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(container.read(selectedDateProvider), DateTime(2026, 3, 10));
        expect(container.read(scheduleViewProvider), ScheduleView.day);
      });

      // The point of wrapping the *whole* page rather than just the header
      // (see _WeekPager's own doc) — a fling starting well below the header,
      // inside the hour grid's own scroll area, still pages the week. Safe
      // because the grid's own gesture there is long-press-to-create (a
      // different recognizer type that only competes once it's already won
      // the arena during its hold phase) plus a vertical scroll (an
      // orthogonal axis) — neither claims a quick horizontal fling.
      testWidgets(
        'a fling starting inside the hour grid, not just the header, also '
        'navigates',
        (tester) async {
          final anchor = DateTime(2026, 3, 10);
          final container = await pumpWeek(tester, anchor);

          await tester.fling(
            find.byType(SingleChildScrollView),
            const Offset(-400, 0),
            1000,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(container.read(selectedDateProvider), DateTime(2026, 3, 17));
        },
      );
    },
  );

  group('lunar date labels', () {
    testWidgets('shown under each day number by default', (tester) async {
      final anchor = DateTime(2026, 3, 10);
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpWeek(tester, anchor);

      final lunar = LunarDate.fromSolar(anchor)!;
      expect(find.text(LunarFmt.compact(AppL10nKo(), lunar)), findsOneWidget);
    });

    testWidgets('hidden when the setting is off', (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings.showLunarDates': false,
      });
      final anchor = DateTime(2026, 3, 10);
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpWeek(tester, anchor);

      final lunar = LunarDate.fromSolar(anchor)!;
      expect(find.text(LunarFmt.compact(AppL10nKo(), lunar)), findsNothing);
    });
  });
}
