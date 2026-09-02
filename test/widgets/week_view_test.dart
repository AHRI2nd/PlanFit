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
import 'package:planfit/design/tokens/app_colors.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/presentation/week_view/week_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
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
    'a crowded event card caps its title to one line, but an uncrowded '
    "one still gets two — a crowded card's own narrow width was found to "
    'silently drop a 2nd wrapped line entirely rather than paint it '
    '(confirmed live on device: layout metrics reported two lines, only '
    'the first one actually rendered, no ellipsis either) — capping to '
    'one line there sidesteps that renderer-level issue rather than '
    'triggering it',
    (tester) async {
      final anchor = DateTime(2026, 3, 10);
      // Short (1-2 char) titles so fitOneLine (see the crowded card's own
      // comment) never actually needs to truncate either one — this test
      // is about the maxLines each card picks, not fitOneLine's own
      // truncation, which week_fit_one_line_test.dart covers directly.
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

      expect(tester.widget<Text>(find.text('C1')).maxLines, 1);
      expect(tester.widget<Text>(find.text('C2')).maxLines, 1);
      expect(tester.widget<Text>(find.text('A1')).maxLines, 2);
    },
  );

  testWidgets(
    'a crowded event card whose title needs more than one line renders a '
    'real second line instead of silently dropping it — regression test '
    "for Text(maxLines: 2)'s own layout reporting two wrapped lines but "
    'only ever painting the first one at a cascaded card\'s narrow width',
    (tester) async {
      final anchor = DateTime(2026, 3, 10);
      // Long enough that no cascaded (2-way) slice of the day column can
      // fit it on one line, whatever the exact test viewport width is.
      const longTitle = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          event(
            id: longTitle,
            startAt: DateTime(2026, 3, 11, 11),
            endAt: DateTime(2026, 3, 11, 14),
          ),
          event(
            id: 'Y2',
            startAt: DateTime(2026, 3, 11, 11),
            endAt: DateTime(2026, 3, 11, 14),
          ),
        ]),
      );
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpWeek(tester, anchor);

      final xLines = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((data) => data.startsWith('X'))
          .toList();

      expect(
        xLines.length,
        2,
        reason:
            'expected the title to wrap into exactly two rendered lines, '
            'got: $xLines',
      );
      expect(xLines[0], isNot(xLines[1]));
      expect(xLines[1], isNotEmpty);
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
}
