import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/schedule/domain/event_input.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/presentation/event_edit/quick_add_sheet.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quick_add_event_sheet_test.mocks.dart';

@GenerateMocks([EventRepository])
void main() {
  late MockEventRepository events;

  setUp(() {
    events = MockEventRepository();
    SharedPreferences.setMockInitialValues({});
    when(events.save(any)).thenAnswer((invocation) async {
      final input = invocation.positionalArguments.single as EventInput;
      return EventRow(
        id: input.id,
        title: input.title,
        memo: input.memo,
        location: input.location,
        startAt: input.startAt,
        endAt: input.endAt,
        isAllDay: input.isAllDay,
        colorTag: input.colorTag,
        notify: input.notify,
        reminderMinutesBefore: input.reminderMinutesBefore,
        additionalReminderMinutes: null,
        recurrenceRule: null,
        recurrenceGroupId: null,
        osCalendarId: null,
        osEventId: null,
        osLastKnownModified: null,
        syncStatus: SyncStatus.localOnly,
        importSourceCalendarId: null,
        importSourceEventId: null,
        createdAt: input.startAt,
        updatedAt: input.startAt,
      );
    });
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(events),
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
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showQuickAddEvent(
                    context,
                    anchorDay: DateTime(2026, 10, 2),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('preview interprets date and time and defaults to 09:00', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(find.byType(TextField), '팀 회의');
    await tester.pump();

    expect(
      find.byKey(const Key('quick-add-event-default-time')),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '12월 25일 오후 3시 팀 회의');
    await tester.pump();

    final preview = tester.widget<Text>(
      find.byKey(const Key('quick-add-event-preview')),
    );
    expect(preview.data, contains('12월 25일'));
    expect(preview.data, contains('오후 3'));
    expect(preview.data, contains('오후 4'));
    expect(find.byKey(const Key('quick-add-event-default-time')), findsNothing);
  });

  testWidgets('overnight preview shows the end date on the following day', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(find.byType(TextField), '12월 25일 오후 11시 팀 회의');
    await tester.pump();

    final preview = tester.widget<Text>(
      find.byKey(const Key('quick-add-event-preview')),
    );
    expect(preview.data, contains('12월 25일'));
    expect(preview.data, contains('12월 26일'));
  });

  testWidgets('date-only and time-only phrases keep the other default', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), '12월 25일 팀 회의');
    await tester.pump();
    var preview = tester.widget<Text>(
      find.byKey(const Key('quick-add-event-preview')),
    );
    expect(preview.data, contains('12월 25일'));
    expect(
      find.byKey(const Key('quick-add-event-default-time')),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '오후 3시 팀 회의');
    await tester.pump();
    preview = tester.widget<Text>(
      find.byKey(const Key('quick-add-event-preview')),
    );
    expect(preview.data, contains('10월 2일'));
    expect(preview.data, contains('오후 3'));
    expect(find.byKey(const Key('quick-add-event-default-time')), findsNothing);
  });

  testWidgets('saved event start matches the date and time shown in preview', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(find.byType(TextField), '12월 25일 오후 3시 팀 회의');
    await tester.pump();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final captured =
        verify(events.save(captureAny)).captured.single as EventInput;
    expect(captured.title, '팀 회의');
    expect(captured.startAt.month, 12);
    expect(captured.startAt.day, 25);
    expect(captured.startAt.hour, 15);
    expect(captured.startAt.minute, 0);
    expect(captured.endAt, captured.startAt.add(const Duration(hours: 1)));
    await tester.pump(const Duration(seconds: 5));
  });
}
