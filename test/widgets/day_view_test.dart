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
import 'package:planfit/design/widgets/section_header.dart';
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
    String? importSourceCalendarId,
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
      importSourceCalendarId: importSourceCalendarId,
      importSourceEventId: importSourceCalendarId == null ? null : 'src-1',
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
    // _minEventCardHeight(64) + _locationRowExtraHeight(20) — see those
    // constants' own docs.
    expect(card.height, greaterThanOrEqualTo(84));
  });

  group('back-to-back events (one starting exactly when the previous ends)', () {
    testWidgets(
      'never visually overlap, and a plain 1-hour one renders at exactly '
      'its own true height with no artificial stretch at all',
      (tester) async {
        // Regression test — reported live: a screenshot of 6 consecutive
        // plain 1-hour events showed every boundary looking like an
        // overlap. Each is only 64px tall at this DayView's 64px/hour;
        // back when _minEventCardHeight was 80 (it budgeted room for a
        // resize grip that's since been removed entirely — see that
        // constant's own doc), every one of them got stretched past its
        // own true duration regardless of what followed, painting 16px
        // into the very next event's card despite the two sharing no
        // time at all. Now that the floor (64) matches a plain hour
        // exactly, this case doesn't even need the next-event capping
        // that shorter/crowded/located events still do — asserting the
        // exact height (not just "no overlap") pins that down.
        final day = DateTime(2026, 3, 10);
        final first = row(
          id: 'first',
          title: 'First',
          startAt: DateTime(2026, 3, 10, 9),
          endAt: DateTime(2026, 3, 10, 10),
        );
        final second = row(
          id: 'second',
          title: 'Second',
          startAt: DateTime(2026, 3, 10, 10),
          endAt: DateTime(2026, 3, 10, 11),
        );
        when(
          events.watchBetween(any, any),
        ).thenAnswer((_) => Stream.value([first, second]));

        await pumpDay(tester, day);

        expect(tester.takeException(), isNull);
        Finder cardOf(String title) => find
            .ancestor(
              of: find.text(title),
              matching: find.byType(RepaintBoundary),
            )
            .first;
        final firstRect = tester.getRect(cardOf('First'));
        final secondRect = tester.getRect(cardOf('Second'));
        expect(firstRect.bottom, lessThanOrEqualTo(secondRect.top));
        expect(firstRect.height, 64);
      },
    );

    testWidgets(
      'a card squeezed by the next event still shows its title and time '
      'range, with no overflow even when it also carries a location',
      (tester) async {
        // The tight-mode budget (_tightEventCardHeight) drops the
        // location row but keeps the time-range line — this pins down
        // that a location on the squeezed event doesn't sneak back in
        // and overflow the smaller budget the same way an earlier bug
        // let it overflow the comfortable one (see the "gets enough
        // extra height for its location row" test above).
        final day = DateTime(2026, 3, 10);
        final first = row(
          id: 'first',
          title: 'Coffee with a client',
          startAt: DateTime(2026, 3, 10, 9),
          endAt: DateTime(2026, 3, 10, 10),
          location: '1234 Main St',
        );
        final second = row(
          id: 'second',
          title: 'Next thing',
          startAt: DateTime(2026, 3, 10, 10),
          endAt: DateTime(2026, 3, 10, 11),
        );
        when(
          events.watchBetween(any, any),
        ).thenAnswer((_) => Stream.value([first, second]));

        await pumpDay(tester, day);

        expect(tester.takeException(), isNull);
        expect(find.text('Coffee with a client'), findsOneWidget);
        // The time-range line uses an en dash between start and end
        // regardless of 12h/24h formatting — check for that rather than
        // a specific "09:00"/"9:00 AM" string tied to one format. Both
        // cards show their own time range now, so at least one (not
        // exactly one).
        expect(
          find.byWidgetPredicate(
            (w) => w is Text && (w.data?.contains('–') ?? false),
          ),
          findsAtLeastNWidgets(1),
        );
        // The location row is dropped in tight mode — there's no budget
        // for it once squeezed this far.
        expect(find.text('1234 Main St'), findsNothing);
      },
    );

    testWidgets(
      'a squeezed card in a crowded (side-by-side) column still shows no '
      'overflow even with a title long enough to want 2 lines',
      (tester) async {
        // Regression test for the fix's first attempt: tight mode kept
        // the crowded case's own maxLines: 2 (meant for the *comfortable*
        // budget's extra headroom — _crowdedColumnExtraHeight — which the
        // smaller _tightEventCardHeight budget was never given), and a
        // genuinely 2-line-wrapping title overflowed it by exactly the
        // second line's worth of height. Fixed by pinning tight mode to
        // maxLines: 1 regardless of crowding, rather than trying to also
        // budget _tightEventCardHeight for a 2nd title line.
        final day = DateTime(2026, 3, 10);
        // "first"/"overlap" genuinely overlap (9:00-9:30 and 9:15-10:00),
        // forcing a 2-column crowded layout; "first" then also butts
        // straight up against "next" starting the moment it ends.
        final first = row(
          id: 'first',
          title: 'A genuinely quite long meeting title that wraps twice',
          startAt: DateTime(2026, 3, 10, 9),
          endAt: DateTime(2026, 3, 10, 9, 30),
        );
        final overlap = row(
          id: 'overlap',
          title: 'Overlap',
          startAt: DateTime(2026, 3, 10, 9, 15),
          endAt: DateTime(2026, 3, 10, 10),
        );
        final next = row(
          id: 'next',
          title: 'Next',
          startAt: DateTime(2026, 3, 10, 9, 30),
          endAt: DateTime(2026, 3, 10, 10, 30),
        );
        when(
          events.watchBetween(any, any),
        ).thenAnswer((_) => Stream.value([first, overlap, next]));

        await pumpDay(tester, day);

        expect(tester.takeException(), isNull);
      },
    );
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

  testWidgets(
    'a mirrored event (holiday/subscribed calendar) does not wire up '
    'long-press-drag at all — regression test: it used to, and dragging it '
    'called save() straight from the gesture handler, bypassing the '
    '"mirrored events are read-only" gate that tapping the card already '
    'goes through, and created a duplicate device-calendar event',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      final mirrored = row(
        id: 'holiday1',
        title: 'Chuseok',
        startAt: DateTime(2026, 3, 10, 9),
        endAt: DateTime(2026, 3, 10, 10),
        importSourceCalendarId:
            'ko.south_korea#holiday@group.v.calendar.google.com',
      );
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value([mirrored]));

      await pumpDay(tester, day);

      final detector = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.text('Chuseok'),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(detector.onLongPressStart, isNull);
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

    testWidgets(
      'compact:true renders a small one-line empty state, not the full '
      "icon+hint block — regression test: the full block's own vertical "
      "padding alone could exceed the month grid's entire minimum day-panel "
      'height, pushing the to-dos section below the fold on a day with no '
      'events',
      (tester) async {
        final day = DateTime(2026, 3, 10);
        when(
          events.watchBetween(any, any),
        ).thenAnswer((_) => Stream.value(const []));

        await pumpDay(tester, day, compact: true);
        final l10n = lookupAppL10n(const Locale('ko'));

        expect(find.text(l10n.dayEmpty), findsOneWidget);
        expect(find.text(l10n.dayAddHint), findsNothing);
        expect(find.byIcon(Icons.bedtime_outlined), findsNothing);
      },
    );

    testWidgets(
      'a full (non-compact) DayView keeps the icon+hint empty state',
      (tester) async {
        final day = DateTime(2026, 3, 10);
        when(
          events.watchBetween(any, any),
        ).thenAnswer((_) => Stream.value(const []));

        await pumpDay(tester, day);
        final l10n = lookupAppL10n(const Locale('ko'));

        expect(find.text(l10n.dayEmpty), findsOneWidget);
        expect(find.text(l10n.dayAddHint), findsOneWidget);
        expect(find.byIcon(Icons.bedtime_outlined), findsOneWidget);
      },
    );
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

  testWidgets(
    'the 00시 label skips the upward shift every other hour label gets — '
    "regression test: shifting it too (like every other hour) moved it "
    "above this scroll view's own y=0, which SingleChildScrollView clips "
    'by default, permanently cutting off "오전 12시" at any scroll '
    'position when there are no all-day cards above the timeline to '
    'absorb it',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      // A timed event, not an empty list — an empty day renders _EmptyDay
      // instead of the timeline this test is actually about.
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          row(
            id: 'e1',
            title: 'Anchor',
            startAt: DateTime(2026, 3, 10, 9),
            endAt: DateTime(2026, 3, 10, 10),
          ),
        ]),
      );

      await pumpDay(tester, day);

      // PageView.builder keeps the current page plus its neighbors alive
      // for swiping, so more than one _DayContent(scrollable: true) can
      // exist at once — every one of them needs to stay padding-free.
      final scrollViews = find.byType(SingleChildScrollView);
      expect(scrollViews, findsWidgets);
      for (final element in scrollViews.evaluate()) {
        final scrollView = element.widget as SingleChildScrollView;
        final topPadding =
            scrollView.padding?.resolve(TextDirection.ltr).top ?? 0;
        expect(
          topPadding,
          0,
          reason:
              'this scrollable must stay content-height == viewport-height '
              '(see its own doc for why — giving it any scroll extent of '
              "its own breaks the *outer* list it sits inside, covered by "
              'the next test)',
        );
      }

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
        -7,
        reason: 'every other hour keeps its usual -7 shift',
      );
    },
  );

  testWidgets(
    'a closing "오전 12시" boundary appears below the last hour row — '
    'regression test for the grid visually just stopping at 오후 11시 with '
    'nothing marking where the day actually ends',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      // A timed event, not an empty list — an empty day renders _EmptyDay
      // instead of the timeline this test is actually about.
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          row(
            id: 'e1',
            title: 'Anchor',
            startAt: DateTime(2026, 3, 10, 9),
            endAt: DateTime(2026, 3, 10, 10),
          ),
        ]),
      );

      await pumpDay(tester, day);

      // 64 (hourHeight) * 24 — the boundary sits exactly one hour row below
      // the 23시 row's own top edge, i.e. right at the grid's true bottom.
      final boundary = find.byWidgetPredicate(
        (w) => w is Positioned && w.top == 64.0 * 24,
      );
      expect(boundary, findsWidgets);
      expect(find.text('오전 12시'), findsWidgets);
    },
  );

  testWidgets(
    "dragging the timeline actually scrolls the day into view — "
    'regression test: giving the inner (timeline) SingleChildScrollView '
    'even a few px of its own scroll extent (an earlier, since-reverted '
    "fix for the 00시-label clip above) made it capture the vertical drag "
    "for itself instead of the *outer* list this whole day's content "
    'sits inside, leaving that outer list stuck unscrollable — the '
    "to-dos section below the timeline became permanently unreachable, "
    'not just harder to get to',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      // A timed event, not an empty list — an empty day's much shorter
      // _EmptyDay (280px) fits without the outer list needing to scroll at
      // all, which wouldn't exercise the regression this guards against.
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          row(
            id: 'e1',
            title: 'Anchor',
            startAt: DateTime(2026, 3, 10, 9),
            endAt: DateTime(2026, 3, 10, 10),
          ),
        ]),
      );
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpDay(tester, day);

      // The pager reserves a full 1536px (24 hours) box before the to-dos
      // section even starts, so SectionHeader sits well outside a test
      // surface's default viewport + cache extent — genuinely unmounted,
      // not just scrolled out of view. That's the baseline this test
      // relies on: if the outer list can really scroll, dragging it far
      // enough must bring SectionHeader into the cache extent and mount
      // it; if the outer list is stuck (the regression this guards
      // against), it never will be, no matter how many times this drags.
      expect(find.byType(SectionHeader), findsNothing);

      // A fixed screen coordinate, not a text finder — whatever hour label
      // happens to be there scrolls out (and unmounts) after the first
      // couple of drags, but the coordinate itself stays valid throughout.
      for (var i = 0; i < 6; i++) {
        await tester.dragFrom(const Offset(400, 400), const Offset(0, -600));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byType(SectionHeader),
        findsOneWidget,
        reason:
            "the to-dos section header never scrolled into view — the "
            "outer list is stuck exactly like the regression this guards "
            'against',
      );
    },
  );

  testWidgets(
    "the inline to-do row's checkbox has a tappable area of at least "
    '44x44 — regression test, same fix as the home/todo-list checkboxes '
    'elsewhere in the app',
    (tester) async {
      final day = DateTime(2026, 3, 10);
      final todo = TodoRow(
        id: 't1',
        eventId: null,
        title: 'Buy milk',
        slotStart: day.add(const Duration(hours: 9)),
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
        createdAt: day,
      );
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value([todo]));
      when(events.watchBetween(any, any)).thenAnswer((_) => Stream.value([]));

      await pumpDay(tester, day);

      final hitArea = find.ancestor(
        of: find.byIcon(Icons.radio_button_unchecked),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 44 && w.height == 44,
        ),
      );
      expect(hitArea, findsOneWidget);
      final size = tester.getSize(hitArea);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    },
  );

  testWidgets(
    'an event card has no resize grip at all, on any card — dragging its '
    "bottom edge does nothing; resizing only happens through the editor "
    'sheet now',
    (tester) async {
      // Regression test: an earlier version gave a card a bottom-edge
      // drag grip whenever it had room to show one — which in practice
      // meant only cards *not* immediately followed by another event
      // (most real days are back-to-back, so most cards never had it)
      // — inconsistent enough that it read as a bug in its own right.
      // Removed for every card alike rather than kept conditionally.
      final day = DateTime(2026, 3, 10);
      final e = row(
        id: 'e1',
        title: 'Long event',
        startAt: DateTime(2026, 3, 10, 2),
        endAt: DateTime(2026, 3, 10, 4),
      );
      when(events.watchBetween(any, any)).thenAnswer((_) => Stream.value([e]));

      await pumpDay(tester, day);

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Positioned &&
              w.height == 44 &&
              w.bottom == 0 &&
              w.left == 0 &&
              w.right == 0,
        ),
        findsNothing,
      );
    },
  );
}
