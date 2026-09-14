import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/db/event_row_x.dart';
import '../../../../core/format.dart';
import '../../../../core/maps_launcher.dart';
import '../../../../core/time_format.dart';
import '../../../../design/glass/glass_nav_bar.dart'
    show navBarClearance;
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../../design/widgets/adaptive_bottom_sheet.dart';
import '../../../../design/widgets/snackbar_x.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/application/app_settings.dart';
import '../../../settings/application/settings_controller.dart';
import 'event_editor_sheet.dart';

/// Opens a read-only preview of [event] — the tap target for an *existing*
/// event everywhere in the app now (day/week/month/agenda/home/search/day-
/// clock — see each call site's own doc comment). A long-press on any of
/// those same tiles skips this sheet entirely and calls [showEventEditor]
/// directly, which is also the sheet's own "편집" button's route back to the
/// full form.
///
/// [showEventEditor] itself opens this (never the editable form) for an
/// event mirrored in from a subscribed/holiday calendar — see this widget's
/// own `_isMirrored` doc. That's the only other path that reaches this sheet,
/// and it's why this file — not the retired `mirrored_event_detail_screen.dart`,
/// whose row layout and read-only copy now live on in this sheet's mirrored
/// branch — is the single "look at this event" surface the whole app funnels
/// through.
Future<void> showEventPreview(BuildContext context, {required EventRow event}) {
  return showAdaptiveBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => EventPreviewSheet(event: event),
  );
}

class EventPreviewSheet extends ConsumerWidget {
  const EventPreviewSheet({super.key, required this.event});

  final EventRow event;

  /// An event mirrored in from a subscribed device calendar or a holiday
  /// calendar (both pulled in read-only — see CalendarImportService's and
  /// HolidayCalendarService's own docs) never gets an "편집" button here:
  /// saving an edit would try to push it back out to a calendar PlanFit
  /// doesn't own, which is exactly what must never happen for either kind.
  bool get _isMirrored => event.importSourceCalendarId != null;

  /// Holidays are mirrored the same way a subscribed calendar is (shared
  /// `importSourceCalendarId` machinery), but "구독 중" reads oddly for a
  /// national-holiday calendar — matches on the shared `'holiday:'` prefix
  /// both the country (`holiday:country:KR`) and custom source-id shapes
  /// start with, same check `MirroredEventDetailScreen` used to make.
  bool get _isHoliday =>
      (event.importSourceCalendarId ?? '').startsWith('holiday:');

  Future<void> _openInMaps(
    BuildContext context,
    AppL10n l10n,
    MapsAppPreference mapsAppPreference,
  ) async {
    final query = event.location?.trim() ?? '';
    if (query.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final uri = buildMapsSearchUri(
      query: query,
      preference: mapsAppPreference,
      isIOS: Platform.isIOS,
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('launchUrl returned false');
    } catch (_) {
      if (!context.mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.eventOpenInMapsFailed)),
      );
    }
  }

  void _openEditor(BuildContext context) {
    // Same "capture the Navigator's own (root) context before popping"
    // pattern as EventEditorSheet._duplicate — this sheet's own context is
    // about to be unmounted by the pop below, so pushing the editor through
    // it instead of the Navigator's context would push onto a route that's
    // mid-teardown.
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    navigator.pop();
    showEventEditor(rootContext, existing: event);
  }

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
    final mapsAppPreference = ref.watch(
      settingsControllerProvider.select((s) => s.mapsAppPreference),
    );
    final accent = EventColorTag.resolve(event.colorTag, event.startAt);
    final textAccent = legibleOn(palette.surface, accent);
    final hasLocation = (event.location ?? '').isNotEmpty;
    final hasMemo = (event.memo ?? '').isNotEmpty;

    final infoRows = <Widget>[
      _InfoRow(
        icon: Icons.schedule_rounded,
        color: palette.inkFaint,
        child: Text(
          event.isAllDay
              ? Fmt.fullDate(event.startAt, locale)
              : '${Fmt.fullDate(event.startAt, locale)}\n'
                    '${Fmt.time(event.startAt, locale, use24Hour: use24)} – '
                    '${Fmt.time(event.endAt, locale, use24Hour: use24)}',
          style: theme.textTheme.bodyLarge?.copyWith(color: palette.inkSoft),
        ),
      ),
      if (hasLocation)
        _InfoRow(
          icon: Icons.place_outlined,
          color: palette.inkFaint,
          child: InkWell(
            onTap: () => _openInMaps(context, l10n, mapsAppPreference),
            child: Text(
              event.location!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: textAccent,
                decoration: TextDecoration.underline,
                decorationColor: textAccent,
              ),
            ),
          ),
        ),
      if (hasMemo)
        _InfoRow(
          icon: Icons.notes_rounded,
          color: palette.inkFaint,
          child: Text(event.memo!, style: theme.textTheme.bodyMedium),
        ),
      if (event.recurrenceGroupId != null)
        _InfoRow(
          icon: Icons.repeat_rounded,
          color: palette.inkFaint,
          child: Text(
            l10n.eventRepeat,
            style: theme.textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
          ),
        ),
      _InfoRow(
        icon: event.notify
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        color: palette.inkFaint,
        child: event.notify
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final offset in event.reminderOffsets)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: offset == event.reminderOffsets.last
                            ? 0
                            : AppSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eventReminderLeadTimeLabel(l10n, offset),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.inkSoft,
                            ),
                          ),
                          // The label alone ("정시", "1시간 전") is relative
                          // to the event's own start — a small absolute
                          // clock time underneath is what actually answers
                          // "so when does it go off", without the reader
                          // doing that subtraction in their head themselves.
                          Text(
                            Fmt.time(
                              event.startAt.subtract(Duration(minutes: offset)),
                              locale,
                              use24Hour: use24,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            : Text(
                l10n.eventNotifyOff,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.inkSoft,
                ),
              ),
      ),
    ];

    // MediaQueryData.fromView, not MediaQuery.paddingOf(context) — this
    // widget is built as a ModalBottomSheetRoute's content, and Flutter's
    // own bottom-sheet machinery wraps that content with
    // `MediaQuery.removePadding(removeTop: true, ...)` (bottom sheets are
    // assumed to only ever care about the bottom inset, e.g. the keyboard),
    // so `MediaQuery.paddingOf(context).top` in here reads 0 (or some other
    // ancestor-dependent, unreliable value — confirmed live on an iOS
    // simulator: a first attempt at capturing it from the *calling*
    // context, before this sheet ever opened, still came out far smaller
    // than the device's real inset, for reasons that trace back to the
    // same class of MediaQuery-stripping). Going straight to the platform
    // view sidesteps all of that — it's always the true, un-stripped
    // device inset, regardless of what any ancestor in the widget tree
    // has done to the inherited MediaQuery.
    final topSafeAreaInset = MediaQueryData.fromView(
      View.of(context),
    ).padding.top;
    // A modal bottom sheet always docks its content flush to the true
    // screen bottom, growing upward as content needs — this sheet's own
    // short, shrink-wrapped content (see the Flexible/SingleChildScrollView
    // doc below) left a large, starkly empty block of this Container's own
    // solid-white background sitting directly above the floating glass tab
    // bar, with the "편집하기" button stranded well above it — confirmed
    // live on an iOS simulator as reading like broken/unstyled leftover
    // space, not a deliberate margin. Reserving the tab-bar clearance as an
    // *outer margin* below the whole card instead — so the dimmed backdrop
    // shows through that gap rather than this card's own solid color —
    // turns it into an ordinary "floating card has room around it" look
    // instead of a dead rectangle glued to the card's own bottom edge.
    final bottomMargin =
        MediaQuery.viewInsetsOf(context).bottom + navBarClearance(context);
    // A flat percentage of screen height (e.g. 0.85) ignores the top inset
    // entirely — on a tall enough sheet that cap alone let the sheet's top
    // edge land right under (or straddling) the notch/Dynamic Island
    // instead of clearing it. Anchoring the cap to the real top inset (plus
    // a small margin) and subtracting [bottomMargin] too guarantees the
    // whole card — including the outer margin below it — always fits
    // between the notch and the floating tab bar, on any device.
    final maxSheetHeight =
        MediaQuery.sizeOf(context).height -
        topSafeAreaInset -
        AppSpacing.xl -
        bottomMargin;

    // A plain, fully opaque solid-color sheet — no GlassSurface/blur/tint/
    // highlight-gradient anywhere in this popup. showAdaptiveBottomSheet
    // itself is called with backgroundColor: Colors.transparent (matching
    // every other sheet's convention), so *this* Container is the only
    // thing painting a background at all; without it, whatever screen sits
    // behind shows straight through — same fix todo_detail_sheet.dart's own
    // root Container already relies on. The maxHeight cap plus the
    // Flexible/SingleChildScrollView body below mean a long memo or a lot
    // of detail never gets clipped, just scrolled — without forcing the
    // sheet to that same height when there's nothing that tall to show.
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomMargin),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.all(AppRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(
                        top: 6,
                        right: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title.isEmpty ? '—' : event.title,
                            style: theme.textTheme.titleLarge,
                          ),
                          if (_isMirrored)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _isHoliday
                                    ? l10n.holidayEventBadge
                                    : l10n.calendarImportSubscribedHint,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: palette.inkFaint,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: l10n.commonCancel,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Flexible, not Expanded: Expanded's tight fit forces this
              // region to consume every pixel of the leftover space inside
              // the maxHeight-capped Column regardless of how little content
              // it actually holds — confirmed live on an iOS simulator as a
              // huge dead-space gap between the last info row and the footer
              // below, pushing the edit button far lower than the content
              // ever needed. A loose-fit Flexible lets the Column genuinely
              // shrink-wrap short content (its own mainAxisSize.min intent)
              // while still capping — and making scrollable — this region
              // whenever real content is too tall to fit.
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.xs,
                    AppSpacing.gutter,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < infoRows.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: AppSpacing.lg,
                            color: palette.hairline,
                          ),
                        infoRows[i],
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xs,
                  AppSpacing.gutter,
                  AppSpacing.lg,
                ),
                child: _isMirrored
                    ? Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: AppRadius.cardMd,
                          border: Border.all(color: palette.hairline),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: palette.inkFaint,
                            ),
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
                      )
                    : FilledButton.icon(
                        onPressed: () => _openEditor(context),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.eventPreviewEditButton),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: bestTextOn(
                            accent,
                            dark: palette.ink,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.cardMd,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A leading-icon + content row — the same shape
/// `MirroredEventDetailScreen`'s time/location rows used, promoted here as
/// this sheet's own repeated pattern (time/location/memo/repeat all use it)
/// rather than copy-pasting the `Row(children: [Icon(...), ..., Expanded(...)])`
/// four times.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: child),
      ],
    );
  }
}
