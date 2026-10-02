import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/backup/backup_service.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/settings/application/app_settings.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';
import 'package:planfit/features/settings/presentation/settings_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SelectedBackupFile extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile('/tmp/selected-planfit-backup.json');
}

class _SettingsController extends SettingsController {
  @override
  AppSettings build() => const AppSettings();
}

class _RecordingBackupService extends Fake implements BackupService {
  int importCalls = 0;

  @override
  Future<BackupFilePreview> previewFromFile(String path) async =>
      const BackupFilePreview(
        eventCount: 3,
        todoCount: 2,
        templateCount: 1,
        legacyFormat: false,
      );

  @override
  Future<BackupImportSummary> importFromFile(String path) async {
    importCalls++;
    return const BackupImportSummary(
      eventCount: 3,
      todoCount: 2,
      templateCount: 1,
      legacyFormat: false,
    );
  }
}

void main() {
  late FileSelectorPlatform originalFileSelector;
  late _RecordingBackupService backup;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalFileSelector = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = _SelectedBackupFile();
    backup = _RecordingBackupService();
  });

  tearDown(() => FileSelectorPlatform.instance = originalFileSelector);

  Future<void> pumpSettings(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsControllerProvider.overrideWith(_SettingsController.new),
          backupServiceProvider.overrideWithValue(backup),
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
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('전체 백업 가져오기'));
    await tester.pumpAndSettle();
  }

  testWidgets('canceling the import preview leaves local data untouched', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.tap(find.text('전체 백업 가져오기'));
    await tester.pumpAndSettle();

    expect(find.text('전체 백업을 가져올까요?'), findsOneWidget);
    expect(find.textContaining('일정 3개'), findsOneWidget);
    expect(backup.importCalls, 0);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(backup.importCalls, 0);
  });

  testWidgets('confirming the import preview applies the backup once', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.tap(find.text('전체 백업 가져오기'));
    await tester.pumpAndSettle();

    expect(backup.importCalls, 0);
    await tester.tap(find.text('가져오기', skipOffstage: false).last);
    await tester.pumpAndSettle();
    expect(backup.importCalls, 1);
  });
}
