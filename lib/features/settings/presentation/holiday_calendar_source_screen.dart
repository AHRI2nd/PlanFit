import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar_sync/holiday_calendar_service.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';
import 'settings_screen.dart' show holidayCountryDisplayName;

/// Lets the user pick any number of countries whose public holidays PlanFit
/// mirrors, plus any number of custom ICS URLs — every selection is
/// independent and additive, not a single either/or choice. Modeled on
/// [CalendarImportScreen]'s multi-subscribe shape (each row has its own
/// on/off state, several can be on at once) rather than
/// [CalendarPickerScreen]'s single-pick shape, plus that same screen's
/// busy-overlay pattern for the network round trip each toggle triggers.
class HolidayCalendarSourceScreen extends ConsumerStatefulWidget {
  const HolidayCalendarSourceScreen({super.key});

  @override
  ConsumerState<HolidayCalendarSourceScreen> createState() =>
      _HolidayCalendarSourceScreenState();
}

class _HolidayCalendarSourceScreenState
    extends ConsumerState<HolidayCalendarSourceScreen> {
  bool _busy = false;

  Future<void> _toggleCountry(String countryCode, bool selected) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .setHolidayCountrySelected(countryCode, selected);
    } on HolidayCalendarSyncException {
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.holidayCalendarSourceSyncFailedGeneric)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeCustomUrl(String url) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .removeCustomHolidayCalendarUrl(url);
    } on HolidayCalendarSyncException {
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.holidayCalendarSourceSyncFailedGeneric)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCustomUrl() async {
    final l10n = AppL10n.of(context);
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.holidayCalendarSourceCustomDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: l10n.holidayCalendarSourceCustomDialogHint,
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
    // Deferred, not disposed right here — the dialog's own exit animation
    // is still holding a reference to this controller's TextField for a few
    // more frames after showDialog's future resolves (Navigator.pop
    // completes the Future synchronously, well before the route's exit
    // transition actually finishes), so disposing immediately can tear it
    // down out from under a widget that's still (briefly) in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (url == null || url.isEmpty || !mounted) return;

    // Local scheme check before ever touching the network — a URL that
    // can't even parse as http/https is never worth a round trip for.
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        !(parsed.isScheme('HTTP') || parsed.isScheme('HTTPS'))) {
      ScaffoldMessenger.of(context).showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.holidayCalendarSourceCustomInvalidUrl)),
      );
      return;
    }
    if (ref
        .read(settingsControllerProvider)
        .customHolidayCalendarUrls
        .contains(url)) {
      // Already added — nothing to do, and re-syncing wouldn't be wrong,
      // just pointless network traffic for a no-op.
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .addCustomHolidayCalendarUrl(url);
    } on HolidayCalendarSyncException {
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.holidayCalendarSourceSyncFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final settings = ref.watch(settingsControllerProvider);
    final customUrls = settings.customHolidayCalendarUrls.toList()..sort();
    final countries = HolidayCalendarService.holidayCountryCalendarIds.keys
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.holidayCalendarSourceTitle)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              for (final url in customUrls)
                ListTile(
                  leading: Icon(Icons.link, color: palette.inkFaint),
                  title: Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: l10n.holidayCalendarSourceRemoveCustomUrl,
                    icon: Icon(Icons.close, color: palette.inkFaint),
                    onPressed: _busy ? null : () => _removeCustomUrl(url),
                  ),
                ),
              ListTile(
                leading: Icon(Icons.add_link, color: palette.accent),
                title: Text(
                  l10n.holidayCalendarSourceCustomEntry,
                  style: TextStyle(color: palette.accent),
                ),
                onTap: _busy ? null : _addCustomUrl,
              ),
              Divider(height: 1, color: palette.hairline),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.xxs,
                ),
                child: Text(
                  l10n.holidayCalendarSourceSectionCountries,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: palette.inkFaint),
                ),
              ),
              for (final countryCode in countries)
                CheckboxListTile(
                  title: Text(holidayCountryDisplayName(l10n, countryCode)),
                  value: settings.holidayCountryCodes.contains(countryCode),
                  activeColor: palette.accent,
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: _busy
                      ? null
                      : (selected) =>
                            _toggleCountry(countryCode, selected ?? false),
                ),
            ],
          ),
          if (_busy)
            Container(
              // palette.ink, not a hardcoded black — same reasoning as
              // CalendarImportScreen's own busy overlay: reads clearly
              // against this theme's background in both light and dark.
              color: palette.ink.withValues(alpha: 0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
