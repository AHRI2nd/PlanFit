import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/todo_dao.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
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
    DateTime selected,
  ) async {
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
              locale: const Locale('ko'),
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
}
