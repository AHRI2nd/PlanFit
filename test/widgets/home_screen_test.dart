import 'package:drift/drift.dart' show Value;
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
import 'package:planfit/design/glass/glass_nav_bar.dart';
import 'package:planfit/features/home/presentation/home_screen.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/domain/ports.dart';
import 'package:planfit/features/todo/domain/todo_priority.dart';
import 'package:planfit/features/todo/presentation/quick_add_todo_sheet.dart';
import 'package:planfit/features/todo/presentation/todo_smart_list_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen_test.mocks.dart';

@GenerateMocks([EventRepository, TodoDao, NotificationPort, RemindersPort])
void main() {
  late MockEventRepository events;
  late MockTodoDao todos;
  late MockNotificationPort notifications;
  late MockRemindersPort reminders;

  setUp(() async {
    events = MockEventRepository();
    todos = MockTodoDao();
    notifications = MockNotificationPort();
    reminders = MockRemindersPort();
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
    when(
      todos.watchOverdue(any),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
    when(
      todos.watchUpcomingNotOverdue(any, limit: anyNamed('limit')),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
    when(notifications.cancelForTodo(any)).thenAnswer((_) async {});
    when(reminders.deleteTodo(any)).thenAnswer((_) async {});
    when(reminders.isEnabled).thenReturn(false);
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
          notificationPortProvider.overrideWithValue(notifications),
          remindersPortProvider.overrideWithValue(reminders),
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

  /// Drags the pull-up bar (collapsed by default) fully open — enough
  /// distance that, combined with the sheet's own snap:true, it always
  /// settles at its max size rather than somewhere in between. Dragged from
  /// the "할 일 추가" header specifically: with two ListViews on screen now
  /// (the background one behind the sheet, and the sheet's own), that
  /// header is a point guaranteed to be inside just the sheet, at any size.
  Future<void> expandTodoSheet(WidgetTester tester) async {
    await tester.drag(find.text('할 일 추가'), const Offset(0, -600));
    await tester.pumpAndSettle();
  }

  testWidgets('shows every empty state when there is no data', (tester) async {
    await pumpHome(tester);

    // The merged today feed (events + to-dos) shows one empty state now,
    // not the two separate ones the old _UpcomingList/_TodayTodos cards had.
    expect(find.text('오늘은 예정된 일정도, 할 일도 없어요'), findsOneWidget);
    expect(find.text('이번 주는 아직 조용하네요'), findsOneWidget);

    // 할 일 only shows once the pull-up bar is dragged open.
    await expandTodoSheet(tester);
    expect(find.text('처리할 할 일이 없어요'), findsOneWidget);
  });

  testWidgets(
    "the sheet's own scroll view reaches its bottom edge, so what sits "
    "behind the floating nav bar is real content for the bar's blur to "
    'soften — regression test: this screen once wrapped the list in a '
    '`Column[Expanded(list), SizedBox(navBarClearance)]` to keep '
    'the 할 일 section clear of the bar. That strip sits inside the '
    "sheet's own opaque surface fill, so the bar's backdrop blur had "
    'nothing behind it but a flat slab of that colour (reported from a '
    'real device as "the bar is a solid block, not glass"), and '
    "Expanded's own bottom edge hard-clipped the list mid-glyph right "
    'above it. Only the home tab had that structure, which is exactly '
    'why only the home tab showed it',
    (tester) async {
      await pumpHome(tester);
      await tester.pumpAndSettle();

      final surface = find.byKey(const ValueKey('homeTodoSheetSurface'));
      final sheetList = find.descendant(
        of: surface,
        matching: find.byType(ListView),
      );
      expect(
        tester.getBottomLeft(sheetList).dy,
        moreOrLessEquals(tester.getBottomLeft(surface).dy, epsilon: 1),
      );

      // And the gap the user actually sees between the add field and the
      // 할 일 list, once there's room to see both, is a normal small
      // spacing constant — not a nav-bar-sized one leaking into the
      // middle of the content, which is what the spacer before that
      // Column did.
      await expandTodoSheet(tester);
      final addFieldBottom = tester.getBottomLeft(find.byIcon(Icons.tune)).dy;
      final sectionTitle = find.text('할 일');
      final sectionTop = tester.getTopLeft(sectionTitle).dy;
      // Comparing against the clearance itself rather than a literal: the
      // bug put a whole nav-bar-sized spacer here, so re-introducing it
      // would push this gap past the clearance on its own.
      expect(
        sectionTop - addFieldBottom,
        lessThan(navBarClearance(tester.element(sectionTitle))),
      );
    },
  );

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
    // 이번 주 sits below the fold at this text scale — scroll the
    // background list (there are two ListViews on screen now: this one,
    // and the pull-up bar's own; .first is the background one, since it's
    // the first Stack child built).
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pump();

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
      // A fixed Wednesday. The event is placed by absolute date (Tue–Thu),
      // so this only needs a stable anchor — whichever weekday the bar
      // starts on, Tue/Wed/Thu all fall inside that same week.
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

  testWidgets(
    'the inline field carries the same time / priority / repeat controls the '
    'day view\'s own add field has — the tune toggle reveals a priority menu '
    'and a repeat menu, and a picked priority reaches the new to-do',
    (tester) async {
      when(todos.findById(any)).thenAnswer((_) async => null);
      when(todos.upsert(any)).thenAnswer((_) async {});

      await pumpHome(tester);

      // Collapsed by default — priority/repeat live behind the tune toggle.
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();
      // TodoPriority.high — the last entry in the menu.
      await tester.tap(find.text('높음').last);
      await tester.pumpAndSettle();

      // Title field is the first TextField; the expanded panel's tags
      // field is the second.
      await tester.enterText(find.byType(TextField).first, 'Taxes');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final captured =
          verify(todos.upsert(captureAny)).captured.single
              as TodoItemsCompanion;
      expect(captured.priority.value, greaterThan(0));
    },
  );

  testWidgets(
    "the tune button grows the pull-up bar itself by the details panel's "
    'own height, and shrinks it back by the same amount when tapped again '
    "— the panel used to just grow inside a sheet that didn't move, "
    'clipping/scrolling instead of the two animating together',
    (tester) async {
      await pumpHome(tester);

      final surface = find.byKey(const ValueKey('homeTodoSheetSurface'));
      final collapsedHeight = tester.getSize(surface).height;

      await tester.tap(find.byIcon(Icons.tune));
      // The sheet's own animateTo and the field's AnimatedSize both run on
      // a 180ms timer — settle both before measuring.
      await tester.pumpAndSettle();

      final expandedHeight = tester.getSize(surface).height;
      expect(expandedHeight, greaterThan(collapsedHeight));

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();

      final recollapsedHeight = tester.getSize(surface).height;
      expect(recollapsedHeight, moreOrLessEquals(collapsedHeight, epsilon: 1));
    },
  );

  testWidgets(
    'toggling the tune button while the bar is already dragged all the way '
    'up to browse 할 일 leaves it there — regression test: it used to force '
    'the whole bar back down to the tune-driven collapsed size, fighting '
    "the user's own drag, whichever way the toggle went",
    (tester) async {
      await pumpHome(tester);
      await expandTodoSheet(tester);

      final surface = find.byKey(const ValueKey('homeTodoSheetSurface'));
      final fullyOpenHeight = tester.getSize(surface).height;

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(surface).height,
        moreOrLessEquals(fullyOpenHeight, epsilon: 1),
      );

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(surface).height,
        moreOrLessEquals(fullyOpenHeight, epsilon: 1),
      );
    },
  );

  testWidgets(
    'a firm drag down with the tune options panel open stops at the '
    "options-open height and leaves the panel open — the sheet's floor is "
    'raised by exactly the panel\'s own height while it is open, because '
    "the panel renders inside the sheet's own scroll view: let the sheet "
    'shrink to its options-closed height and the panel ends up below the '
    "sheet's bottom edge, behind the floating tab bar (the original bug). "
    'An earlier fix instead force-closed the panel to let the sheet keep '
    'shrinking, which threw away the state the user had just opened',
    (tester) async {
      await pumpHome(tester);

      final surface = find.byKey(const ValueKey('homeTodoSheetSurface'));
      final collapsedHeight = tester.getSize(surface).height;

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      final optionsOpenHeight = tester.getSize(surface).height;
      expect(optionsOpenHeight, greaterThan(collapsedHeight));
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

      // A firm drag down on the header — more than enough to have driven
      // the sheet to its options-closed floor, were that still the floor.
      await tester.drag(find.text('할 일 추가'), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(surface).height,
        moreOrLessEquals(optionsOpenHeight, epsilon: 1),
      );
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

      // And the floor drops back once the panel is closed by its own
      // toggle — the only thing that should ever close it.
      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(surface).height,
        moreOrLessEquals(collapsedHeight, epsilon: 1),
      );
    },
  );

  testWidgets(
    'a re-measure that happens while the tune options panel is open does '
    "not corrupt the bar's own collapsed height — the root cause behind a "
    'whole family of wrong sheet heights. The collapsed height used to be '
    'read off the *live* bar, which is exactly the widget whose height the '
    'panel changes, so any re-measure taken while the panel was open '
    'recorded peek+panel as the plain peek height. didChangeMetrics fires '
    'on every keyboard show/hide and the tags field that raises the '
    "keyboard lives inside that very panel, so this was the normal case, "
    'not a corner one: from then on the sheet floor sat a whole '
    "panel-height too tall and the toggle had nothing left to grow by",
    (tester) async {
      await pumpHome(tester);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final surface = find.byKey(const ValueKey('homeTodoSheetSurface'));
      final collapsedHeight = tester.getSize(surface).height;

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      final optionsOpenHeight = tester.getSize(surface).height;
      expect(optionsOpenHeight, greaterThan(collapsedHeight));

      // Same text scale as before — this is here purely to fire the
      // re-measure, standing in for the keyboard appearing over the tags
      // field inside the open panel.
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      await tester.pumpAndSettle();

      // The re-measure alone must not move a sheet nobody dragged.
      expect(
        tester.getSize(surface).height,
        moreOrLessEquals(optionsOpenHeight, epsilon: 1),
      );

      // And the heights it recorded must still be the real ones: closing
      // the panel returns the bar to exactly where it started.
      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(surface).height,
        moreOrLessEquals(collapsedHeight, epsilon: 1),
      );
    },
  );

  testWidgets(
    'a short drag down on the collapsed bar with the tune options panel '
    "open settles back at the options-open height instead of collapsing — "
    'regression test: with only the collapsed and fully-expanded sizes as '
    "snap targets, DraggableScrollableSheet's own snap-to-nearest had "
    'nowhere else to resolve a drag from the (in-between) options-open '
    'height *to* — any drag, however small, had to land on whichever '
    'extreme it was closer to, which from there was almost always the '
    'collapsed floor. Confirmed on a real device as casual/undecided '
    'scrolling with the panel open fully collapsing the bar and closing '
    'the panel with it. Giving the options-open height its own place in '
    "the sheet's snapSizes gives a short drag somewhere to resolve back "
    'to besides the two extremes',
    (tester) async {
      await pumpHome(tester);

      final surface = find.byKey(const ValueKey('homeTodoSheetSurface'));
      final collapsedHeight = tester.getSize(surface).height;

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      final expandedHeight = tester.getSize(surface).height;
      expect(expandedHeight, greaterThan(collapsedHeight));
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

      // A short, gentle nudge down — nowhere near the collapsed floor.
      await tester.drag(find.text('할 일 추가'), const Offset(0, 30));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(surface).height,
        moreOrLessEquals(expandedHeight, epsilon: 1),
      );
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'a short, slow drag down that springs back to full expansion instead '
    "of actually collapsing doesn't close the tune options panel — "
    'regression test: an earlier fix reacted the moment the sheet\'s live '
    'size dipped any amount below its own peak, which happens on every '
    "frame of a drag regardless of where it ends up. DraggableScrollableSheet"
    " only has two snap targets (collapsed and fully expanded), so a short/"
    'slow drag from the fully-expanded, options-open state can still '
    "resolve back to full expansion via the sheet's own snap-to-nearest — "
    'but the live dip during that drag was already enough to close the '
    'panel, leaving a fully-expanded bar with no panel in it even though '
    "the sheet never actually collapsed",
    (tester) async {
      await pumpHome(tester);
      await expandTodoSheet(tester);

      final surface = find.byKey(const ValueKey('homeTodoSheetSurface'));
      final fullyOpenHeight = tester.getSize(surface).height;

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

      // A short, gentle nudge down — nowhere near enough to cross toward
      // the collapsed floor — that should spring straight back to full
      // expansion rather than collapsing.
      await tester.drag(find.text('할 일 추가'), const Offset(0, 30));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(surface).height,
        moreOrLessEquals(fullyOpenHeight, epsilon: 1),
      );
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'a runtime text-scale change re-measures the pull-up bar instead of '
    'keeping its stale collapsed height — a rotation or an accessibility '
    'text-size change used to leave the sheet at its old size until the '
    'screen was rebuilt from scratch',
    (tester) async {
      await pumpHome(tester);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final surface = find.byKey(const ValueKey('homeTodoSheetSurface'));
      final baselineHeight = tester.getSize(surface).height;

      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      await tester.pumpAndSettle();

      final rescaledHeight = tester.getSize(surface).height;
      expect(rescaledHeight, greaterThan(baselineHeight));
    },
  );

  testWidgets(
    "a spurious didChangeMetrics mid-drag (nothing about the peek content's "
    "own size actually changed) doesn't fight the user's own drag — "
    'regression test: iOS fires didChangeMetrics several times in a row '
    'around app launch and other unrelated moments as safe-area/keyboard '
    'insets settle, with the same size measured every time; re-measuring '
    'unconditionally still called setState on every one of those, handing '
    'DraggableScrollableSheet a freshly-recomputed (if numerically '
    'identical) minChildSize/initialChildSize mid-gesture, which reset the '
    'sheet back toward its collapsed size out from under an in-progress '
    'drag',
    (tester) async {
      await pumpHome(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('할 일 추가')),
      );
      // A burst of no-op metrics pings interleaved with every step of the
      // drag — the peek content's measured size never actually changes —
      // mirroring how densely iOS was observed firing didChangeMetrics
      // around a single continuous touch, not just once.
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -75));
        tester.binding.handleMetricsChanged();
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final surface = find.byKey(const ValueKey('homeTodoSheetSurface'));
      final screenHeight = tester.getSize(find.byType(HomeScreen)).height;
      // Dragged up ~600 logical pixels total from its collapsed state —
      // well past collapsed, whatever collapsed's own exact height is.
      expect(tester.getSize(surface).height, greaterThan(screenHeight * 0.5));
    },
  );

  testWidgets(
    'the date and time chips default to the nearest upcoming top of the '
    "hour when nothing's been picked — no more hard-coded 9am",
    (tester) async {
      await pumpHome(tester);

      final field = find.byType(QuickAddTodoField);
      final ctx = tester.element(field);
      final now = DateTime.now();
      final nextHour = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
      ).add(const Duration(hours: 1));

      // Time chip: exactly the next top of the hour.
      final expectedTime = TimeOfDay(
        hour: nextHour.hour,
        minute: 0,
      ).format(ctx);
      expect(
        find.descendant(of: field, matching: find.text(expectedTime)),
        findsOneWidget,
      );

      // Date chip: 오늘 (or 내일 if that next hour already rolled past
      // midnight) — never a hard-coded absolute date.
      final expectedDate = nextHour.day == now.day ? '오늘' : '내일';
      expect(
        find.descendant(of: field, matching: find.text(expectedDate)),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping the date chip opens a date picker', (tester) async {
    await pumpHome(tester);

    final field = find.byType(QuickAddTodoField);
    final chip = find.descendant(
      of: field,
      matching: find.byWidgetPredicate(
        (w) => w is Text && (w.data == '오늘' || w.data == '내일'),
      ),
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets(
    'the expanded panel has a tags field, and what\'s typed there lands on '
    'the new to-do alongside any "#tag" phrase in the title',
    (tester) async {
      when(todos.findById(any)).thenAnswer((_) async => null);
      when(todos.upsert(any)).thenAnswer((_) async {});

      await pumpHome(tester);
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Two fields now: [0] title, [1] tags.
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).at(1), '업무, 급함');
      await tester.enterText(find.byType(TextField).first, '보고서 #분기');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final captured =
          verify(todos.upsert(captureAny)).captured.single
              as TodoItemsCompanion;
      expect(captured.tags.value, '분기,업무,급함');
      expect(captured.title.value, '보고서');
    },
  );

  group("the home screen's own to-do list (below the add field)", () {
    TodoRow todo({
      required String id,
      required String title,
      required DateTime slotStart,
      int priority = 0,
      String? tags,
      String? recurrenceGroupId,
    }) {
      return TodoRow(
        id: id,
        eventId: null,
        title: title,
        slotStart: slotStart,
        slotEnd: null,
        hasTime: true,
        isDone: false,
        sortOrder: 0,
        priority: priority,
        tags: tags,
        notify: false,
        isPinned: false,
        recurrenceRule: null,
        recurrenceGroupId: recurrenceGroupId,
        reminderSyncStatus: SyncStatus.pendingPush,
        createdAt: slotStart,
      );
    }

    testWidgets(
      'places every overdue-and-not-done to-do above the upcoming ones — '
      'oldest overdue first, then soonest-upcoming first — regardless of '
      "watchOverdue's own most-recently-overdue-first order (that order "
      "suits the smart list's 기한 지남 tab, its other caller, not this one)",
      (tester) async {
        final now = DateTime(2026, 3, 10, 12);
        final oldOverdue = todo(
          id: 'overdue-old',
          title: 'Old overdue',
          slotStart: now.subtract(const Duration(days: 5)),
        );
        final recentOverdue = todo(
          id: 'overdue-recent',
          title: 'Recent overdue',
          slotStart: now.subtract(const Duration(hours: 1)),
        );
        final soonUpcoming = todo(
          id: 'upcoming-soon',
          title: 'Soon',
          slotStart: now.add(const Duration(hours: 2)),
        );
        final laterUpcoming = todo(
          id: 'upcoming-later',
          title: 'Later',
          slotStart: now.add(const Duration(days: 3)),
        );
        // Handed to the mock in watchOverdue's own real order (most recent
        // first) — the widget under test is the one responsible for
        // reversing it, not a lucky pass-through.
        when(
          todos.watchOverdue(any),
        ).thenAnswer((_) => Stream.value([recentOverdue, oldOverdue]));
        when(
          todos.watchUpcomingNotOverdue(any, limit: anyNamed('limit')),
        ).thenAnswer((_) => Stream.value([soonUpcoming, laterUpcoming]));

        await pumpHome(tester, now: now);
        await expandTodoSheet(tester);

        double topOf(String title) => tester.getTopLeft(find.text(title)).dy;

        expect(topOf('Old overdue'), lessThan(topOf('Recent overdue')));
        expect(topOf('Recent overdue'), lessThan(topOf('Soon')));
        expect(topOf('Soon'), lessThan(topOf('Later')));
      },
    );

    testWidgets(
      'shows an overdue to-do in red/bold regardless of how many days ago '
      'it was due, and shows its date (not just a time) since this list, '
      "unlike _TodayFeed above it, isn't scoped to today",
      (tester) async {
        final now = DateTime(2026, 3, 10, 12);
        final oldOverdue = todo(
          id: 'overdue-old',
          title: 'Old overdue',
          slotStart: DateTime(2026, 3, 1, 9),
        );
        when(
          todos.watchOverdue(any),
        ).thenAnswer((_) => Stream.value([oldOverdue]));

        await pumpHome(tester, now: now);
        await expandTodoSheet(tester);

        expect(find.text('Old overdue'), findsOneWidget);
        expect(find.textContaining('3월 1일'), findsOneWidget);
      },
    );

    testWidgets('tapping a to-do in this list opens its detail sheet', (
      tester,
    ) async {
      final now = DateTime(2026, 3, 10, 12);
      final soonUpcoming = todo(
        id: 'upcoming-soon',
        title: 'Soon',
        slotStart: now.add(const Duration(hours: 2)),
      );
      when(
        todos.watchUpcomingNotOverdue(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => Stream.value([soonUpcoming]));
      when(
        todos.findById('upcoming-soon'),
      ).thenAnswer((_) async => soonUpcoming);
      when(
        todos.watchSubtasks('upcoming-soon'),
      ).thenAnswer((_) => Stream.value(const []));

      await pumpHome(tester, now: now);
      await expandTodoSheet(tester);

      await tester.tap(find.text('Soon'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Soon'), findsOneWidget);
    });

    testWidgets('shows a priority dot and tags — this list used to drop both '
        'entirely, so setting either never showed up anywhere on the home '
        'screen', (tester) async {
      final now = DateTime(2026, 3, 10, 12);
      final important = todo(
        id: 'upcoming-important',
        title: 'Renew passport',
        slotStart: now.add(const Duration(hours: 2)),
        priority: TodoPriority.high.value,
        tags: '여권,긴급',
      );
      when(
        todos.watchUpcomingNotOverdue(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => Stream.value([important]));

      await pumpHome(tester, now: now);
      await expandTodoSheet(tester);

      expect(find.text('Renew passport'), findsOneWidget);
      expect(find.text('여권 · 긴급'), findsOneWidget);
      final dot = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 8 &&
            w.constraints?.maxHeight == 8,
      );
      expect(dot, findsOneWidget);
    });

    group('swipe-to-delete', () {
      // Regression coverage: this list used to have no way to delete a
      // to-do at all — the tile was a plain GestureDetector with no
      // Dismissible.
      late TodoRow soon;

      setUp(() {
        final now = DateTime(2026, 3, 10, 12);
        soon = todo(
          id: 'upcoming-soon',
          title: 'Soon',
          slotStart: now.add(const Duration(hours: 2)),
        );
        when(
          todos.watchUpcomingNotOverdue(any, limit: anyNamed('limit')),
        ).thenAnswer((_) => Stream.value([soon]));
        when(todos.findById(any)).thenAnswer((_) async => soon);
        when(
          todos.watchSubtasks(any),
        ).thenAnswer((_) => Stream.value(const []));
        when(todos.deleteById(any)).thenAnswer((_) async {});
      });

      testWidgets('swiping a one-off to-do deletes it immediately, no dialog', (
        tester,
      ) async {
        final now = DateTime(2026, 3, 10, 12);
        await pumpHome(tester, now: now);
        await expandTodoSheet(tester);

        await tester.drag(find.text('Soon'), const Offset(-500, 0));
        await tester.pumpAndSettle();

        expect(find.text('반복 할 일 삭제'), findsNothing);
        verify(todos.deleteById('upcoming-soon')).called(1);
        // showAutoDismissSnackBar arms its own real Timer — let it fire
        // before the test tears down (see snackbar_x.dart).
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('swiping a recurring to-do asks this-only vs this-and-future '
          'before deleting', (tester) async {
        final now = DateTime(2026, 3, 10, 12);
        soon = soon.copyWith(recurrenceGroupId: const Value('series-1'));
        when(
          todos.watchUpcomingNotOverdue(any, limit: anyNamed('limit')),
        ).thenAnswer((_) => Stream.value([soon]));
        when(
          todos.seriesFrom(any, any),
        ).thenAnswer((_) => Future.value([soon]));

        await pumpHome(tester, now: now);
        await expandTodoSheet(tester);

        await tester.drag(find.text('Soon'), const Offset(-500, 0));
        await tester.pumpAndSettle();

        expect(find.text('이 항목만 삭제'), findsOneWidget);
        await tester.tap(find.text('이 항목만 삭제'));
        await tester.pumpAndSettle();

        verify(todos.deleteById('upcoming-soon')).called(1);
        verifyNever(todos.seriesFrom(any, any));
        await tester.pump(const Duration(seconds: 5));
      });
    });

    testWidgets(
      'a large overdue backlog renders only the first 50 tiles, with a '
      "link to the rest instead — the underlying query stays uncapped (for "
      "the badge/dots elsewhere), but this list has no lazy ListView.builder "
      "under it, so rendering everything inline doesn't scale",
      (tester) async {
        final now = DateTime(2026, 3, 10, 12);
        // watchOverdue's own order is most-recently-overdue-first —
        // reproduced here so the reversal to oldest-first in the widget
        // under test doesn't accidentally line up by coincidence.
        final overdue = [
          for (var i = 55; i >= 1; i--)
            todo(
              id: 'overdue-$i',
              title: 'Overdue $i',
              slotStart: DateTime(2026, 3, i.clamp(1, 9)),
            ),
        ];
        when(todos.watchOverdue(any)).thenAnswer((_) => Stream.value(overdue));

        await pumpHome(tester, now: now);
        await expandTodoSheet(tester);

        expect(find.byType(Dismissible), findsNWidgets(50));
        final moreLink = find.text('5건 더 있음 — 스마트 리스트에서 보기');
        expect(moreLink, findsOneWidget);

        await tester.ensureVisible(moreLink);
        await tester.pumpAndSettle();
        await tester.tap(moreLink);
        await tester.pumpAndSettle();

        final smartList = tester.widget<TodoSmartListScreen>(
          find.byType(TodoSmartListScreen),
        );
        expect(smartList.initialTab, SmartListInitialTab.overdue);
      },
    );
  });
}
