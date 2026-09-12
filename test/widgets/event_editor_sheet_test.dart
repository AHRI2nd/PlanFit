import 'package:flutter/cupertino.dart' show CupertinoPicker;
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
import 'package:planfit/design/tokens/app_colors.dart';
import 'package:planfit/features/schedule/domain/event_input.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/domain/recurrence.dart';
import 'package:planfit/features/schedule/presentation/event_edit/event_editor_sheet.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

  testWidgets('picking "매년" while lunar input is on saves as yearlyLunar, not '
      'plain yearly — and the chip still just reads "매년", not a 6th '
      'option of its own', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Lunar birthday');
    await tester.tap(find.byIcon(Icons.nightlight_outlined));
    await tester.pump();

    await tester.dragUntilVisible(
      find.text('매년'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    expect(find.text('음력'), findsNothing);
    await tester.tap(find.text('매년'), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final input = verify(repo.save(captureAny)).captured.single as EventInput;
    expect(input.recurrenceFrequency, RecurrenceFrequency.yearlyLunar);
  });

  testWidgets('picking "매년" defaults its end date via RecurrenceExpansion'
      '.defaultUntil, not a flat start+365 days — regression test: a '
      'fixed +365 days silently produced just one occurrence whenever a '
      'leap year fell inside that window, since defaultUntil special-cases '
      'yearly/yearlyLunar for exactly this reason (already used by '
      'TodoController.add, but not here until now)', (tester) async {
    // A fixed +365 days from here lands on 2024-02-29 (2024 is a leap
    // year), a day *before* the real next anniversary of 2024-03-01 —
    // exactly the silent "ends one occurrence early" failure mode
    // defaultUntil exists to avoid.
    final start = DateTime(2023, 3, 1, 9);
    await pumpEditor(tester, initialStart: start);

    await tester.enterText(find.byType(TextField).at(0), 'Leap year birthday');
    await tester.dragUntilVisible(
      find.text('매년'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('매년'), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final input = verify(repo.save(captureAny)).captured.single as EventInput;
    expect(input.recurrenceFrequency, RecurrenceFrequency.yearly);
    expect(
      input.recurrenceUntil,
      RecurrenceExpansion.defaultUntil(start, RecurrenceFrequency.yearly),
    );
    // The bug this guards against: the old flat +365-days default.
    expect(input.recurrenceUntil, isNot(start.add(const Duration(days: 365))));
  });

  testWidgets('turning lunar input back off after picking "매년" reverts it to '
      'plain yearly', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Plain yearly');
    await tester.tap(find.byIcon(Icons.nightlight_outlined));
    await tester.pump();
    await tester.dragUntilVisible(
      find.text('매년'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('매년'), warnIfMissed: false);
    await tester.pump();

    // Toggle lunar input back off — scroll back up to reach the icon.
    await tester.dragUntilVisible(
      find.byIcon(Icons.nightlight_round),
      find.byType(ListView),
      const Offset(0, 100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.nightlight_round));
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final input = verify(repo.save(captureAny)).captured.single as EventInput;
    expect(input.recurrenceFrequency, RecurrenceFrequency.yearly);
  });

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

  testWidgets(
    "the start date's own text color clears WCAG AA contrast against the "
    "card surface it sits on — regression test: it used to be the raw "
    "time-of-day accent with no adjustment at all, which measured well "
    "under the 4.5:1 floor for normal text near the gradient's amber/sky "
    'stops',
    (tester) async {
      // Midday — the time-of-day gradient's own amber/sky stretch, exactly
      // where the raw accent color used to fail contrast worst.
      final existing = row(
        id: 'e4b',
        title: 'Contrast check',
        startAt: DateTime(2026, 3, 10, 13),
        endAt: DateTime(2026, 3, 10, 14),
      );
      await pumpEditor(tester, existing: existing);

      final dateText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('date-start')),
          matching: find.byType(Text),
        ),
      );

      expect(
        contrastRatio(dateText.style!.color!, AppPalette.light.surface),
        greaterThanOrEqualTo(4.5),
      );
    },
  );

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

  group('lunar date input', () {
    testWidgets(
      'toggling it opens the custom picker instead of the native one — '
      'unlike showDatePicker, this one is a plain custom widget, so this '
      'test drives it directly rather than just asserting dialog type',
      (tester) async {
        final existing = row(
          id: 'e6',
          title: 'Lunar toggle test',
          startAt: DateTime(2026, 3, 10, 9),
          endAt: DateTime(2026, 3, 10, 10),
        );
        await pumpEditor(tester, existing: existing);

        await tester.tap(find.byIcon(Icons.nightlight_outlined));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('date-start')));
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsNothing);
        expect(find.byType(CupertinoPicker), findsNWidgets(3));
      },
    );

    testWidgets(
      'confirming it with no wheel changes round-trips to the same start '
      'date',
      (tester) async {
        final existing = row(
          id: 'e7',
          title: 'Lunar round trip',
          startAt: DateTime(2026, 3, 10, 9),
          endAt: DateTime(2026, 3, 10, 10),
        );
        await pumpEditor(tester, existing: existing);

        // All-day first, so _pick skips its own time-picker step entirely
        // (see _pick's own doc) — the lunar date sheet is then the only
        // step left before save, no native dialog to also drive.
        await tester.tap(find.byType(Switch).first);
        await tester.pump();

        await tester.tap(find.byIcon(Icons.nightlight_outlined));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('date-start')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('완료'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();

        final input =
            verify(repo.save(captureAny)).captured.single as EventInput;
        expect(input.startAt, DateTime(2026, 3, 10));
      },
    );
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

  testWidgets(
    'saving the current event as a template captures its location too — '
    'regression test: the EventTemplates table/save flow used to have no '
    'location field at all, so it was silently dropped every time a '
    'template was saved, and never restored when one was applied',
    (tester) async {
      when(templateDao.upsert(any)).thenAnswer((_) async {});
      await pumpEditor(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Team sync');
      await tester.enterText(find.byType(TextField).at(2), 'Room 2');

      await tester.tap(find.byTooltip('템플릿'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('현재 내용을 템플릿으로 저장'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Standup');
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();
      // The success snackbar auto-dismisses itself on its own timer —
      // drain that so the test doesn't end with it still pending.
      await tester.pump(const Duration(seconds: 5));

      final companion =
          verify(templateDao.upsert(captureAny)).captured.single
              as EventTemplatesCompanion;
      expect(companion.title.value, 'Team sync');
      expect(companion.location.value, 'Room 2');
    },
  );

  testWidgets(
    'applying a template restores its saved location into the editor',
    (tester) async {
      final template = EventTemplateRow(
        id: 't1',
        name: 'Gym',
        title: 'Workout',
        memo: null,
        location: 'Community Center',
        durationMinutes: 60,
        isAllDay: false,
        colorTag: null,
        notify: true,
        reminderMinutesBefore: 0,
        createdAt: DateTime(2020),
      );
      when(templateDao.watchAll()).thenAnswer((_) => Stream.value([template]));
      await pumpEditor(tester);

      await tester.tap(find.byTooltip('템플릿'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gym'));
      await tester.pumpAndSettle();

      expect(find.text('Community Center'), findsOneWidget);
    },
  );

  group('recomputeForNewStart', () {
    test("pushing the start date past the old end recomputes the end "
        "using the event's wall-clock length, not elapsed real time — "
        'regression test: a real DST spring-forward, verified with '
        "timezone's TZDateTime pinned to America/New_York (its actual "
        '2026 transition) rather than relying on the host running this '
        'test to observe one', () {
      tzdata.initializeTimeZones();
      final ny = tz.getLocation('America/New_York');
      // An ordinary 2h30m event, nowhere near any transition.
      final oldStart = tz.TZDateTime(ny, 2026, 1, 5, 1, 0);
      final oldEnd = tz.TZDateTime(ny, 2026, 1, 5, 3, 30);
      // Pushed out to the very night of the 2026 US spring-forward
      // (2AM -> 3AM) — old end (Jan 5) is now before this, so the end
      // gets recomputed from it.
      final newStart = tz.TZDateTime(ny, 2026, 3, 8, 1, 0);

      final result = recomputeForNewStart(
        oldStart: oldStart,
        oldEnd: oldEnd,
        oldRecurrenceUntil: newStart, // not exercised by this case
        newStart: newStart,
        recurrence: RecurrenceFrequency.none,
      );

      expect(result.end.hour, 3);
      expect(result.end.minute, 30);
      expect(result.end.day, 8);

      // Confirm this scenario actually exercises the transition — the
      // old elapsed-time approach really does drift an hour later here.
      final buggyEnd = newStart.add(oldEnd.difference(oldStart));
      expect(
        buggyEnd.hour,
        4,
        reason:
            'the elapsed-time approach lands an hour later than '
            'intended here — confirming this scenario genuinely '
            'crosses the transition, not a false negative',
      );
    });

    test('leaves the end alone when it is still after the new start', () {
      final oldStart = DateTime(2026, 3, 10, 9);
      final oldEnd = DateTime(2026, 3, 10, 10);
      final newStart = DateTime(2026, 3, 10, 8);

      final result = recomputeForNewStart(
        oldStart: oldStart,
        oldEnd: oldEnd,
        oldRecurrenceUntil: DateTime(2026, 4, 1),
        newStart: newStart,
        recurrence: RecurrenceFrequency.none,
      );

      expect(result.end, oldEnd);
    });

    test('pushing the start past a still-active recurrence carries "until" '
        'forward by the same number of calendar days — the DST-safety of '
        'this calculation rests entirely on calendarDuration, already '
        "verified directly (with a real DST transition) in "
        'date_math_test.dart; this covers the wiring with ordinary dates', () {
      final result = recomputeForNewStart(
        oldStart: DateTime(2026, 1, 5, 9),
        oldEnd: DateTime(2026, 1, 5, 10),
        oldRecurrenceUntil: DateTime(2026, 5, 15), // 130 days after Jan 5
        newStart: DateTime(2026, 6, 1, 9), // past the old until
        recurrence: RecurrenceFrequency.daily,
      );

      expect(result.recurrenceUntil, DateTime(2026, 10, 9));
    });

    test('leaves "until" alone when it is still after the new start', () {
      final until = DateTime(2026, 5, 15);
      final result = recomputeForNewStart(
        oldStart: DateTime(2026, 1, 5, 9),
        oldEnd: DateTime(2026, 1, 5, 10),
        oldRecurrenceUntil: until,
        newStart: DateTime(2026, 2, 1, 9),
        recurrence: RecurrenceFrequency.daily,
      );

      expect(result.recurrenceUntil, until);
    });

    test('leaves "until" alone when the event has no recurrence at all', () {
      final until = DateTime(2020); // a bare default, never meant to be used
      final result = recomputeForNewStart(
        oldStart: DateTime(2026, 1, 5, 9),
        oldEnd: DateTime(2026, 1, 5, 10),
        oldRecurrenceUntil: until,
        newStart: DateTime(2026, 6, 1, 9),
        recurrence: RecurrenceFrequency.none,
      );

      expect(result.recurrenceUntil, until);
    });
  });
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
