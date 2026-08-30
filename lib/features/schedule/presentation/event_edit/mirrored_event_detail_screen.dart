import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/format.dart';
import '../../../../core/time_format.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/application/settings_controller.dart';

/// Read-only detail view for an event mirrored in from a subscribed
/// calendar — see CalendarImportService's doc comment for why these are
/// never opened in the full [EventEditorSheet]: any edit that flowed
/// through `EventRepository.save` would try to push it back out somewhere,
/// which is exactly what a subscribed (often not even writable) calendar
/// must not trigger.
class MirroredEventDetailScreen extends ConsumerWidget {
  const MirroredEventDetailScreen({super.key, required this.event});

  final EventRow event;

  /// Holidays are mirrored in the exact same way as a subscribed device
  /// calendar (see HolidayCalendarService's doc), so they land on this same
  /// read-only screen — but "subscribed" reads oddly for a national-holiday
  /// calendar even though the user does now pick which one (a country, or a
  /// custom URL — see the holiday calendar source picker screen), hence the
  /// separate copy here. Matches on the shared `'holiday:'` prefix, which
  /// both the country (`holiday:country:KR`) and custom (`holiday:custom`)
  /// source-id shapes still start with.
  bool get _isHoliday =>
      (event.importSourceCalendarId ?? '').startsWith('holiday:');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      appBar: AppBar(
        title: Text(
          _isHoliday
              ? l10n.holidayEventBadge
              : l10n.calendarImportSubscribedHint,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            Text(
              event.title.isEmpty ? '—' : event.title,
              style: theme.textTheme.headlineSmall,
            ),
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
                              '${Fmt.time(event.startAt, locale, use24Hour: use24)} – '
                              '${Fmt.time(event.endAt, locale, use24Hour: use24)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: palette.inkSoft,
                    ),
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
                    child: Text(
                      event.location!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: palette.inkSoft,
                      ),
                    ),
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
                      _isHoliday
                          ? l10n.holidayEventReadOnlyNote
                          : l10n.calendarImportMirroredReadOnlyNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.inkFaint,
                      ),
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
