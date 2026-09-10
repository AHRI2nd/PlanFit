import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/clock.dart';
import 'package:planfit/core/date_math.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/todo_dao.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/design/tokens/app_colors.dart';
import 'package:planfit/features/home/presentation/home_screen.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen_test.mocks.dart';

@GenerateMocks([EventRepository, TodoDao])
void main() {
  late MockEventRepository events;
  late MockTodoDao todos;

  setUp(() async {
    events = MockEventRepository();
    todos = MockTodoDao();
    SharedPreferences.setMockInitialValues({});

    // HomeScreen's empty-state cards only need these to resolve — every
    // watch* the screen (and its _WeeklyStats/_TodayTodos children) can
    // reach gets a default empty stream so a test can override just the
    // one it cares about.
    when(
      events.watchUpcoming(any, limit: anyNamed('limit')),
    ).thenAnswer((_) => Stream.value(const <EventRow>[]));
    when(
      events.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const <EventRow>[]));
    when(
      todos.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    TextScaler? textScaler,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(events),
          todoDaoProvider.overrideWithValue(todos),
          if (now != null)
            nowTickerProvider.overrideWith((_) => Stream.value(now)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          // Pinned so the test doesn't depend on the host machine's locale.
          locale: const Locale('ko'),
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          // Matches app.dart's own 1.0-1.3x accessibility clamp when a test
          // asks for it, instead of the tester's default 1.0.
          builder: textScaler == null
              ? null
              : (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                  child: child!,
                ),
          home: const HomeScreen(),
        ),
      ),
    );
    // Time-driven pieces (the clock, the weekly bar's entrance animation)
    // never settle on their own — a couple of frames is enough for the
    // empty-state cards to build.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows every empty state when there is no data', (tester) async {
    await pumpHome(tester);

    // The merged today feed (events + to-dos) shows one empty state now,
    // not the two separate ones the old _UpcomingList/_TodayTodos cards had.
    expect(find.text('오늘은 예정된 일정도, 할 일도 없어요'), findsOneWidget);
    expect(find.text('이번 주는 아직 조용하네요'), findsOneWidget);
  });

  testWidgets('renders an upcoming event\'s title once data arrives', (
    tester,
  ) async {
    final now = DateTime.now();
    final event = EventRow(
      id: 'e1',
      title: 'Team sync',
      memo: null,
      startAt: now.add(const Duration(hours: 1)),
      endAt: now.add(const Duration(hours: 2)),
      isAllDay: false,
      notify: true,
      reminderMinutesBefore: 0,
      colorTag: null,
      recurrenceRule: null,
      recurrenceGroupId: null,
      osCalendarId: null,
      osEventId: null,
      osLastKnownModified: null,
      syncStatus: SyncStatus.pendingPush,
      createdAt: now,
      updatedAt: now,
    );
    when(
      events.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value([event]));

    await pumpHome(tester);

    expect(find.text('Team sync'), findsOneWidget);
    expect(find.text('오늘은 예정된 일정도, 할 일도 없어요'), findsNothing);
  });

  testWidgets('tapping an upcoming event tile opens the read-only preview, and '
      'long-pressing it skips straight to the editor', (tester) async {
    final now = DateTime.now();
    final event = EventRow(
      id: 'e1',
      title: 'Team sync',
      memo: null,
      startAt: now.add(const Duration(hours: 1)),
      endAt: now.add(const Duration(hours: 2)),
      isAllDay: false,
      notify: true,
      reminderMinutesBefore: 0,
      colorTag: null,
      recurrenceRule: null,
      recurrenceGroupId: null,
      osCalendarId: null,
      osEventId: null,
      osLastKnownModified: null,
      syncStatus: SyncStatus.pendingPush,
      createdAt: now,
      updatedAt: now,
    );
    when(
      events.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value([event]));

    await pumpHome(tester);

    await tester.tap(find.text('Team sync'));
    await tester.pumpAndSettle();
    expect(find.text('편집하기'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Team sync'), findsNothing);
    Navigator.of(tester.element(find.text('편집하기'))).pop();
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Team sync'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Team sync'), findsOneWidget);
    expect(find.text('편집하기'), findsNothing);
  });

  testWidgets(
    "an event days away no longer leaks into the 오늘 card — the bug this "
    "regression guards against: the card used to watch upcomingEventsProvider "
    "(next N events from now, no date ceiling), so a quiet day could pull in "
    "something 24 days out and label it 오늘 right next to its own honest "
    "'N일 뒤' relative-time badge",
    (tester) async {
      final now = DateTime.now();
      final farEvent = EventRow(
        id: 'e2',
        title: 'Chuseok Holiday',
        memo: null,
        startAt: now.add(const Duration(days: 24)),
        endAt: now.add(const Duration(days: 24, hours: 1)),
        isAllDay: false,
        notify: false,
        reminderMinutesBefore: 0,
        colorTag: null,
        recurrenceRule: null,
        recurrenceGroupId: null,
        osCalendarId: null,
        osEventId: null,
        osLastKnownModified: null,
        syncStatus: SyncStatus.pendingPush,
        createdAt: now,
        updatedAt: now,
      );
      // Still reachable via watchUpcoming (a different provider, used by the
      // OS home-screen widget and the schedule-tab badge — neither of those
      // makes a "today" claim) but must NOT show up on the 오늘 card, which
      // only ever watches watchBetween(today, tomorrow).
      when(
        events.watchUpcoming(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => Stream.value([farEvent]));

      await pumpHome(tester);

      expect(find.text('Chuseok Holiday'), findsNothing);
      expect(find.text('오늘은 예정된 일정도, 할 일도 없어요'), findsOneWidget);
    },
  );

  testWidgets(
    'an event whose end time has passed reads 종료됨, not 진행 중 — regression '
    'test: editing a still-"진행 중" event\'s end time to somewhere in the '
    'past (a normal correction, not just something that eventually happens '
    'on its own) used to keep the card claiming it was still running, since '
    'the relative-time label only ever looked at the start time',
    (tester) async {
      final now = DateTime(2026, 3, 10, 15);
      final endedEvent = EventRow(
        id: 'e3',
        title: 'Morning standup',
        memo: null,
        startAt: now.subtract(const Duration(hours: 2)),
        endAt: now.subtract(const Duration(minutes: 30)),
        isAllDay: false,
        notify: false,
        reminderMinutesBefore: 0,
        colorTag: null,
        recurrenceRule: null,
        recurrenceGroupId: null,
        osCalendarId: null,
        osEventId: null,
        osLastKnownModified: null,
        syncStatus: SyncStatus.pendingPush,
        createdAt: now,
        updatedAt: now,
      );
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value([endedEvent]));

      await pumpHome(tester, now: now);

      expect(find.text('Morning standup'), findsOneWidget);
      expect(find.text('종료됨'), findsOneWidget);
      expect(find.text('진행 중'), findsNothing);
    },
  );

  testWidgets(
    "renders today's to-do title once data arrives, interleaved with events",
    (tester) async {
      final today = DateTime(2026, 3, 10);
      final todo = TodoRow(
        id: 't1',
        eventId: null,
        title: 'Buy milk',
        slotStart: today.add(const Duration(hours: 9)),
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
        createdAt: today,
      );
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value([todo]));

      await pumpHome(tester);

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('오늘은 예정된 일정도, 할 일도 없어요'), findsNothing);
    },
  );

  testWidgets("the today card's to-do checkbox has a tappable area of at least "
      '44x44 — regression test for a hit box that used to be a 22px icon '
      'plus 4px of padding (~30x30), under the accessibility floor', (
    tester,
  ) async {
    final today = DateTime(2026, 3, 10);
    final todo = TodoRow(
      id: 't1',
      eventId: null,
      title: 'Buy milk',
      slotStart: today.add(const Duration(hours: 9)),
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
      createdAt: today,
    );
    when(todos.watchBetween(any, any)).thenAnswer((_) => Stream.value([todo]));

    await pumpHome(tester);

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
  });

  testWidgets("the weekly stats bar's done/total label fits its own box at the "
      "app's 1.3x accessibility text-scale ceiling — regression test: that "
      'box was a fixed 12px SizedBox around labelSmall/fontSize:9 text, '
      'which needs only ~10.8px at the default 1.0x scale but ~14px at '
      "1.3x — 2px taller than the box. Being a plain SizedBox (not a Flex) "
      "meant this never threw a catchable overflow error; the label's true "
      'layout just silently painted outside its box and overlapped the '
      'weekday abbreviation directly below it', (tester) async {
    final today = DateTime.now();
    final todo = TodoRow(
      id: 't1',
      eventId: null,
      title: 'Buy milk',
      slotStart: today,
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
      createdAt: today,
    );
    when(todos.watchBetween(any, any)).thenAnswer((_) => Stream.value([todo]));

    await pumpHome(tester, textScaler: const TextScaler.linear(1.3));

    final labelFinder = find.text('0/1');
    expect(labelFinder, findsOneWidget);
    final boxFinder = find
        .ancestor(of: labelFinder, matching: find.byType(SizedBox))
        .first;
    final boxHeight = tester.getSize(boxFinder).height;

    final labelWidget = tester.widget<Text>(labelFinder);
    final naturalHeight = (TextPainter(
      text: TextSpan(text: '0/1', style: labelWidget.style),
      textDirection: TextDirection.ltr,
      textScaler: const TextScaler.linear(1.3),
    )..layout()).height;

    expect(
      boxHeight,
      greaterThanOrEqualTo(naturalHeight),
      reason:
          "the label's own box (${boxHeight}px) must be at least as "
          'tall as the text actually needs at this scale '
          '(${naturalHeight}px), or it paints outside the box and '
          'overlaps the weekday label below',
    );
  });

  testWidgets(
    "the week bar gets an accent dot on every day a multi-day event spans, "
    "not just its start day — regression test: it used to be keyed by a "
    "bare dateOnly(e.startAt), so a 3-day trip only lit up the bar's first "
    "day even though the event genuinely covered all 3",
    (tester) async {
      // A fixed Wednesday — weekStartsMonday defaults to true, so this
      // week's Monday is 2026-03-09.
      final now = DateTime(2026, 3, 11);
      final weekStart = startOfWeek(now, startWeekday: DateTime.monday);
      final palette = AppTheme.light().extension<AppPalette>()!;
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          EventRow(
            id: 'trip',
            title: 'Trip',
            memo: null,
            startAt: addCalendarDays(weekStart, 1), // Tuesday
            endAt: addCalendarDays(weekStart, 4), // exclusive -> Fri
            isAllDay: true,
            notify: false,
            reminderMinutesBefore: 0,
            colorTag: null,
            recurrenceRule: null,
            recurrenceGroupId: null,
            osCalendarId: null,
            osEventId: null,
            osLastKnownModified: null,
            syncStatus: SyncStatus.pendingPush,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      await pumpHome(tester, now: now);

      final dots = tester.widgetList<Container>(find.byType(Container)).where((
        c,
      ) {
        final decoration = c.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == palette.accent;
      });
      // Tue, Wed, Thu — endAt (Fri) is exclusive.
      expect(dots, hasLength(3));
    },
  );

  testWidgets('the bottom of the home screen has an always-visible inline "할 일 '
      '추가" field — home never had an add affordance of its own before, and '
      'this matches the day/week views\' own inline-field convention rather '
      'than a FAB opening a modal sheet (that "+" is the schedule tab\'s own, '
      'for adding an event)', (tester) async {
    await pumpHome(tester);

    expect(find.text('할 일 추가'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets(
    'submitting a title in that inline field creates the to-do and clears '
    'the field in place — there\'s no sheet here to close',
    (tester) async {
      when(todos.findById(any)).thenAnswer((_) async => null);
      when(todos.upsert(any)).thenAnswer((_) async {});

      await pumpHome(tester);
      await tester.enterText(find.byType(TextField), 'Buy milk');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final captured =
          verify(todos.upsert(captureAny)).captured.single
              as TodoItemsCompanion;
      expect(captured.title.value, 'Buy milk');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );
}
