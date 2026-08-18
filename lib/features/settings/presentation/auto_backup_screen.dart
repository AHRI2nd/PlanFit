import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';

/// Lists PlanFit's own rolling automatic backups (see [AutoBackupService])
/// and lets the user restore from one — the safety net for when the manual
/// "내보내기" export was never run before the device was lost or reset.
class AutoBackupScreen extends ConsumerStatefulWidget {
  const AutoBackupScreen({super.key});

  @override
  ConsumerState<AutoBackupScreen> createState() => _AutoBackupScreenState();
}

class _AutoBackupScreenState extends ConsumerState<AutoBackupScreen> {
  Future<List<File>>? _future;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(autoBackupServiceProvider).listBackups();
  }

  Future<void> _restore(File file) async {
    final l10n = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.autoBackupRestoreConfirmTitle),
        content: Text(l10n.autoBackupRestoreConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.autoBackupRestore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _restoring = true);
    try {
      final summary =
          await ref.read(backupServiceProvider).importFromFile(file.path);
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(SnackBar(
        content: Text(
          l10n.backupImportSuccess(summary.eventCount, summary.todoCount),
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.backupImportFailed)),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.autoBackupTitle)),
      body: Stack(
        children: [
          FutureBuilder<List<File>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final files = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.gutter),
                    child: Text(
                      l10n.autoBackupDesc,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: palette.inkFaint),
                    ),
                  ),
                  Expanded(
                    child: files.isEmpty
                        ? Center(
                            child: Text(
                              l10n.autoBackupEmpty,
                              style: TextStyle(color: palette.inkFaint),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.gutter),
                            itemCount: files.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: palette.hairline),
                            itemBuilder: (context, i) {
                              final file = files[i];
                              return FutureBuilder<FileStat>(
                                future: file.stat(),
                                builder: (context, statSnapshot) {
                                  final modified = statSnapshot.data?.modified;
                                  final size = statSnapshot.data?.size;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.history,
                                        color: palette.inkFaint),
                                    title: Text(
                                      modified == null
                                          ? file.uri.pathSegments.last
                                          : '${Fmt.monthDay(modified, locale)}  ${Fmt.time(modified, locale, use24Hour: use24)}',
                                    ),
                                    subtitle: size == null
                                        ? null
                                        : Text('${(size / 1024).ceil()} KB'),
                                    trailing: TextButton(
                                      onPressed: _restoring
                                          ? null
                                          : () => _restore(file),
                                      child: Text(l10n.autoBackupRestore),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
          if (_restoring)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
