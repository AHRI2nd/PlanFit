import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import '../../../core/di.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../../design/glass/glass_nav_bar.dart' show navBarClearance;
import '../../../design/widgets/async_content.dart';
import '../../../l10n/app_localizations.dart';
import '../application/integration_health.dart';
import '../application/settings_controller.dart';

class IntegrationStatusScreen extends ConsumerStatefulWidget {
  const IntegrationStatusScreen({super.key});
  @override
  ConsumerState<IntegrationStatusScreen> createState() =>
      _IntegrationStatusScreenState();
}

class _IntegrationStatusScreenState
    extends ConsumerState<IntegrationStatusScreen>
    with WidgetsBindingObserver {
  IntegrationFeature? _working;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(integrationHealthProvider);
    }
  }

  Future<void> _act(IntegrationHealth item) async {
    if (_working != null) return;
    setState(() => _working = item.feature);
    try {
      if (item.state == IntegrationState.needsPermission) {
        if (item.feature == IntegrationFeature.exactAlarms) {
          await ref
              .read(notificationServiceProvider)
              .requestExactAlarmPermission();
        } else {
          await openAppSettings();
        }
      } else {
        switch (item.feature) {
          case IntegrationFeature.calendar:
            await ref.read(calendarReconcilerProvider).reconcile();
            if (mounted) {
              await ref
                  .read(lastCalendarSyncAtProvider.notifier)
                  .record(DateTime.now());
            }
          case IntegrationFeature.reminders:
            if (item.state == IntegrationState.needsTarget) {
              ref.read(remindersServiceProvider).targetListId = null;
            }
            await ref.read(remindersReconcilerProvider).reconcile();
            if (mounted) {
              await ref
                  .read(lastRemindersSyncAtProvider.notifier)
                  .record(DateTime.now());
            }
          case IntegrationFeature.backup:
            await ref.read(autoBackupServiceProvider).runIfDue(force: true);
          case IntegrationFeature.notifications:
          case IntegrationFeature.exactAlarms:
            await openAppSettings();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.of(context).errorWidgetFallback)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _working = null);
        ref.invalidate(integrationHealthProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final health = ref.watch(integrationHealthProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );
    String feature(IntegrationFeature value) => switch (value) {
      IntegrationFeature.notifications => l10n.settingsNotifications,
      IntegrationFeature.exactAlarms => l10n.healthExactAlarms,
      IntegrationFeature.calendar => l10n.settingsCalendar,
      IntegrationFeature.reminders => l10n.settingsReminderSync,
      IntegrationFeature.backup => l10n.autoBackupTitle,
    };
    String state(IntegrationState value) => switch (value) {
      IntegrationState.off => l10n.healthOff,
      IntegrationState.needsPermission => l10n.healthPermission,
      IntegrationState.needsTarget => l10n.healthTarget,
      IntegrationState.ready => l10n.healthReady,
      IntegrationState.pending => l10n.healthPending,
      IntegrationState.unavailable => l10n.healthUnavailable,
      IntegrationState.failed => l10n.healthFailed,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.healthTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(integrationHealthProvider),
          ),
        ],
      ),
      body: AsyncContent<List<IntegrationHealth>>(
        value: health,
        onRetry: () => ref.invalidate(integrationHealthProvider),
        builder: (items) => ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, navBarClearance(context)),
          children: [
            Text(l10n.healthDescription),
            if (_working != null) const LinearProgressIndicator(),
            for (final item in items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature(item.feature),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(state(item.state)),
                      if (item.pendingCount > 0)
                        Text(l10n.healthPendingCount(item.pendingCount)),
                      if (item.lastPass != null)
                        Text(
                          l10n.healthLastPass(
                            '${Fmt.monthDay(item.lastPass!, locale)} ${Fmt.time(item.lastPass!, locale, use24Hour: use24)}',
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if ({
                            IntegrationState.needsPermission,
                            IntegrationState.needsTarget,
                            IntegrationState.pending,
                            IntegrationState.failed,
                          }.contains(item.state))
                            TextButton(
                              key: Key('health-${item.feature.name}-action'),
                              onPressed: _working != null
                                  ? null
                                  : () => _act(item),
                              child: Text(
                                item.state == IntegrationState.needsPermission
                                    ? l10n.settingsOpenAppSettings
                                    : l10n.healthRunNow,
                              ),
                            ),
                          if (item.state == IntegrationState.off)
                            TextButton(
                              onPressed: () =>
                                  GoRouter.maybeOf(context)?.go('/settings'),
                              child: Text(l10n.settingsTitle),
                            ),
                          if (item.feature == IntegrationFeature.calendar) ...[
                            TextButton(
                              onPressed: () => GoRouter.maybeOf(
                                context,
                              )?.go('/settings/calendar-picker'),
                              child: Text(l10n.healthChooseTarget),
                            ),
                            TextButton(
                              onPressed: () => GoRouter.maybeOf(
                                context,
                              )?.go('/settings/sync-log'),
                              child: Text(l10n.settingsSyncLog),
                            ),
                          ],
                          if (item.feature == IntegrationFeature.backup)
                            TextButton(
                              onPressed: () => GoRouter.maybeOf(
                                context,
                              )?.go('/settings/auto-backup'),
                              child: Text(l10n.healthHistory),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
