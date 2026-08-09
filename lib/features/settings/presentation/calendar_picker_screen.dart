import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';

/// Lets the user pick which writable device calendar PlanFit syncs events
/// to, instead of always silently auto-creating a "PlanFit" calendar.
class CalendarPickerScreen extends ConsumerWidget {
  const CalendarPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final settings = ref.watch(settingsControllerProvider);
    final calendarsAsync = ref.watch(writableCalendarsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCalendarTarget)),
      body: calendarsAsync.when(
        data: (calendars) {
          if (calendars.isEmpty) {
            return Center(
              child: Text(
                l10n.settingsCalendarTargetEmpty,
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
              final selected = calendar.id == settings.targetCalendarId;
              return ListTile(
                leading: Icon(Icons.circle,
                    size: 14, color: calendar.color ?? palette.inkFaint),
                title: Text(calendar.name),
                subtitle:
                    calendar.accountName != null
                        ? Text(calendar.accountName!)
                        : null,
                trailing:
                    selected ? Icon(Icons.check, color: palette.accent) : null,
                onTap: () async {
                  await ref
                      .read(settingsControllerProvider.notifier)
                      .setTargetCalendar(calendar.id);
                  if (context.mounted) context.pop();
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            l10n.settingsCalendarTargetEmpty,
            style: TextStyle(color: palette.inkFaint),
          ),
        ),
      ),
    );
  }
}
