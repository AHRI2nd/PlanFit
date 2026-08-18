import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/sync_status.dart';
import '../../../core/di.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';

/// A trail of what calendar reconciliation did — so last-write-wins is never
/// fully silent.
class SyncLogScreen extends ConsumerWidget {
  const SyncLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );
    final logs =
        ref.watch(syncLogDaoProvider).watchRecent();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSyncLog)),
      body: StreamBuilder<List<SyncLogRow>>(
        stream: logs,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <SyncLogRow>[];
          if (rows.isEmpty) {
            return Center(
              child: Text(
                '—',
                style: TextStyle(color: palette.inkFaint, fontSize: 32),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            itemCount: rows.length,
            separatorBuilder: (_, _) =>
                Divider(color: palette.hairline, height: AppSpacing.lg),
            itemBuilder: (context, i) {
              final row = rows[i];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconFor(row.resolution),
                      size: 18, color: _colorFor(row.resolution, palette)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.eventTitle ?? '—',
                            style: Theme.of(context).textTheme.titleMedium),
                        if (row.detail != null)
                          Text(row.detail!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: palette.inkSoft)),
                        const SizedBox(height: 2),
                        Text(Fmt.time(row.at, locale, use24Hour: use24),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: palette.inkFaint)),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(SyncResolution r) => switch (r) {
        SyncResolution.pushed => Icons.upload_outlined,
        SyncResolution.pulled => Icons.download_outlined,
        SyncResolution.conflictLocalWon => Icons.merge_type,
        SyncResolution.conflictRemoteWon => Icons.merge_type,
        SyncResolution.deletedRemotely => Icons.delete_outline,
      };

  Color _colorFor(SyncResolution r, AppPalette palette) => switch (r) {
        SyncResolution.deletedRemotely => palette.danger,
        SyncResolution.conflictLocalWon ||
        SyncResolution.conflictRemoteWon =>
          AppColors.dayAmber,
        _ => palette.accent,
      };
}
