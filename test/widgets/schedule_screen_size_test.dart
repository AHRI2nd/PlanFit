import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/presentation/schedule_screen.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'schedule_screen_test.mocks.dart';

/// Every schedule view, at every window the app can actually be given.
///
/// The month view shipped a layout that only ever fitted a portrait phone:
/// in landscape its timeline collapsed to zero height and the split handle
/// went off the bottom edge, and nothing in the suite noticed because every
/// other widget test runs at flutter_test's one default surface. This is the
/// guard for that whole class of bug — a view that cannot lay itself out in
/// the window it is given fails here rather than on a device.
///
/// The app declares landscape on iPhone and iPad and sets no
/// UIRequiresFullScreen, so all of these are reachable today, without
/// waiting for a foldable.
class _FixedSelectedDate extends SelectedDate {
  _FixedSelectedDate(this._date);
  final DateTime _date;
  @override
  DateTime build() => _date;
}

class _FixedScheduleView extends ScheduleViewMode {
  _FixedScheduleView(this._view);
  final ScheduleView _view;
  @override
  ScheduleView build() => _view;
}

void main() {
  late MockEventRepository events;
  late MockTodoDao todos;

  setUp(() {
    events = MockEventRepository();
    todos = MockTodoDao();
    SharedPreferences.setMockInitialValues({});
    when(
      todos.watchOverdue(any),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
    when(
      todos.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const <TodoRow>[]));
    when(
      events.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const <EventRow>[]));
  });

  Future<void> pumpSchedule(
    WidgetTester tester, {
    required ScheduleView view,
    required DateTime selected,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(events),
          todoDaoProvider.overrideWithValue(todos),
          selectedDateProvider.overrideWith(() => _FixedSelectedDate(selected)),
          scheduleViewProvider.overrideWith(() => _FixedScheduleView(view)),
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
          home: const ScheduleScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Logical sizes, not device names — what matters is the window, and a
  /// split-view or foldable hands out sizes no single device has.
  const windows = <String, Size>{
    // Portrait phone, the size every other widget test implicitly assumes.
    'phone portrait': Size(393, 852),
    // Landscape phone: the shortest windows the app is given, and where the
    // month view used to break. The smallest phone through the largest.
    'small phone landscape': Size(667, 375),
    'phone landscape': Size(852, 393),
    'large phone landscape': Size(932, 430),
    // iPad, both ways up, plus the narrowest multitasking slot.
    'tablet portrait': Size(768, 1024),
    'tablet landscape': Size(1024, 768),
    'slide over': Size(320, 500),
  };

  // August 2026 spans six calendar weeks — the tallest a month grid gets,
  // and the case that failed on every phone in landscape.
  final sixRowMonth = DateTime(2026, 8, 15);

  for (final view in ScheduleView.values) {
    for (final entry in windows.entries) {
      testWidgets('${view.name} lays out in a ${entry.key} window', (
        tester,
      ) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpSchedule(tester, view: view, selected: sixRowMonth);

        expect(
          tester.takeException(),
          isNull,
          reason: '${view.name} overflowed at ${entry.value}',
        );
      });
    }
  }

  testWidgets(
    'wide month view keeps the calendar pane free of duplicated day content',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpSchedule(
        tester,
        view: ScheduleView.month,
        selected: sixRowMonth,
      );

      final month = tester.widget<MonthView>(find.byType(MonthView));
      expect(month.calendarOnly, isTrue);
      expect(find.text('이 날은 아직 비어 있어요'), findsOneWidget);
    },
  );

  for (final view in ScheduleView.values) {
    testWidgets('${view.name} survives a rotation with no rebuild from '
        'scratch', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpSchedule(tester, view: view, selected: sixRowMonth);

      // A rotation is a resize of the live tree, not a fresh pump — the
      // month view's own layout-mode switch happens on exactly this path.
      tester.view.physicalSize = const Size(852, 393);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'rotating into it');

      tester.view.physicalSize = const Size(393, 852);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'and back out again');
    });
  }
}
