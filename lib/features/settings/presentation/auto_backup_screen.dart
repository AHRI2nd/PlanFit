import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../../core/backup/import_activity.dart';
import '../../../core/backup/share_full_backup.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../../design/glass/glass_nav_bar.dart' show navBarClearance;
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/app_dialog.dart';
import '../../../design/widgets/async_content.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';

class AutoBackupScreen extends ConsumerStatefulWidget {
  const AutoBackupScreen({super.key});
  @override
  ConsumerState<AutoBackupScreen> createState() => _AutoBackupScreenState();
}

class _BackupEntry {
  const _BackupEntry(this.file, this.stat, this.recovery);
  final File file;
  final FileStat? stat;
  final bool recovery;
}

class _AutoBackupScreenState extends ConsumerState<AutoBackupScreen>
    with WidgetsBindingObserver {
  late Future<List<_BackupEntry>> _future;
  List<_BackupEntry>? _previous;
  StreamSubscription<void>? _changes;
  bool _restoring = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
    _changes = ref.read(autoBackupServiceProvider).changes.listen((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_changes?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<List<_BackupEntry>> _load() async {
    final service = ref.read(autoBackupServiceProvider);
    final automatic = await service.listBackups();
    final recovery = await service.backupService.listRecoveryBackups();
    final entries = await Future.wait([
      for (final file in [...automatic, ...recovery]) (() async {
        FileStat? stat;
        try {
          final value = await file.stat();
          if (value.type == FileSystemEntityType.file) stat = value;
        } on FileSystemException { /* The row remains visible with a retry action. */ }
        return _BackupEntry(file, stat, recovery.any((r) => r.path == file.path));
      })(),
    ]);
    entries.sort((a, b) => (b.stat?.modified ?? DateTime(1970))
      .compareTo(a.stat?.modified ?? DateTime(1970)));
    if (mounted) _previous = entries;
    return entries;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final future = _load();
    setState(() => _future = future);
    try { await future; } catch (_) { /* FutureBuilder exposes retry. */ }
  }

  Future<void> _createNow() async {
    if (_creating) return;
    setState(() => _creating = true);
    try { await ref.read(autoBackupServiceProvider).runIfDue(force: true); }
    finally {
      if (mounted) { setState(() => _creating = false); await _refresh(); }
    }
  }

  Future<void> _restore(_BackupEntry entry) async {
    final activity = ref.read(backupImportActivityProvider.notifier);
    if (!activity.begin()) return;
    final backup = ref.read(autoBackupServiceProvider).backupService;
    final l10n = AppL10n.of(context);
    setState(() => _restoring = true);
    try {
      final prepared = await backup.prepareFromFile(entry.file.path);
      if (!mounted) return;
      final preview = prepared.preview;
      setState(() => _restoring = false);
      final confirmed = await showAppDialog<bool>(context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.autoBackupRestoreConfirmTitle),
          content: Text('${l10n.backupImportPreviewBody(preview.eventCount, preview.todoCount, preview.templateCount)}\n\n${l10n.backupImportMergeNote}'
            '${preview.legacyFormat ? '\n\n${l10n.backupImportLegacyWarning}' : ''}'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.autoBackupRestore))],
        ));
      if (confirmed != true || !mounted) return;
      setState(() => _restoring = true);
      final summary = await backup.importPrepared(prepared);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAutoDismissSnackBar(SnackBar(content: Text(
        '${l10n.backupImportSuccess(summary.eventCount, summary.todoCount)}'
        '${summary.deferredCount > 0 ? '\n${l10n.backupIntegrationDeferred}' : ''}'
        '${summary.legacyFormat ? '\n${l10n.backupImportLegacyWarning}' : ''}')));
      await _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.backupImportFailed)));
    } finally {
      activity.finish();
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final service = ref.watch(autoBackupServiceProvider);
    final importing = ref.watch(backupImportActivityProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final use24 = resolveUse24Hour(ref.watch(settingsControllerProvider
      .select((s) => s.displayTimeFormatPreference)), context);
    String formatted(DateTime value) => '${Fmt.monthDay(value, locale)} ${Fmt.time(value, locale, use24Hour: use24)}';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.autoBackupTitle), actions: [
        IconButton(tooltip: l10n.backupRefresh, onPressed: _refresh,
          icon: const Icon(Icons.refresh))]),
      body: Stack(children: [
        FutureBuilder<List<_BackupEntry>>(future: _future, builder: (context, snapshot) {
          final entries = snapshot.data ?? _previous;
          if (entries == null) {
            if (snapshot.hasError) return AsyncStateNotice(onRetry: _refresh);
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(onRefresh: _refresh, child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.gutter,
              AppSpacing.gutter, navBarClearance(context)),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting) const LinearProgressIndicator(),
              if (snapshot.hasError) AsyncStateNotice(onRetry: _refresh),
              Text(l10n.autoBackupDesc),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.autoBackupLocalProtection),
              if (service.lastRunAt != null) Text(l10n.backupLastSuccess(formatted(service.lastRunAt!))),
              if (service.lastAttemptAt != null) Text(l10n.backupLastAttempt(formatted(service.lastAttemptAt!))),
              if (service.lastError != null) Text(service.lastError == 'cleanup'
                ? l10n.backupCleanupPending : l10n.backupWriteFailed),
              Wrap(spacing: AppSpacing.sm, children: [
                OutlinedButton.icon(onPressed: () => shareFullBackup(context, service.backupService),
                  icon: const Icon(Icons.ios_share), label: Text(l10n.autoBackupExportFull)),
                TextButton.icon(onPressed: _creating || importing ? null : _createNow,
                  icon: const Icon(Icons.backup_outlined), label: Text(l10n.backupCreateNow)),
              ]),
              if (entries.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(l10n.autoBackupEmpty)),
              for (final entry in entries) ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(entry.recovery ? Icons.restore_page : Icons.history),
                title: Text(entry.stat == null ? entry.file.uri.pathSegments.last : formatted(entry.stat!.modified)),
                subtitle: Text(entry.stat == null ? l10n.errorWidgetFallback
                  : '${entry.recovery ? '${l10n.backupRecoveryLabel} · ' : ''}${(entry.stat!.size / 1024).ceil()} KB'),
                trailing: entry.stat == null ? IconButton(onPressed: _refresh,
                  tooltip: l10n.commonRetry, icon: const Icon(Icons.refresh))
                  : TextButton(onPressed: importing ? null : () => _restore(entry),
                      child: Text(l10n.autoBackupRestore)),
              ),
            ]));
        }),
        if (_restoring) const Positioned.fill(child: ColoredBox(color: Color(0x33000000),
          child: Center(child: CircularProgressIndicator()))),
      ]),
    );
  }
}
