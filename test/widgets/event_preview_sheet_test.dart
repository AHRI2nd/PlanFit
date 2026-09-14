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
import 'package:planfit/design/glass/glass_surface.dart';
import 'package:planfit/design/glass/glass_nav_bar.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/design/tokens/app_spacing.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/presentation/event_edit/event_editor_sheet.dart';
import 'package:planfit/features/schedule/presentation/event_edit/event_preview_sheet.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'event_preview_sheet_test.mocks.dart';

// Covers the read-only/editable split showEventEditor's mirrored branch now
// delegates to this sheet for (see event_editor_sheet.dart's own doc): a
// mirrored/holiday event never gets an "편집하기" button (there's nothing to
// edit — see EventPreviewSheet._isMirrored's doc), while a regular event's
// button is the one required entry point back to the full editor.
@GenerateMocks([EventRepository, EventTemplateDao])
void main() {
  late MockEventRepository repo;
  late MockEventTemplateDao templateDao;

  EventRow row({
    String title = 'Team sync',
    String? memo,
    String? location,
    String? importSourceCalendarId,
    String? recurrenceGroupId,
    bool notify = false,
    int reminderMinutesBefore = 0,
    String? additionalReminderMinutes,
  }) {
    final start = DateTime(2026, 3, 10, 9);
    return EventRow(
      id: 'e1',
      title: title,
      memo: memo,
      location: location,
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
      isAllDay: false,
      notify: notify,
      reminderMinutesBefore: reminderMinutesBefore,
      additionalReminderMinutes: additionalReminderMinutes,
      syncStatus: SyncStatus.synced,
      importSourceCalendarId: importSourceCalendarId,
      recurrenceGroupId: recurrenceGroupId,
      createdAt: start,
      updatedAt: start,
    );
  }

  setUp(() {
    repo = MockEventRepository();
    templateDao = MockEventTemplateDao();
    SharedPreferences.setMockInitialValues({});
    when(
      templateDao.watchAll(),
    ).thenAnswer((_) => Stream.value(const <EventTemplateRow>[]));
  });

  Future<void> pumpPreview(WidgetTester tester, EventRow event) async {
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
                  onPressed: () => showEventPreview(context, event: event),
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

  testWidgets(
    'a regular event shows an edit button, and tapping it opens the full '
    'editor for the same event',
    (tester) async {
      await pumpPreview(tester, row(title: 'Team sync', location: 'HQ'));

      expect(find.text('Team sync'), findsOneWidget);
      expect(find.text('HQ'), findsOneWidget);
      expect(find.text('편집하기'), findsOneWidget);

      await tester.tap(find.text('편집하기'));
      await tester.pumpAndSettle();

      expect(find.byType(EventEditorSheet), findsOneWidget);
      expect(find.text('일정 편집'), findsOneWidget);
      // The preview sheet itself is gone — a plain pop-then-push, not a
      // second layer stacked on top of it.
      expect(find.byType(EventPreviewSheet), findsNothing);
    },
  );

  testWidgets(
    'a holiday-mirrored event shows the holiday badge and read-only note, '
    'with no edit button',
    (tester) async {
      await pumpPreview(
        tester,
        row(title: 'New Year', importSourceCalendarId: 'holiday:KR'),
      );

      expect(find.text('공휴일'), findsOneWidget);
      expect(find.text('구독 중 — 계속 최신 상태로 유지돼요'), findsNothing);
      expect(
        find.text('믿을 수 있는 캘린더에서 자동으로 불러온 공휴일이라 PlanFit에서는 읽기 전용이에요.'),
        findsOneWidget,
      );
      expect(find.text('편집하기'), findsNothing);
    },
  );

  testWidgets(
    'a device-calendar-mirrored event shows the subscribed badge and note, '
    'with no edit button',
    (tester) async {
      await pumpPreview(
        tester,
        row(title: 'Standup', importSourceCalendarId: 'device:abc'),
      );

      expect(find.text('구독 중 — 계속 최신 상태로 유지돼요'), findsOneWidget);
      expect(find.text('공휴일'), findsNothing);
      expect(find.text('편집하기'), findsNothing);
    },
  );

  testWidgets('a recurring event shows the repeat row', (tester) async {
    await pumpPreview(tester, row(recurrenceGroupId: 'series-1'));

    expect(find.text('반복'), findsOneWidget);
  });

  testWidgets(
    'an event with notifications off shows "알림 없음", not a reminder time',
    (tester) async {
      await pumpPreview(tester, row(notify: false));

      expect(find.text('알림 없음'), findsOneWidget);
    },
  );

  testWidgets(
    'an event with notifications on shows every configured reminder as its '
    'own lead-time label plus a small absolute clock time underneath — not '
    'a single comma-joined line, and not the label alone',
    (tester) async {
      final event = row(
        notify: true,
        reminderMinutesBefore: 10,
        additionalReminderMinutes: '60',
      );
      await pumpPreview(tester, event);

      // event.startAt is 2026-03-10 09:00 — 10 minutes before is 08:50,
      // 1 hour before is 08:00. use24Hour resolves to false by default
      // (TimeFormatPreference.system against flutter_test's own default
      // MediaQuery.alwaysUse24HourFormat: false), matching Fmt.time's own
      // ko/12-hour output.
      expect(find.text('10분 전'), findsOneWidget);
      expect(find.text('오전 8:50'), findsOneWidget);
      expect(find.text('1시간 전'), findsOneWidget);
      expect(find.text('오전 8:00'), findsOneWidget);
      expect(find.text('10분 전, 1시간 전'), findsNothing);
      expect(find.text('알림 없음'), findsNothing);
    },
  );

  testWidgets(
    "the sheet's max height clears the top safe-area inset (notch/Dynamic "
    'Island) with real margin, instead of a flat screen-height percentage '
    'that ignores it — regression test: a tall enough sheet used to be '
    'capped at a flat 85% of the *full* screen height, letting its top '
    'edge land right under (or straddling) a Dynamic Island on an iOS '
    'simulator instead of clearing it. Also regression-tests reading the '
    'inset from the raw platform view (MediaQueryData.fromView) rather '
    'than the ambient MediaQuery — a first attempt at this fix read '
    "MediaQuery.paddingOf(context) from this sheet's own build, which "
    'ModalBottomSheetRoute always strips to 0 via '
    'MediaQuery.removePadding(removeTop: true), and a second attempt '
    "captured it from the *calling* context instead, which still didn't "
    "reliably carry the device's real inset through to here — confirmed "
    'live on an iOS simulator both times',
    (tester) async {
      const topInset = 59.0; // a real Dynamic Island's own inset
      // 1.0 so the FakeViewPadding physical-pixel value below equals the
      // logical value MediaQueryData.fromView ultimately resolves to.
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.padding = const FakeViewPadding(top: topInset);
      addTearDown(tester.view.resetPadding);

      await pumpPreview(tester, row());

      final root = tester.widget<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius ==
                  const BorderRadius.all(AppRadius.lg),
        ),
      );
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      // No keyboard here, so the bottom margin is just the floating tab
      // bar's own clearance.
      expect(
        root.constraints!.maxHeight,
        screenHeight -
            topInset -
            AppSpacing.xl -
            navBarClearance(tester.element(find.byType(EventPreviewSheet))),
      );
    },
  );

  testWidgets('a short event does not force the sheet to its full maxHeight — '
      'regression test: the scrollable info-row region used to be wrapped '
      'in Expanded (tight fit) instead of Flexible (loose fit), which '
      'forced it to consume every pixel of leftover space inside the '
      'height-capped sheet regardless of how little content it actually '
      'held — a large dead-space gap between the last row and the edit '
      'button, confirmed live on an iOS simulator', (tester) async {
    await pumpPreview(tester, row(title: 'Short event'));

    final sheet = tester.getSize(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).borderRadius ==
                const BorderRadius.all(AppRadius.lg),
      ),
    );
    // Well under the 568 a full maxHeight cap would have forced this to
    // pre-fix (600, flutter_test's own default surface height, minus the
    // 32 margin and a 0 top inset) — a short event's real content
    // (title + a couple of info rows + the edit button, plus padding)
    // has no business anywhere near that tall.
    expect(sheet.height, lessThan(450));
  });

  testWidgets(
    "the card's own bottom edge stops short of the true screen bottom, "
    'clearing the floating tab bar with an outer margin — regression test: '
    'the tab-bar clearance used to be blank padding *inside* the card '
    "(below the edit button, still the card's own solid-white background), "
    'which read as a large dead, unstyled rectangle floating above the tab '
    "bar rather than a normal margin — confirmed live on an iOS simulator",
    (tester) async {
      await pumpPreview(tester, row(title: 'Short event'));

      final cardBottom = tester
          .getBottomLeft(
            find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).borderRadius ==
                      const BorderRadius.all(AppRadius.lg),
            ),
          )
          .dy;
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        screenHeight - cardBottom,
        greaterThanOrEqualTo(
          navBarClearance(tester.element(find.byType(EventPreviewSheet))),
        ),
      );
    },
  );

  testWidgets(
    'the sheet paints its own fully opaque background and uses no glass/'
    'blur/gradient anywhere — regression test: showAdaptiveBottomSheet '
    'itself is called with backgroundColor: Colors.transparent, so without '
    'this sheet supplying its own solid background, whatever screen sits '
    'behind it shows straight through and overlaps its own text — '
    'confirmed live on an iOS simulator before this fix',
    (tester) async {
      await pumpPreview(tester, row(title: 'Team sync'));

      final root = tester.widget<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius ==
                  const BorderRadius.all(AppRadius.lg),
        ),
      );
      final decoration = root.decoration! as BoxDecoration;
      expect(decoration.color, isNotNull);
      expect(decoration.color!.a, 1.0, reason: 'must be fully opaque');
      expect(find.byType(GlassSurface), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );
}
