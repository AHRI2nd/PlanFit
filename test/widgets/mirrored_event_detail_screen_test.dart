import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/schedule/presentation/event_edit/mirrored_event_detail_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

EventRow _row({required String? importSourceCalendarId}) {
  final now = DateTime(2026, 1, 1);
  return EventRow(
    id: 'e1',
    title: 'New Year',
    memo: null,
    location: null,
    startAt: now,
    endAt: now.add(const Duration(days: 1)),
    isAllDay: true,
    notify: false,
    reminderMinutesBefore: 0,
    syncStatus: SyncStatus.synced,
    importSourceCalendarId: importSourceCalendarId,
    importSourceEventId: 'new-year@holiday',
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pump(WidgetTester tester, EventRow event) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
        home: MirroredEventDetailScreen(event: event),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a holiday-mirrored event shows the holiday badge and copy, not the '
    'subscribed-calendar one',
    (tester) async {
      await _pump(tester, _row(importSourceCalendarId: 'holiday:ko'));

      expect(find.text('공휴일'), findsOneWidget);
      expect(find.text('구독 중 — 계속 최신 상태로 유지돼요'), findsNothing);
      expect(
        find.text('믿을 수 있는 캘린더에서 자동으로 불러온 공휴일이라 PlanFit에서는 읽기 전용이에요.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a device-calendar-mirrored event keeps the original subscribed copy',
    (tester) async {
      await _pump(tester, _row(importSourceCalendarId: 'device:abc'));

      expect(find.text('구독 중 — 계속 최신 상태로 유지돼요'), findsOneWidget);
      expect(find.text('공휴일'), findsNothing);
    },
  );
}
