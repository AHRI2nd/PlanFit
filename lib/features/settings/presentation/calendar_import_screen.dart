import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';

/// Lets the user pick a device calendar (including read-only feeds — this
/// only ever reads from them) and either copy its events into PlanFit once,
/// or subscribe to it for continuous mirroring (see
/// CalendarImportService's doc comment for what "subscribe" means and why
/// it's deliberately one-directional/read-only).
class CalendarImportScreen extends ConsumerStatefulWidget {
  const CalendarImportScreen({super.key});

  @override
  ConsumerState<CalendarImportScreen> createState() =>
      _CalendarImportScreenState();
}

class _CalendarImportScreenState extends ConsumerState<CalendarImportScreen> {
  bool _busy = false;

  Future<bool> _ensureAccess() async {
    final granted = await ref.read(calendarServiceProvider).requestAccess();
    return granted && mounted;
  }

  Future<void> _import(String calendarId, String calendarName) async {
    final l10n = AppL10n.of(context);
    if (!await _ensureAccess() || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.calendarImportConfirmTitle(calendarName)),
        content: Text(l10n.calendarImportConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.calendarImportConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final count = await ref
          .read(calendarImportServiceProvider)
          .importFrom(
            calendarId,
            from: DateTime.now().subtract(const Duration(days: 30)),
            to: DateTime.now().add(const Duration(days: 365)),
          );
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.calendarImportSuccess(count))),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.calendarImportFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setSubscribed(String calendarId, bool subscribed) async {
    if (subscribed && !await _ensureAccess()) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .setCalendarSubscribed(calendarId, subscribed);
    } catch (_) {
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(AppL10n.of(context).calendarImportFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final calendarsAsync = ref.watch(importSourceCalendarsProvider);
    final subscribed = ref.watch(
      settingsControllerProvider.select((s) => s.subscribedCalendarIds),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarImportTitle)),
      body: Stack(
        children: [
          calendarsAsync.when(
            data: (calendars) {
              if (calendars.isEmpty) {
                return Center(
                  child: Text(
                    l10n.calendarImportEmpty,
                    style: TextStyle(color: palette.inkFaint),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: calendars.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: palette.hairline),
                itemBuilder: (context, i) {
                  final calendar = calendars[i];
                  final isSubscribed = subscribed.contains(calendar.id);
                  return ListTile(
                    leading: Icon(
                      Icons.circle,
                      size: 14,
                      color: calendar.color ?? palette.inkFaint,
                    ),
                    title: Text(calendar.name),
                    subtitle: Text(
                      isSubscribed
                          ? l10n.calendarImportSubscribedHint
                          : calendar.accountName ?? '',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.calendarImportConfirmAction,
                          icon: const Icon(Icons.file_download_outlined),
                          onPressed: _busy || isSubscribed
                              ? null
                              : () => _import(calendar.id, calendar.name),
                        ),
                        Switch(
                          value: isSubscribed,
                          onChanged: _busy
                              ? null
                              : (v) => _setSubscribed(calendar.id, v),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Text(
                l10n.calendarImportEmpty,
                style: TextStyle(color: palette.inkFaint),
              ),
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(l10n.calendarImportInProgress),
                      ],
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
