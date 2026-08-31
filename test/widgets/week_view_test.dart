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
/// uses, needed here since the header swipe writes to this provider.
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
  }) {
    return EventRow(
      id: id,
      title: id,
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

  group('swiping the header navigates by whole weeks', () {
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
        find.byKey(const Key('weekHeaderSwipe')),
        const Offset(-400, 0),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(selectedDateProvider), DateTime(2026, 3, 17));
    });

    testWidgets('a right fling goes back to the previous week', (tester) async {
      final anchor = DateTime(2026, 3, 10);
      final container = await pumpWeek(tester, anchor);

      await tester.fling(
        find.byKey(const Key('weekHeaderSwipe')),
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
      'a slow drag past roughly half the header width still advances a '
      'week, with no meaningful velocity',
      (tester) async {
        final anchor = DateTime(2026, 3, 10);
        final container = await pumpWeek(tester, anchor);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const Key('weekHeaderSwipe'))),
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
          tester.getCenter(find.byKey(const Key('weekHeaderSwipe'))),
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
  });
}
