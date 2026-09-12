import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/daos/sync_log_dao.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/settings/presentation/sync_log_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_log_screen_test.mocks.dart';

@GenerateMocks([SyncLogDao])
void main() {
  late MockSyncLogDao syncLogDao;

  setUp(() {
    syncLogDao = MockSyncLogDao();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<SyncLogRow> rows = const [],
  }) async {
    when(syncLogDao.watchRecent()).thenAnswer((_) => Stream.value(rows));
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          syncLogDaoProvider.overrideWithValue(syncLogDao),
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
          home: const SyncLogScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  SyncLogRow row({
    int id = 1,
    required SyncResolution resolution,
    String? eventTitle,
    String? detail,
  }) {
    return SyncLogRow(
      id: id,
      at: DateTime(2026, 3, 10, 9),
      eventTitle: eventTitle,
      resolution: resolution,
      detail: detail,
    );
  }

  testWidgets('shows a placeholder dash when there is no sync activity yet', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('동기화 기록'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('renders a logged entry\'s title and detail', (tester) async {
    await pumpScreen(
      tester,
      rows: [
        row(
          resolution: SyncResolution.pushed,
          eventTitle: 'Team lunch',
          detail: 'Created on device calendar',
        ),
      ],
    );

    expect(find.text('Team lunch'), findsOneWidget);
    expect(find.text('Created on device calendar'), findsOneWidget);
    expect(find.byIcon(Icons.upload_outlined), findsOneWidget);
  });

  testWidgets('a failed resolution renders with the danger icon/color', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      rows: [row(resolution: SyncResolution.failed, eventTitle: 'Standup')],
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
