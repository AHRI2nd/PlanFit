import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/backup/backup_service.dart';
import 'package:planfit/core/backup/share_full_backup.dart';
import 'package:planfit/core/db/daos/event_template_dao.dart';
import 'package:planfit/core/db/daos/todo_dao.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:planfit/features/schedule/domain/ports.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class _NoopEventRepository implements EventRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopTodoDao implements TodoDao {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopEventTemplateDao implements EventTemplateDao {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopNotificationPort implements NotificationPort {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestBackupService extends BackupService {
  _TestBackupService(this.file, {this.failOnExport = false})
    : super(
        eventRepository: _NoopEventRepository(),
        todoDao: _NoopTodoDao(),
        eventTemplateDao: _NoopEventTemplateDao(),
        notifications: _NoopNotificationPort(),
      );

  final File file;
  final bool failOnExport;

  @override
  Future<File> exportToFile() async {
    if (failOnExport) throw FileSystemException('test export failure');
    await file.writeAsString('{}');
    return file;
  }
}

class _FakeSharePlatform extends SharePlatform {
  Future<ShareResult> Function(ShareParams params)? onShare;

  @override
  Future<ShareResult> share(ShareParams params) => onShare!(params);
}

final _originalSharePlatform = SharePlatform.instance;
final _sharePlatform = _FakeSharePlatform();

void main() {
  late Directory tempDir;
  late File backupFile;

  setUpAll(() {
    SharePlatform.instance = _sharePlatform;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('planfit_share_backup');
    backupFile = File('${tempDir.path}/planfit-backup.json');
  });

  tearDown(() async {
    tempDir.deleteSync(recursive: true);
  });

  tearDownAll(() {
    SharePlatform.instance = _originalSharePlatform;
  });

  Future<BuildContext> pumpShareContext(WidgetTester tester) async {
    late BuildContext shareContext;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              shareContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return shareContext;
  }

  testWidgets('shares the generated backup and deletes it after completion', (
    tester,
  ) async {
    ShareParams? sharedParams;
    _sharePlatform.onShare = (params) async {
      sharedParams = params;
      expect(await backupFile.exists(), isTrue);
      return const ShareResult('shared', ShareResultStatus.success);
    };
    final context = await pumpShareContext(tester);
    await tester.runAsync(
      () => shareFullBackup(context, _TestBackupService(backupFile)),
    );
    await tester.pump();

    expect(sharedParams?.files?.single.path, backupFile.path);
    expect(await tester.runAsync(backupFile.exists), isFalse);
    expect(find.text('내보내기에 실패했어요'), findsNothing);
  });

  testWidgets('dismissed share sheet is quiet and still deletes the file', (
    tester,
  ) async {
    _sharePlatform.onShare = (_) async =>
        const ShareResult('dismissed', ShareResultStatus.dismissed);
    final context = await pumpShareContext(tester);
    await tester.runAsync(
      () => shareFullBackup(context, _TestBackupService(backupFile)),
    );
    await tester.pump();

    expect(await tester.runAsync(backupFile.exists), isFalse);
    expect(find.text('내보내기에 실패했어요'), findsNothing);
  });

  testWidgets('share failure shows a localized error and deletes the file', (
    tester,
  ) async {
    _sharePlatform.onShare = (_) async => throw StateError('share failed');
    final context = await pumpShareContext(tester);
    await tester.runAsync(
      () => shareFullBackup(context, _TestBackupService(backupFile)),
    );
    await tester.pump();

    expect(await tester.runAsync(backupFile.exists), isFalse);
    expect(find.text('내보내기에 실패했어요'), findsOneWidget);
  });

  testWidgets('export failure shows a localized error', (tester) async {
    _sharePlatform.onShare = (_) async =>
        const ShareResult('shared', ShareResultStatus.success);
    final context = await pumpShareContext(tester);
    await tester.runAsync(
      () => shareFullBackup(
        context,
        _TestBackupService(backupFile, failOnExport: true),
      ),
    );
    await tester.pump();

    expect(_sharePlatform.onShare, isNotNull);
    expect(await tester.runAsync(backupFile.exists), isFalse);
    expect(find.text('내보내기에 실패했어요'), findsOneWidget);
  });
}
