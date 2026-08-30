import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar_sync/holiday_calendar_service.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settings_controller.dart';
import 'settings_screen.dart' show holidayCountryDisplayName;

/// Lets the user pick which country's public holidays PlanFit mirrors, or
/// add a custom ICS URL instead — the picker screen `_HolidayCalendarSourceRow`
/// (settings_screen.dart) links to. Modeled directly on
/// [CalendarPickerScreen]'s "pick one of several options" shape, plus
/// [CalendarImportScreen]'s busy-overlay pattern for the network round trip
/// each selection triggers.
class HolidayCalendarSourceScreen extends ConsumerStatefulWidget {
  const HolidayCalendarSourceScreen({super.key});

  @override
  ConsumerState<HolidayCalendarSourceScreen> createState() =>
      _HolidayCalendarSourceScreenState();
}

class _HolidayCalendarSourceScreenState
    extends ConsumerState<HolidayCalendarSourceScreen> {
  bool _busy = false;

  Future<void> _selectCountry(String countryCode) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .setHolidayCountryCode(countryCode);
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
    if (parsed == null || !(parsed.isScheme('HTTP') || parsed.isScheme('HTTPS'))) {
      ScaffoldMessenger.of(context).showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.holidayCalendarSourceCustomInvalidUrl)),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .setCustomHolidayCalendarUrl(url);
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
    final customUrl = settings.customHolidayCalendarUrl;
    final countries = HolidayCalendarService.holidayCountryCalendarIds.keys
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.holidayCalendarSourceTitle)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              ListTile(
                leading: Icon(Icons.link, color: palette.inkFaint),
                title: Text(l10n.holidayCalendarSourceCustomEntry),
                subtitle: customUrl != null ? Text(customUrl) : null,
                trailing: customUrl != null
                    ? Icon(Icons.check, color: palette.accent)
                    : null,
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
                ListTile(
                  title: Text(holidayCountryDisplayName(l10n, countryCode)),
                  trailing:
                      customUrl == null &&
                          countryCode == settings.resolvedHolidayCountryCode
                      ? Icon(Icons.check, color: palette.accent)
                      : null,
                  onTap: _busy ? null : () => _selectCountry(countryCode),
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
