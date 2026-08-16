import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di.dart';
import '../../../core/format.dart';
import '../../../design/glass/glass_surface.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/section_header.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../design/widgets/time_gradient_background.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    Future<void> toggleSync(bool value) async {
      if (value) {
        final granted = await ref.read(calendarServiceProvider).requestAccess();
        if (!granted) return;
        // Resolving reuses an existing "PlanFit" calendar if the OS still has
        // one (e.g. from before a reinstall) or creates it the first time —
        // persist the id so that creation only ever happens once, not again
        // on every cold start.
        final calendarId = await ref
            .read(calendarServiceProvider)
            .resolveTargetCalendarId();
        if (calendarId == null) {
          // Nothing to sync into (creation failed and no writable calendar
          // exists either) — leave the toggle off rather than claiming sync
          // is on with no target.
          return;
        }
        await controller.setTargetCalendar(calendarId);
      }
      await controller.setCalendarSyncEnabled(value);
    }

    Future<void> toggleSound(bool value) async {
      if (value) {
        final granted = await ref
            .read(notificationServiceProvider)
            .requestPermission();
        // Denied (or previously denied, so iOS silently returns false with
        // no dialog at all) — don't flip the switch on and persist a
        // setting that claims notifications work when the OS is blocking
        // them outright.
        if (!granted) return;
      }
      await controller.setNotificationSound(value);
    }

    Future<void> exportBackup() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final file = await ref.read(backupServiceProvider).exportToFile();
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], subject: 'PlanFit backup'),
        );
      } catch (_) {
        messenger.showAutoDismissSnackBar(
          SnackBar(content: Text(l10n.backupExportFailed)),
        );
      }
    }

    Future<void> importBackup() async {
      final messenger = ScaffoldMessenger.of(context);
      const jsonTypeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
      final file = await openFile(acceptedTypeGroups: [jsonTypeGroup]);
      final path = file?.path;
      if (path == null) return;
      try {
        final summary = await ref
            .read(backupServiceProvider)
            .importFromFile(path);
        messenger.showAutoDismissSnackBar(
          SnackBar(
            content: Text(
              l10n.backupImportSuccess(summary.eventCount, summary.todoCount),
            ),
          ),
        );
      } catch (_) {
        messenger.showAutoDismissSnackBar(
          SnackBar(content: Text(l10n.backupImportFailed)),
        );
      }
    }

    Future<void> exportIcs() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final file = await ref.read(icsExportServiceProvider).exportToFile();
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], subject: 'PlanFit calendar'),
        );
      } catch (_) {
        messenger.showAutoDismissSnackBar(
          SnackBar(content: Text(l10n.backupExportFailed)),
        );
      }
    }

    Future<void> importIcs() async {
      final messenger = ScaffoldMessenger.of(context);
      const icsTypeGroup = XTypeGroup(label: 'ICS', extensions: ['ics']);
      final file = await openFile(acceptedTypeGroups: [icsTypeGroup]);
      final path = file?.path;
      if (path == null) return;
      try {
        final summary = await ref
            .read(icsExportServiceProvider)
            .importFromFile(path);
        final message = summary.skippedCount == 0
            ? l10n.icsImportSuccess(summary.eventCount)
            : '${l10n.icsImportSuccess(summary.eventCount)} '
                  '(${l10n.icsImportSkipped(summary.skippedCount)})';
        messenger.showAutoDismissSnackBar(SnackBar(content: Text(message)));
      } catch (_) {
        messenger.showAutoDismissSnackBar(SnackBar(content: Text(l10n.icsImportFailed)));
      }
    }

    return TimeGradientBackground(
      intensity: 0.5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            140,
          ),
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.lg,
                ),
                child: Text(
                  l10n.settingsTitle,
                  style:
                      theme.textTheme.displaySmall ??
                      theme.textTheme.headlineMedium,
                ),
              ),
            ),

            SectionHeader(l10n.settingsNotifications),
            _Card(
              children: [
                _SwitchRow(
                  title: l10n.settingsNotificationSound,
                  subtitle: l10n.settingsNotificationSoundDesc,
                  value: settings.notificationSound,
                  onChanged: toggleSound,
                ),
                const _RowDivider(),
                _ExactAlarmRow(l10n: l10n),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            SectionHeader(l10n.settingsCalendar),
            _Card(
              children: [
                _SwitchRow(
                  title: l10n.settingsCalendarSync,
                  subtitle: l10n.settingsCalendarSyncDesc,
                  value: settings.calendarSyncEnabled,
                  onChanged: toggleSync,
                ),
                const _RowDivider(),
                _CalendarTargetRow(
                  enabled: settings.calendarSyncEnabled,
                  l10n: l10n,
                  onTap: () => context.go('/settings/calendar-picker'),
                ),
                if (settings.calendarSyncEnabled) ...[
                  const _RowDivider(),
                  _LastSyncRow(l10n: l10n),
                ],
                const _RowDivider(),
                _NavRow(
                  title: l10n.settingsSyncLog,
                  onTap: () => context.go('/settings/sync-log'),
                ),
                const _RowDivider(),
                _ActionRow(
                  title: l10n.settingsCalendarImport,
                  subtitle: l10n.settingsCalendarImportDesc,
                  icon: Icons.file_download_outlined,
                  onTap: () => context.go('/settings/calendar-import'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            SectionHeader(l10n.settingsAppearance),
            _Card(
              children: [
                _ThemeRow(
                  current: settings.themeMode,
                  labels: (
                    l10n.settingsThemeSystem,
                    l10n.settingsThemeLight,
                    l10n.settingsThemeDark,
                  ),
                  onChanged: controller.setThemeMode,
                ),
                const _RowDivider(),
                _WeekStartRow(
                  weekStartsMonday: settings.weekStartsMonday,
                  l10n: l10n,
                  onChanged: controller.setWeekStartsMonday,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            SectionHeader(l10n.settingsTodo),
            _Card(
              children: [
                _TodoRetentionRow(
                  days: settings.completedTodoRetentionDays,
                  l10n: l10n,
                  onChanged: controller.setCompletedTodoRetentionDays,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            SectionHeader(l10n.settingsData),
            _Card(
              children: [
                _ActionRow(
                  title: l10n.settingsExport,
                  subtitle: l10n.settingsExportDesc,
                  icon: Icons.ios_share,
                  onTap: exportBackup,
                ),
                const _RowDivider(),
                _ActionRow(
                  title: l10n.settingsImport,
                  subtitle: l10n.settingsImportDesc,
                  icon: Icons.file_download_outlined,
                  onTap: importBackup,
                ),
                const _RowDivider(),
                _ActionRow(
                  title: l10n.settingsExportIcs,
                  subtitle: l10n.settingsExportIcsDesc,
                  icon: Icons.event_note_outlined,
                  onTap: exportIcs,
                ),
                const _RowDivider(),
                _ActionRow(
                  title: l10n.settingsImportIcs,
                  subtitle: l10n.settingsImportIcsDesc,
                  icon: Icons.event_available_outlined,
                  onTap: importIcs,
                ),
                const _RowDivider(),
                _NavRow(
                  title: l10n.settingsAutoBackup,
                  onTap: () => context.go('/settings/auto-backup'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            SectionHeader(l10n.settingsAbout),
            _Card(
              children: [_InfoRow(title: l10n.settingsVersion, value: '1.0.0')],
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: AppRadius.cardLg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: context.palette.hairline);
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Icon(Icons.chevron_right, color: palette.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: palette.accent, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.current,
    required this.labels,
    required this.onChanged,
  });

  final ThemeMode current;
  final (String, String, String) labels;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entries = [
      (ThemeMode.system, labels.$1),
      (ThemeMode.light, labels.$2),
      (ThemeMode.dark, labels.$3),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          for (final (mode, label) in entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(mode),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: mode == current
                        ? palette.accent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: AppRadius.cardMd,
                    border: Border.all(
                      color: mode == current
                          ? palette.accent
                          : palette.hairline,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: mode == current ? palette.accent : palette.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Two-option Monday/Sunday toggle for which day starts the week — drives
/// the month grid, year mini-grids, and the home screen's weekly stats card.
class _WeekStartRow extends StatelessWidget {
  const _WeekStartRow({
    required this.weekStartsMonday,
    required this.l10n,
    required this.onChanged,
  });

  final bool weekStartsMonday;
  final AppL10n l10n;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final entries = [
      (true, l10n.settingsWeekStartMonday),
      (false, l10n.settingsWeekStartSunday),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.settingsWeekStart,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          for (final (monday, label) in entries)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: GestureDetector(
                onTap: () => onChanged(monday),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: monday == weekStartsMonday
                        ? palette.accent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: AppRadius.cardMd,
                    border: Border.all(
                      color: monday == weekStartsMonday
                          ? palette.accent
                          : palette.hairline,
                    ),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: monday == weekStartsMonday
                          ? palette.accent
                          : palette.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// How long a completed to-do sticks around before
/// `TodoController.pruneCompleted` deletes it for good — off by default
/// (see `AppSettings.completedTodoRetentionDays`), same pill-row shape as
/// [_WeekStartRow].
class _TodoRetentionRow extends StatelessWidget {
  const _TodoRetentionRow({
    required this.days,
    required this.l10n,
    required this.onChanged,
  });

  final int? days;
  final AppL10n l10n;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final entries = <(int?, String)>[
      (null, l10n.settingsTodoRetentionOff),
      (7, l10n.settingsTodoRetentionDays(7)),
      (30, l10n.settingsTodoRetentionDays(30)),
      (90, l10n.settingsTodoRetentionDays(90)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsTodoRetention, style: theme.textTheme.bodyLarge),
          Text(
            l10n.settingsTodoRetentionDesc,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.inkFaint),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final (value, label) in entries)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(value),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: value == days
                            ? palette.accent.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: AppRadius.cardMd,
                        border: Border.all(
                          color: value == days
                              ? palette.accent
                              : palette.hairline,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: value == days
                              ? palette.accent
                              : palette.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Navigates to [CalendarPickerScreen], showing the currently-resolved
/// sync target's name (or a hint to turn sync on first, while it's off).
class _CalendarTargetRow extends ConsumerWidget {
  const _CalendarTargetRow({
    required this.enabled,
    required this.l10n,
    required this.onTap,
  });

  final bool enabled;
  final AppL10n l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final nameAsync = ref.watch(targetCalendarNameProvider);
    final subtitle = !enabled
        ? l10n.settingsCalendarTargetDisabledHint
        : (nameAsync.asData?.value ?? l10n.settingsCalendarTargetAuto);

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsCalendarTarget,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows when CalendarReconciler last completed a sync pass — surfaces a
/// silently-broken sync (e.g. calendar permission revoked in OS settings
/// after the fact) instead of leaving the toggle looking "on" forever with
/// nothing actually happening behind it.
class _LastSyncRow extends ConsumerWidget {
  const _LastSyncRow({required this.l10n});
  final AppL10n l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final lastSync = ref.watch(lastCalendarSyncAtProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.settingsLastSync,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Text(
            lastSync == null
                ? l10n.settingsLastSyncNever
                : '${Fmt.monthDay(lastSync, locale)}  ${Fmt.time(lastSync, locale)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Android-only exact-alarm permission affordance. Hidden where not relevant.
class _ExactAlarmRow extends ConsumerStatefulWidget {
  const _ExactAlarmRow({required this.l10n});
  final AppL10n l10n;

  @override
  ConsumerState<_ExactAlarmRow> createState() => _ExactAlarmRowState();
}

class _ExactAlarmRowState extends ConsumerState<_ExactAlarmRow> {
  bool? _canExact;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final can = await ref.read(notificationServiceProvider).canScheduleExact();
    if (mounted) setState(() => _canExact = can);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final l10n = widget.l10n;
    final granted = _canExact ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.settingsExactAlarm, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  granted
                      ? l10n.settingsPermissionGranted
                      : l10n.settingsExactAlarmDesc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: granted ? palette.accent : palette.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          if (!granted)
            TextButton(
              onPressed: () async {
                await ref
                    .read(notificationServiceProvider)
                    .requestExactAlarmPermission();
                await _refresh();
              },
              child: Text(l10n.settingsGrant),
            ),
        ],
      ),
    );
  }
}
