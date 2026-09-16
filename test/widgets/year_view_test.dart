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
import 'package:planfit/features/schedule/presentation/year_view/year_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'year_view_test.mocks.dart';

/// Pins [selectedDateProvider] to a fixed date instead of its own default
/// (today) — same pattern week_view_test.dart's `_FixedSelectedDate` uses,
/// needed here since the page swipe writes to this provider.
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

  Future<ProviderContainer> pumpYear(
    WidgetTester tester,
    DateTime selected, {
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
              home: const Scaffold(body: YearView()),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  group('swiping the grid navigates by whole years', () {
    testWidgets('a left fling advances to next year', (tester) async {
      final selected = DateTime(2026, 3, 15);
      final container = await pumpYear(tester, selected);

      await tester.fling(
        find.byKey(const Key('yearPageSwipe')),
        const Offset(-400, 0),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(selectedDateProvider), DateTime(2027, 3, 15));
    });

    testWidgets('a right fling goes back to the previous year', (tester) async {
      final selected = DateTime(2026, 3, 15);
      final container = await pumpYear(tester, selected);

      await tester.fling(
        find.byKey(const Key('yearPageSwipe')),
        const Offset(400, 0),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(selectedDateProvider), DateTime(2025, 3, 15));
    });

    testWidgets(
      'swiping from Feb 29 of a leap year clamps to Feb 28 in the next '
      '(non-leap) year',
      (tester) async {
        final selected = DateTime(2028, 2, 29);
        final container = await pumpYear(tester, selected);

        await tester.fling(
          find.byKey(const Key('yearPageSwipe')),
          const Offset(-400, 0),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(container.read(selectedDateProvider), DateTime(2029, 2, 28));
      },
    );

    testWidgets('tapping a month still opens month view, not a swipe', (
      tester,
    ) async {
      final selected = DateTime(2026, 3, 15);
      final container = await pumpYear(tester, selected);

      await tester.tap(find.text('3월').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(selectedDateProvider), DateTime(2026, 3, 1));
      expect(container.read(scheduleViewProvider), ScheduleView.month);
    });
  });

  testWidgets('an iPad packs all twelve months into two six-month rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpYear(tester, DateTime(2026, 3, 15));

    final grid = tester.widget<GridView>(
      find.byKey(const Key('yearMonthGrid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 6);
  });

  testWidgets('each mini-month header uses the abbreviated month name in en — '
      'regression test: 12 of these are packed in the adaptive year grid, and a full name '
      'wrapping there could push its own fixed-aspect-ratio grid cell into '
      'a real overflow, not just look cramped', (tester) async {
    final selected = DateTime(2026, 3, 15);
    await pumpYear(tester, selected, locale: const Locale('en'));

    // January — GridView.builder only mounts elements within its own
    // viewport, so a later month (e.g. September, month 9 of 12) isn't
    // guaranteed built without scrolling; the very first cell always is.
    expect(find.text('Jan'), findsOneWidget);
    expect(find.textContaining('January'), findsNothing);
  });

  testWidgets(
    'a multi-day event marks every day it spans, not just its start day — '
    'regression test: counts (feeding each day cell\'s marker) used to be '
    'incremented only at dateOnly(e.startAt), so a 3-day event lit up just '
    'one day of the month grid instead of all 3',
    (tester) async {
      final selected = DateTime(2026, 1, 15);
      final palette = AppTheme.light().extension<AppPalette>()!;
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          EventRow(
            id: 'trip',
            title: 'Trip',
            memo: null,
            location: null,
            startAt: DateTime(2026, 1, 5),
            endAt: DateTime(2026, 1, 8), // exclusive -> Jan 5, 6, 7
            isAllDay: true,
            colorTag: null,
            notify: false,
            reminderMinutesBefore: 0,
            additionalReminderMinutes: null,
            recurrenceRule: null,
            recurrenceGroupId: null,
            osCalendarId: null,
            osEventId: null,
            osLastKnownModified: null,
            syncStatus: SyncStatus.localOnly,
            importSourceCalendarId: null,
            importSourceEventId: null,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ]),
      );

      // January (the grid's first mini-month) is the only one guaranteed
      // mounted without scrolling — see the abbreviated-month-name test
      // above for why.
      await pumpYear(tester, selected);

      // A single event on a day (count == 1) marks it with this exact
      // alpha — see year_view.dart's own (0.30 + count * 0.18) formula.
      final expectedColor = palette.accent.withValues(alpha: 0.48);
      final dots = tester.widgetList<Container>(find.byType(Container)).where((
        c,
      ) {
        final decoration = c.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == expectedColor;
      });
      expect(dots, hasLength(3));
    },
  );
}
