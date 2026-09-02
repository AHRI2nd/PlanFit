import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/event_template_dao.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/schedule/domain/event_input.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/domain/recurrence.dart';
import 'package:planfit/features/schedule/presentation/event_edit/event_editor_sheet.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'event_editor_sheet_test.mocks.dart';

// Not covered: showDatePicker/showAppTimePicker (date & time rows) and the
// flutter_colorpicker dialog (custom color swatch) — real native/plugin
// dialogs that are fragile to drive under flutter test.
@GenerateMocks([EventRepository, EventTemplateDao])
void main() {
  late MockEventRepository repo;
  late MockEventTemplateDao templateDao;

  setUp(() {
    repo = MockEventRepository();
    templateDao = MockEventTemplateDao();
    SharedPreferences.setMockInitialValues({});

    when(
      templateDao.watchAll(),
    ).thenAnswer((_) => Stream.value(const <EventTemplateRow>[]));
    when(repo.save(any)).thenAnswer(
      (_) async => row(
        id: 'saved',
        title: 'saved',
        startAt: DateTime(2020),
        endAt: DateTime(2020),
      ),
    );
    when(repo.saveSeriesFrom(any, any)).thenAnswer((_) async {});
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    EventRow? existing,
    EventRow? duplicateFrom,
    DateTime? initialDay,
    DateTime? initialStart,
    DateTime? initialEnd,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepositoryProvider.overrideWithValue(repo),
          eventTemplateDaoProvider.overrideWithValue(templateDao),
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
          home: EventEditorSheet(
            existing: existing,
            duplicateFrom: duplicateFrom,
            initialDay: initialDay,
            initialStart: initialStart,
            initialEnd: initialEnd,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Switch notifySwitch(WidgetTester tester) => tester.widget<Switch>(
    find.descendant(
      of: find.byKey(const ValueKey('row-notify')),
      matching: find.byType(Switch),
    ),
  );

  testWidgets('empty title shows an error and never saves', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text('저장'));
    await tester.pump();

    expect(find.text('제목을 입력해주세요'), findsOneWidget);
    verifyNever(repo.save(any));
  });

  testWidgets(
    'save trims the title and blanks out whitespace-only memo/location',
    (tester) async {
      await pumpEditor(tester);

      await tester.enterText(find.byType(TextField).at(0), '  Team sync  ');
      await tester.enterText(find.byType(TextField).at(1), '   ');
      await tester.enterText(find.byType(TextField).at(2), '  Room 2  ');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      final input = verify(repo.save(captureAny)).captured.single as EventInput;
      expect(input.title, 'Team sync');
      expect(input.memo, isNull);
      expect(input.location, 'Room 2');
    },
  );

  testWidgets('toggling all-day normalizes start/end to day boundaries', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      initialStart: DateTime(2026, 3, 10, 14, 30),
      initialEnd: DateTime(2026, 3, 10, 15, 30),
    );

    await tester.enterText(find.byType(TextField).at(0), 'All day event');
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final input = verify(repo.save(captureAny)).captured.single as EventInput;
    expect(input.isAllDay, isTrue);
    expect(input.startAt, DateTime(2026, 3, 10));
    expect(input.endAt, DateTime(2026, 3, 11));
  });

  testWidgets(
    'creating a new recurring event saves with the picked frequency',
    (tester) async {
      await pumpEditor(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Standup');
      // The repeat chips sit below the ListView's initial viewport now that
      // the 기본 section has its own header + card padding above them —
      // scroll incrementally until the target chip itself is on-screen and
      // clear of anything overlapping it, rather than guessing one drag
      // distance that happens to land exactly right.
      await tester.dragUntilVisible(
        find.text('매월'),
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      // Monthly, not daily: the default 365-day recurrence window stays under
      // RecurrenceExpansion.maxOccurrences at a monthly cadence, so no
      // truncation snackbar (and its auto-dismiss timer) gets scheduled.
      await tester.tap(find.text('매월'), warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      final input = verify(repo.save(captureAny)).captured.single as EventInput;
      expect(input.recurrenceFrequency, RecurrenceFrequency.monthly);
      verifyNever(repo.saveSeriesFrom(any, any));
    },
  );

  testWidgets(
    'saving an occurrence of a recurring series and choosing "apply to future" '
    'calls saveSeriesFrom instead of save',
    (tester) async {
      final existing = row(
        id: 'e1',
        title: 'Existing',
        startAt: DateTime(2026, 3, 10, 9),
        endAt: DateTime(2026, 3, 10, 10),
        recurrenceGroupId: 'g1',
      );
      await pumpEditor(tester, existing: existing);

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      expect(find.text('이 일정만 저장'), findsOneWidget);
      expect(find.text('이후 모든 반복에 적용'), findsOneWidget);

      await tester.tap(find.text('이후 모든 반복에 적용'));
      await tester.pumpAndSettle();

      verify(repo.saveSeriesFrom('e1', any)).called(1);
      verifyNever(repo.save(any));
    },
  );

  testWidgets(
    'saving an occurrence of a recurring series and choosing "this only" '
    'calls save instead of saveSeriesFrom',
    (tester) async {
      final existing = row(
        id: 'e1',
        title: 'Existing',
        startAt: DateTime(2026, 3, 10, 9),
        endAt: DateTime(2026, 3, 10, 10),
        recurrenceGroupId: 'g1',
      );
      await pumpEditor(tester, existing: existing);

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이 일정만 저장'));
      await tester.pumpAndSettle();

      verify(repo.save(any)).called(1);
      verifyNever(repo.saveSeriesFrom(any, any));
    },
  );

  testWidgets("duplicateFrom pre-fills the new event's title and memo", (
    tester,
  ) async {
    final source = row(
      id: 'src',
      title: 'Original title',
      memo: 'Original memo',
      startAt: DateTime(2026, 3, 10, 9),
      endAt: DateTime(2026, 3, 10, 10),
    );
    await pumpEditor(tester, duplicateFrom: source);

    expect(find.text('Original title'), findsOneWidget);
    expect(find.text('Original memo'), findsOneWidget);
    // duplicateFrom always creates a fresh event, so the sheet opens as new.
    expect(find.text('새 일정'), findsOneWidget);
  });

  testWidgets('editing an existing event pre-fills its fields', (tester) async {
    final existing = row(
      id: 'e2',
      title: 'Existing title',
      memo: 'Existing memo',
      location: 'Existing location',
      startAt: DateTime(2026, 3, 10),
      endAt: DateTime(2026, 3, 11),
      isAllDay: true,
      notify: false,
    );
    await pumpEditor(tester, existing: existing);

    expect(find.text('Existing title'), findsOneWidget);
    expect(find.text('Existing memo'), findsOneWidget);
    expect(find.text('Existing location'), findsOneWidget);
    expect(find.text('일정 편집'), findsOneWidget);

    final allDay = tester.widget<Switch>(find.byType(Switch).first);
    expect(allDay.value, isTrue);

    // The 알림 card sits below the ListView's initial viewport — scroll it
    // into reach before it's even mounted for find() to see.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    expect(notifySwitch(tester).value, isFalse);
  });

  testWidgets(
    'turning off notify and picking a color preset both carry through to '
    'the saved input',
    (tester) async {
      // Editing an existing (non-recurring) event, not a new one — the
      // recurrence picker only shows for new events and pushes the notify
      // row below the fold of the ListView's non-lazy-but-still-viewport-
      // clipped children, out of tap reach without extra scrolling.
      final existing = row(
        id: 'e3',
        title: 'Color test',
        startAt: DateTime(2026, 3, 10, 9),
        endAt: DateTime(2026, 3, 10, 10),
      );
      await pumpEditor(tester, existing: existing);

      // The 알림 card sits below the ListView's initial viewport now that
      // the 기본/일시 cards above it carry their own headers and padding —
      // scroll it into reach before it's even mounted for find()/tap() to
      // see.
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('row-notify')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pump();
      expect(notifySwitch(tester).value, isFalse);

      // The color row sits further below still — drag it into reach before
      // the semantics tree can even see the swatch.
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      final semantics = tester.ensureSemantics();
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('amber'));
      await tester.pump();
      semantics.dispose();

      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      final input = verify(repo.save(captureAny)).captured.single as EventInput;
      expect(input.notify, isFalse);
      expect(input.colorTag, 'amber');
    },
  );

  testWidgets('tapping the start date opens only the date picker', (
    tester,
  ) async {
    final existing = row(
      id: 'e4',
      title: 'Date tap test',
      startAt: DateTime(2026, 3, 10, 9),
      endAt: DateTime(2026, 3, 10, 10),
    );
    await pumpEditor(tester, existing: existing);

    await tester.tap(find.byKey(const ValueKey('date-start')));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.byType(TimePickerDialog), findsNothing);
  });

  testWidgets('tapping the start time opens only the time picker', (
    tester,
  ) async {
    final existing = row(
      id: 'e5',
      title: 'Time tap test',
      startAt: DateTime(2026, 3, 10, 9),
      endAt: DateTime(2026, 3, 10, 10),
    );
    await pumpEditor(tester, existing: existing);

    await tester.tap(find.byKey(const ValueKey('time-start')));
    await tester.pumpAndSettle();

    // The old, unsplit row always opened the date picker first — this is
    // exactly the regression this split guards against.
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });

  testWidgets(
    'the open-in-maps button is disabled until a location is entered',
    (tester) async {
      await pumpEditor(tester);

      IconButton mapsButton() => tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.directions_outlined),
          matching: find.byType(IconButton),
        ),
      );

      expect(mapsButton().onPressed, isNull);

      await tester.enterText(
        find.ancestor(
          of: find.byIcon(Icons.place_outlined),
          matching: find.byType(TextField),
        ),
        'Some address',
      );
      await tester.pump();

      expect(mapsButton().onPressed, isNotNull);
    },
  );
}

EventRow row({
  required String id,
  required String title,
  String? memo,
  String? location,
  required DateTime startAt,
  required DateTime endAt,
  bool isAllDay = false,
  bool notify = true,
  String? colorTag,
  String? recurrenceGroupId,
}) {
  return EventRow(
    id: id,
    title: title,
    memo: memo,
    location: location,
    startAt: startAt,
    endAt: endAt,
    isAllDay: isAllDay,
    colorTag: colorTag,
    notify: notify,
    reminderMinutesBefore: 0,
    recurrenceRule: null,
    recurrenceGroupId: recurrenceGroupId,
    osCalendarId: null,
    osEventId: null,
    osLastKnownModified: null,
    syncStatus: SyncStatus.pendingPush,
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );
}
