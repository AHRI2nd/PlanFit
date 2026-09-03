import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar_sync/holiday_calendar_service.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/tokens/event_color_tag.dart';
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

  /// Returned by [_pickColor] when the user chose "기본값"/"Default" —
  /// distinct from `null`, which means the dialog was dismissed without any
  /// choice at all. Never collides with a real color: [EventColorTag.toHex]
  /// always starts with `#`.
  static const String _defaultColorToken = '__default__';

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

  Future<void> _changeCountryColor(String countryCode, String? currentHex) =>
      _changeColor(
        currentHex,
        (hex) => ref
            .read(settingsControllerProvider.notifier)
            .setHolidayCountryColor(countryCode, colorHex: hex),
      );

  Future<void> _changeCustomColor(String url, String? currentHex) =>
      _changeColor(
        currentHex,
        (hex) => ref
            .read(settingsControllerProvider.notifier)
            .setCustomHolidayColor(url, colorHex: hex),
      );

  /// Shared flow behind [_changeCountryColor]/[_changeCustomColor]: shows
  /// the picker, then applies the result via [apply] (`colorHex: null`
  /// clears back to the default) — same busy-overlay + sync-failure-snackbar
  /// handling every other change on this screen already uses.
  Future<void> _changeColor(
    String? currentHex,
    Future<void> Function(String? colorHex) apply,
  ) async {
    final picked = await _pickColor(currentHex);
    if (picked == null || !mounted) return; // dialog dismissed, or unmounted
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await apply(picked == _defaultColorToken ? null : picked);
    } on HolidayCalendarSyncException {
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.holidayCalendarSourceSyncFailedGeneric)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A row of quick swatches — the default holiday color, the app's 4
  /// "day's arc" [EventColorTag] presets (indigo/sky/amber/violet — see
  /// that enum's declaration order and [AppColors]'s own doc on which
  /// hues are the core family vs. "extra"), and a "custom" swatch opening
  /// the full palette ([_pickCustomPaletteColor]) for those or anything
  /// else. Deliberately capped at 5 swatches + custom = 6 total: any more
  /// and the row needs a horizontal scroll to see them all, which on a
  /// phone-width dialog reliably fills with exactly this many swatches —
  /// so scrolling was never discoverable and "custom" (previously past the
  /// 6th slot, alongside the 2 dropped presets) went unseen entirely.
  /// Returns a `#RRGGBB` hex, [_defaultColorToken], or null if dismissed
  /// without a choice.
  Future<String?> _pickColor(String? currentHex) {
    final l10n = AppL10n.of(context);
    final quickPresetHexes = EventColorTag.values
        .take(4)
        .map((tag) => EventColorTag.toHex(tag.color))
        .toSet();
    // A source whose color is already set to something outside the 5 quick
    // swatches above (the default, or one of the 4 presets) — reachable
    // either from before this dialog was capped to 4 presets, or today via
    // "custom"'s own full palette, which still lets rose/sage (or anything
    // else) be picked directly. Without this, reopening the dialog on such
    // a source showed no checkmark anywhere at all: none of the 5 fixed
    // swatches match its real hex, and the custom swatch itself never had
    // a selected state, so an actively-set color visually read as "nothing
    // chosen".
    final customColor = currentHex != null && !quickPresetHexes.contains(currentHex)
        ? EventColorTag.parseHex(currentHex)
        : null;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.holidayCalendarSourceColorTitle),
        content: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ColorChoice(
                key: const Key('colorChoice-default'),
                color: AppColors.holidayRed,
                selected: currentHex == null,
                semanticLabel: l10n.holidayCalendarSourceColorDefault,
                onTap: () =>
                    Navigator.of(dialogContext).pop(_defaultColorToken),
              ),
              for (final tag in EventColorTag.values.take(4))
                _ColorChoice(
                  key: Key('colorChoice-${tag.name}'),
                  color: tag.color,
                  selected: currentHex == EventColorTag.toHex(tag.color),
                  semanticLabel: tag.name,
                  onTap: () => Navigator.of(
                    dialogContext,
                  ).pop(EventColorTag.toHex(tag.color)),
                ),
              _CustomColorChoice(
                key: const Key('colorChoice-custom'),
                color: customColor,
                semanticLabel: l10n.eventColorPickerTitle,
                onTap: () async {
                  final custom = await _pickCustomPaletteColor(
                    dialogContext,
                    EventColorTag.parseHex(currentHex) ?? AppColors.holidayRed,
                  );
                  if (custom != null && dialogContext.mounted) {
                    Navigator.of(
                      dialogContext,
                    ).pop(EventColorTag.toHex(custom));
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  /// The full-palette picker — same widget and shape as
  /// `EventEditorSheet._pickCustomColor`. [context] is the still-mounted
  /// swatch-row dialog's own context (this one nests on top of it, rather
  /// than replacing it).
  Future<Color?> _pickCustomPaletteColor(BuildContext context, Color initial) {
    final l10n = AppL10n.of(context);
    var working = initial;
    return showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.eventColorPickerTitle),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: working,
            onColorChanged: (c) => working = c,
            enableAlpha: false,
            hexInputBar: true,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(working),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SourceColorDot(
                        color:
                            EventColorTag.parseHex(
                              settings
                                  .holidaySourceColors[holidayCustomSourceId(
                                url,
                              )],
                            ) ??
                            AppColors.holidayRed,
                        tooltip: l10n.holidayCalendarSourceColorTooltip,
                        onTap: _busy
                            ? null
                            : () => _changeCustomColor(
                                url,
                                settings
                                    .holidaySourceColors[holidayCustomSourceId(
                                  url,
                                )],
                              ),
                      ),
                      IconButton(
                        tooltip: l10n.holidayCalendarSourceRemoveCustomUrl,
                        icon: Icon(Icons.close, color: palette.inkFaint),
                        onPressed: _busy ? null : () => _removeCustomUrl(url),
                      ),
                    ],
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
                  secondary: _SourceColorDot(
                    color:
                        EventColorTag.parseHex(
                          settings.holidaySourceColors[holidayCountrySourceId(
                            countryCode,
                          )],
                        ) ??
                        AppColors.holidayRed,
                    tooltip: l10n.holidayCalendarSourceColorTooltip,
                    onTap: _busy
                        ? null
                        : () => _changeCountryColor(
                            countryCode,
                            settings.holidaySourceColors[holidayCountrySourceId(
                              countryCode,
                            )],
                          ),
                  ),
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

/// The small color circle on each source row — tapping it opens
/// [_HolidayCalendarSourceScreenState._pickColor] for that one source. A
/// plain [IconButton] (not a bare [GestureDetector]) so it gets Material's
/// own tap target sizing/ripple and, nested inside a [ListTile]/
/// [CheckboxListTile], reliably claims taps on itself without the row's own
/// tap (toggling the checkbox, opening the row) firing instead — the same
/// nested-IconButton-inside-a-ListTile shape this screen's own "remove"
/// button already relies on.
class _SourceColorDot extends StatelessWidget {
  const _SourceColorDot({
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: palette.hairline),
        ),
      ),
    );
  }
}

/// One preset swatch inside [_HolidayCalendarSourceScreenState._pickColor]'s
/// dialog — visually mirrors `event_editor_sheet.dart`'s own `_Swatch`
/// (kept as a separate, private copy here rather than shared, since that
/// one is tangled up with the event editor's extra "automatic" time-gradient
/// option, which doesn't apply to a holiday source).
class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    super.key,
    required this.color,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: selected ? palette.ink : Colors.transparent,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        ),
      ),
    );
  }
}

/// The "custom color" swatch — opens the full palette picker instead of
/// picking a color directly, same role as `event_editor_sheet.dart`'s own
/// `_PaletteSwatch`, including that one's "already has a value" styling:
/// [color] non-null (the current hex doesn't match any of the fixed
/// swatches next to this one) fills the circle with it and shows a
/// checkmark, instead of leaving an actively-set custom color looking
/// indistinguishable from nothing being chosen at all.
class _CustomColorChoice extends StatelessWidget {
  const _CustomColorChoice({
    super.key,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
  });

  final Color? color;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = color != null;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected ? palette.ink : palette.hairline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Icon(
            selected ? Icons.check : Icons.palette_outlined,
            size: 18,
            color: selected ? Colors.white : palette.inkSoft,
          ),
        ),
      ),
    );
  }
}
