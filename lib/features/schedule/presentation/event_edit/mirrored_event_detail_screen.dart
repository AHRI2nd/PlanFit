import 'package:flutter/material.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/format.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Read-only detail view for an event mirrored in from a subscribed
/// calendar — see CalendarImportService's doc comment for why these are
/// never opened in the full [EventEditorSheet]: any edit that flowed
/// through `EventRepository.save` would try to push it back out somewhere,
/// which is exactly what a subscribed (often not even writable) calendar
/// must not trigger.
class MirroredEventDetailScreen extends StatelessWidget {
  const MirroredEventDetailScreen({super.key, required this.event});

  final EventRow event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendarImportSubscribedHint),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            Text(event.title.isEmpty ? '—' : event.title,
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: palette.inkFaint),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    event.isAllDay
                        ? Fmt.monthDay(event.startAt, locale)
                        : '${Fmt.monthDay(event.startAt, locale)}  '
                            '${Fmt.time(event.startAt, locale)} – '
                            '${Fmt.time(event.endAt, locale)}',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: palette.inkSoft),
                  ),
                ),
              ],
            ),
            if (event.location != null && event.location!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 18, color: palette.inkFaint),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(event.location!,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: palette.inkSoft)),
                  ),
                ],
              ),
            ],
            if (event.memo != null && event.memo!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(event.memo!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: AppRadius.cardMd,
                border: Border.all(color: palette.hairline),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: palette.inkFaint),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.calendarImportMirroredReadOnlyNote,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: palette.inkFaint),
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
