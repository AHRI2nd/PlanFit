import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/date_math.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/todo_dao.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/design/tokens/event_color_tag.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'month_view_test.mocks.dart';

/// Pins [selectedDateProvider] to a fixed, safely-mid-month date instead of
/// its own default (today) — MonthView also embeds a `compact` [DayView]
/// for whichever day is selected, and today's own date drifts as the suite
/// runs on different days, risking a multi-day event's span crossing a
/// month boundary depending on when in the month the test happens to run.
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

  EventRow multiDayEvent({
    required String id,
    required DateTime startAt,
    required DateTime endAt,
    required String colorTag,
  }) {
    return EventRow(
      id: id,
      title: id,
      memo: null,
      location: null,
      startAt: startAt,
      endAt: endAt,
      isAllDay: true,
      colorTag: colorTag,
      notify: false,
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
    when(todos.watchOverdue(any)).thenAnswer((_) => Stream.value(const []));
    when(
      todos.watchBetween(any, any),
    ).thenAnswer((_) => Stream.value(const []));
  });

  Future<void> pumpMonth(WidgetTester tester, DateTime selected) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(events),
          todoDaoProvider.overrideWithValue(todos),
          selectedDateProvider.overrideWith(() => _FixedSelectedDate(selected)),
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
          home: const Scaffold(body: MonthView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets(
    'a multi-day all-day event renders its own colorTag as a bar across the '
    'days it spans',
    (tester) async {
      final eventStart = DateTime(2026, 3, 10);
      // A different day than the event's own start/span, same month — the
      // selected day's own marker renders white for contrast (see
      // month_view.dart's `isSelected ? Colors.white : color`), which would
      // otherwise swallow one of the 3 expected colored bars if the
      // selected day and the event's start coincided.
      final selectedDay = DateTime(2026, 3, 20);
      const tag = '#3388CC';
      when(events.watchBetween(any, any)).thenAnswer(
        (_) => Stream.value([
          multiDayEvent(
            id: 'trip',
            startAt: eventStart,
            endAt: addCalendarDays(eventStart, 3),
            colorTag: tag,
          ),
        ]),
      );

      await pumpMonth(tester, selectedDay);

      final expectedColor = EventColorTag.resolve(tag, eventStart);
      // The month grid's own bar Container (height: 4, per month_view.dart)
      // — filtered on that exact height too, not just color, since the
      // selected day's embedded compact DayView renders this same event's
      // color again on its own 3×30 accent strip, which would otherwise
      // false-positive-match on color alone.
      final bars = tester.widgetList<Container>(find.byType(Container)).where((
        c,
      ) {
        final decoration = c.decoration;
        return decoration is BoxDecoration &&
            decoration.color == expectedColor &&
            c.constraints?.maxHeight == 4;
      });

      // One bar per day cell the 3-day event actually spans.
      expect(bars, hasLength(3));
    },
  );
}
