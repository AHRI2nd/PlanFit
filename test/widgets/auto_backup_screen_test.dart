import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:planfit/core/backup/auto_backup_service.dart';
import 'package:planfit/core/backup/backup_service.dart';
import 'package:planfit/core/db/daos/event_template_dao.dart';
import 'package:planfit/core/db/daos/todo_dao.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/domain/ports.dart';
import 'package:planfit/features/settings/presentation/auto_backup_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
}

// None of these are ever actually called by this screen — restoring a
// backup goes through backupServiceProvider (a separate provider from
// autoBackupServiceProvider), and this screen's own initState only calls
// AutoBackupService.listBackups(), which never touches BackupService at
// all. Plain no-op Mocks (no @GenerateMocks/build_runner needed, since
// nothing here is ever stubbed or verified) are enough to satisfy
// BackupService's required constructor params.
class _NoopEventRepository extends Mock implements EventRepository {}

class _NoopTodoDao extends Mock implements TodoDao {}

class _NoopEventTemplateDao extends Mock implements EventTemplateDao {}

class _NoopNotificationPort extends Mock implements NotificationPort {}

void main() {
  late Directory rootDir;

  setUp(() {
    rootDir = Directory.systemTemp.createTempSync('planfit_auto_backup_ui');
    PathProviderPlatform.instance = _FakePathProvider(rootDir);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => rootDir.deleteSync(recursive: true));

  Future<void> pumpScreen(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final widget = ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        autoBackupServiceProvider.overrideWithValue(
          AutoBackupService(
            backupService: BackupService(
              eventRepository: _NoopEventRepository(),
              todoDao: _NoopTodoDao(),
              eventTemplateDao: _NoopEventTemplateDao(),
              notifications: _NoopNotificationPort(),
            ),
            prefs: prefs,
          ),
        ),
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
        home: const AutoBackupScreen(),
      ),
    );
    // initState's listBackups() future does real (if trivially fast)
    // dart:io filesystem work, whose completion callback arrives on the
    // real event loop — AutomatedTestWidgetsFlutterBinding's default
    // FakeAsync zone never lets that callback run, so pumping outside of
    // runAsync leaves the loading branch's CircularProgressIndicator on
    // screen forever (and pumpAndSettle just times out against its
    // perpetual animation). Building the widget (which kicks off that
    // future from initState) and waiting for it inside the same runAsync
    // callback lets the real event loop actually deliver it.
    await tester.runAsync(() async {
      await tester.pumpWidget(widget);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  testWidgets('shows an empty-state message when no backup has run yet', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('아직 자동 백업이 없어요'), findsOneWidget);
  });

  testWidgets(
    'lists an existing backup file with a restore button, and tapping it '
    'opens a confirmation dialog',
    (tester) async {
      // listBackups() reads from the service's own "auto_backups"
      // subdirectory under the app-support path, not the path itself.
      final backupsDir = Directory('${rootDir.path}/auto_backups')
        ..createSync(recursive: true);
      File(
        '${backupsDir.path}/backup-2026-01-01T00-00-00.json',
      ).writeAsStringSync('{}');

      await pumpScreen(tester);

      expect(find.text('이 백업으로 복원'), findsOneWidget);

      await tester.tap(find.text('이 백업으로 복원'));
      await tester.pumpAndSettle();

      expect(find.text('이 백업으로 복원할까요?'), findsOneWidget);
    },
  );
}
