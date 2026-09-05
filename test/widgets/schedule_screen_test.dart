import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/presentation/schedule_screen.dart';
import 'package:planfit/features/schedule/presentation/week_view/week_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:planfit/l10n/app_localizations_ko.dart';
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
    Locale locale = const Locale('ko'),
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
              locale: locale,
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

  group('title chevrons navigate selectedDateProvider', () {
    // Regression tests for the chevrons being IgnorePointer'd hint-only
    // decoration — a user tapping directly on ‹ / › (rather than dragging
    // the title) got no response at all.
    testWidgets('day view: tapping › advances by 1 day', (tester) async {
      final selected = DateTime(2026, 3, 10);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.day,
        selected: selected,
      );
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(container.read(selectedDateProvider), DateTime(2026, 3, 11));
    });

    testWidgets('day view: tapping ‹ goes back 1 day', (tester) async {
      final selected = DateTime(2026, 3, 10);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.day,
        selected: selected,
      );
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(container.read(selectedDateProvider), DateTime(2026, 3, 9));
    });

    testWidgets('month view: tapping › advances by 1 month', (tester) async {
      final selected = DateTime(2026, 3, 15);
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.month,
        selected: selected,
      );
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(container.read(selectedDateProvider), DateTime(2026, 4, 15));
    });

    testWidgets(
      'agenda view: no chevrons render at all — no period to page',
      (tester) async {
        final selected = DateTime(2026, 3, 15);
        await pumpSchedule(tester, view: ScheduleView.agenda, selected: selected);
        expect(find.byIcon(Icons.chevron_left), findsNothing);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
      },
    );

    testWidgets(
      "agenda view: the missing chevrons leave behind a 44x44 invisible "
      "spacer each, not a gap — regression test: this title row's own "
      'height is whichever of the title text and the chevrons\' 44x44 '
      "footprint is taller; agenda's title text is shorter than 44px "
      '(every non-day title is, not just agenda\'s), so simply omitting '
      "the chevrons from the Row (rather than replacing them with a "
      "same-size invisible box) shrank *this tab's* title row alone, "
      'visibly bumping the view-switcher pills right below it up by '
      'several px only when agenda was selected — confirmed live on '
      'an Android emulator before being fixed here',
      (tester) async {
        final selected = DateTime(2026, 3, 15);
        await pumpSchedule(tester, view: ScheduleView.agenda, selected: selected);

        final spacers = find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 44 && w.height == 44,
        );
        expect(spacers, findsNWidgets(2));
      },
    );

    testWidgets(
      'both chevrons carry a screen-reader label — regression test: '
      'neither had a tooltip or Semantics at all, so a VoiceOver/TalkBack '
      'user tapping through the header heard nothing meaningful for the '
      'only tap-based way to page the calendar',
      (tester) async {
        final handle = tester.ensureSemantics();
        final selected = DateTime(2026, 3, 10);
        await pumpSchedule(tester, view: ScheduleView.day, selected: selected);

        // Literal Korean strings, not the l10n getters themselves — this
        // harness pumps Locale('ko') (see its own MaterialApp setup), so
        // asserting against the real resolved text is what actually proves
        // a screen reader would announce something meaningful, not just
        // that some string was passed through.
        expect(find.bySemanticsLabel('이전으로'), findsOneWidget);
        expect(find.bySemanticsLabel('다음으로'), findsOneWidget);

        handle.dispose();
      },
    );

    testWidgets(
      'both chevrons have a tappable area of at least 44x44 — regression '
      'test for a hit box that used to measure only ~30x30 (an 18px icon '
      'plus 6px of padding), well under the ~44x44 accessibility floor '
      'Apple HIG / Material both recommend for a comfortable tap target',
      (tester) async {
        final selected = DateTime(2026, 3, 10);
        await pumpSchedule(tester, view: ScheduleView.day, selected: selected);

        for (final icon in [Icons.chevron_left, Icons.chevron_right]) {
          // The 44x44 SizedBox that pads out _TitleChevron's tap target —
          // matched specifically (not just any SizedBox) since the icon
          // sits under plenty of unrelated ones elsewhere in the tree.
          final hitArea = find.ancestor(
            of: find.byIcon(icon),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.width == 44 && w.height == 44,
            ),
          );
          expect(hitArea, findsOneWidget, reason: '$icon');
          final size = tester.getSize(hitArea);
          expect(
            size.width,
            greaterThanOrEqualTo(44),
            reason: '$icon tap width',
          );
          expect(
            size.height,
            greaterThanOrEqualTo(44),
            reason: '$icon tap height',
          );
        }
      },
    );
  });

  group('body-region swipes', () {
    // _EventCard's own swipe-to-delete was removed (deleting now lives in
    // the edit sheet) specifically so this area could become a navigation
    // surface instead — swiping it now behaves the same as the title.
    testWidgets(
      'day view: swiping an event card navigates the day, same as the '
      'title (it no longer deletes)',
      (tester) async {
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
        await tester.pump(const Duration(milliseconds: 50));

        expect(container.read(selectedDateProvider), DateTime(2026, 3, 11));
        verifyNever(events.delete(any));
      },
    );

    // The one remaining safety boundary: to-dos still keep their own
    // swipe-to-delete (a real Dismissible, unlike events' now-removed
    // hand-rolled one) undisturbed by the day-navigation swipe around it.
    testWidgets('day view: swiping a to-do still only triggers its own delete '
        'gesture, never date navigation', (tester) async {
      final selected = DateTime(2026, 3, 10);
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const []));
      when(todos.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          TodoRow(
            id: 't1',
            eventId: null,
            title: 'Swipe target todo',
            slotStart: DateTime(2026, 3, 10, 9, 0),
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
          ),
        ]),
      );
      final container = await pumpSchedule(
        tester,
        view: ScheduleView.day,
        selected: selected,
      );

      await tester.ensureVisible(find.text('Swipe target todo'));
      await tester.pump();
      await tester.fling(
        find.text('Swipe target todo'),
        const Offset(-400, 0),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(selectedDateProvider), selected);
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

  group('the title\'s lunar subtitle', () {
    testWidgets('shows under the title on day view', (tester) async {
      final selected = DateTime(2026, 3, 10);
      await pumpSchedule(tester, view: ScheduleView.day, selected: selected);

      final lunar = LunarDate.fromSolar(selected)!;
      expect(find.text(LunarFmt.short(AppL10nKo(), lunar)), findsOneWidget);
    });

    testWidgets('is absent on week/month/year/agenda — those titles are a '
        'period, not a single day', (tester) async {
      final selected = DateTime(2026, 3, 10);
      final lunar = LunarDate.fromSolar(selected)!;
      final label = LunarFmt.short(AppL10nKo(), lunar);

      for (final view in [
        ScheduleView.week,
        ScheduleView.month,
        ScheduleView.year,
        ScheduleView.agenda,
      ]) {
        await pumpSchedule(tester, view: view, selected: selected);
        expect(find.text(label), findsNothing, reason: '$view');
      }
    });

    testWidgets('hidden on day view when the setting is off', (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings.showLunarDates': false,
      });
      final selected = DateTime(2026, 3, 10);
      await pumpSchedule(tester, view: ScheduleView.day, selected: selected);

      final lunar = LunarDate.fromSolar(selected)!;
      expect(find.text(LunarFmt.short(AppL10nKo(), lunar)), findsNothing);
    });
  });

  group('the title and view switcher stay legible in every locale', () {
    testWidgets(
      "the week view's title uses abbreviated month names in en — "
      'regression test: the full names ("August 31 – September 6") '
      'overflowed the swipeable title\'s own tight header, ellipsizing '
      'mid-word ("August 31 – Septe…")',
      (tester) async {
        // A Monday-start week fully inside August/September, so the
        // expected range is unambiguous regardless of the week-start
        // setting.
        final selected = DateTime(2026, 8, 31);
        await pumpSchedule(
          tester,
          view: ScheduleView.week,
          selected: selected,
          locale: const Locale('en'),
        );

        expect(find.text('Aug 31 – Sep 6'), findsOneWidget);
        expect(find.textContaining('August'), findsNothing);
      },
    );

    testWidgets(
      "the month view's title uses the abbreviated month in en — "
      'regression test: this sits in the same header the week-range '
      'title above overflowed in, and the full "September 2026" is long '
      'enough to risk the same thing',
      (tester) async {
        final selected = DateTime(2026, 9, 4);
        await pumpSchedule(
          tester,
          view: ScheduleView.month,
          selected: selected,
          locale: const Locale('en'),
        );

        expect(find.text('Sep 2026'), findsOneWidget);
        expect(find.textContaining('September'), findsNothing);
      },
    );

    testWidgets(
      'the view-switcher labels (일/주/월/년/목록) are never forced onto a '
      'single line — regression test: they used to carry maxLines: 1 + '
      'overflow: ellipsis + softWrap: false, which truncated en\'s '
      '"Month"/"Agenda" (real words here, not single ko/ja characters) '
      "to \"Mont…\"/\"Agend…\" in this 5-way pill's own tighter-than-"
      "settings_screen.dart's-3-way-rows budget",
      (tester) async {
        final selected = DateTime(2026, 3, 10);
        await pumpSchedule(
          tester,
          view: ScheduleView.day,
          selected: selected,
          locale: const Locale('en'),
        );

        for (final label in ['Day', 'Week', 'Month', 'Year', 'Agenda']) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, isNull, reason: label);
          expect(
            text.overflow,
            isNot(TextOverflow.ellipsis),
            reason: label,
          );
        }
      },
    );

    testWidgets(
      "the title (and day view's lunar subtitle) never truncates on a "
      'realistic narrow phone width, in any locale — regression test: '
      "every test above pumps at flutter_test's own default surface size "
      '(much wider than a real phone), which is exactly why none of them '
      'caught this: Fmt.fullDate/monthDayShort\'s already-abbreviated '
      'output still overflowed to "…" on an actual ~360dp-wide device in '
      '*every* locale checked here, not just the specific en/ja cases '
      'those abbreviations were originally tuned for. Fixed by wrapping '
      "the title/subtitle in FittedBox(fit: scaleDown) instead of relying "
      'on ever-shorter formats staying ahead of every device width.',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780) * 3.0;
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final locale in [const Locale('ko'), const Locale('en')]) {
          for (final view in [
            ScheduleView.day,
            ScheduleView.week,
            ScheduleView.month,
          ]) {
            await pumpSchedule(
              tester,
              view: view,
              selected: DateTime(2026, 9, 5),
              locale: locale,
            );

            final titleTexts = find.descendant(
              of: find.byKey(const Key('scheduleTitleSwipe')),
              matching: find.byType(Text),
            );
            expect(
              titleTexts,
              findsWidgets,
              reason: '$view/$locale should render at least a title',
            );
            for (final element in titleTexts.evaluate()) {
              final renderParagraph =
                  element.renderObject! as RenderParagraph;
              expect(
                renderParagraph.didExceedMaxLines,
                isFalse,
                reason:
                    '$view/$locale: '
                    '"${(element.widget as Text).data}" truncated',
              );
            }
          }
        }
      },
    );
  });
}
