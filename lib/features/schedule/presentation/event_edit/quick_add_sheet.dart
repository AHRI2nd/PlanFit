import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di.dart';
import '../../../../core/format.dart';
import '../../../../core/quick_add/quick_add_parser.dart';
import '../../../../core/time_format.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../../design/glass/glass_nav_bar.dart'
    show navBarControlClearance;
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/widgets/adaptive_bottom_sheet.dart';
import '../../../../design/widgets/snackbar_x.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/event_input.dart';

/// A one-line free-text entry point for creating an event straight from a
/// phrase like "내일 오후 3시 회의" — [parseQuickAdd] pulls the date/time
/// out and only the remaining text becomes the title. Anything it can't
/// recognize (no date, no time, or both) still creates the event, just
/// anchored on [anchorDay] at a default hour — never worse than typing the
/// same text into the plain title field of the full editor.
Future<void> showQuickAddEvent(
  BuildContext context, {
  required DateTime anchorDay,
}) {
  return showAdaptiveBottomSheet<void>(
    context: context,
    builder: (_) => QuickAddEventSheet(anchorDay: anchorDay),
  );
}

class QuickAddEventSheet extends ConsumerStatefulWidget {
  const QuickAddEventSheet({super.key, required this.anchorDay});

  final DateTime anchorDay;

  @override
  ConsumerState<QuickAddEventSheet> createState() => _QuickAddEventSheetState();
}

class _QuickAddEventSheetState extends ConsumerState<QuickAddEventSheet> {
  final _controller = TextEditingController();
  String _draftText = '';
  ({String title, DateTime startAt, bool usedDefaultTime})? _draft;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final resolved = _draftText == text && _draft != null
        ? _draft!
        : _resolve(text);
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final day = DateUtils.dateOnly(resolved.startAt);
    final title = resolved.title;
    final startAt = resolved.startAt;
    final endAt = startAt.add(const Duration(hours: 1));

    setState(() => _saving = true);
    try {
      await ref
          .read(eventRepositoryProvider)
          .save(EventInput(title: title, startAt: startAt, endAt: endAt));
      if (!mounted) return;
      navigator.pop();
      final use24 = resolveUse24Hour(
        ref.read(
          settingsControllerProvider.select(
            (s) => s.displayTimeFormatPreference,
          ),
        ),
        context,
      );
      messenger.showAutoDismissSnackBar(
        SnackBar(
          content: Text(
            l10n.quickAddEventCreated(
              title,
              Fmt.monthDay(day, locale),
              Fmt.time(startAt, locale, use24Hour: use24),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  ({String title, DateTime startAt, bool usedDefaultTime}) _resolve(
    String text,
  ) {
    final parsed = parseQuickAdd(text, now: DateTime.now());
    final day = parsed.date ?? widget.anchorDay;
    final time = parsed.time ?? const TimeOfDay(hour: 9, minute: 0);
    return (
      title: parsed.title.isEmpty ? text : parsed.title,
      startAt: DateTime(day.year, day.month, day.day, time.hour, time.minute),
      usedDefaultTime: parsed.time == null,
    );
  }

  void _onChanged(String value) {
    final text = value.trim();
    setState(() {
      _draftText = text;
      _draft = text.isEmpty ? null : _resolve(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final draft = _draft;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        top: AppSpacing.sm,
        // The keyboard inset (when it's up, dwarfing the tab bar clearance
        // below) plus enough to clear the floating tab bar when it isn't —
        // see navBarClearance's own doc. Without this, the Save
        // button (this column's last element) sat directly behind the tab
        // bar with the keyboard down — not just visually hidden but
        // literally untappable, since the tab bar itself still consumed the
        // touch.
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            AppSpacing.lg +
            navBarControlClearance(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.quickAddEventTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.quickAddEventHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.inkFaint),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(hintText: l10n.quickAddEventExample),
          ),
          if (draft != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.quickAddEventPreview(
                Fmt.monthDay(draft.startAt, locale),
                Fmt.time(draft.startAt, locale, use24Hour: use24),
                Fmt.monthDay(
                  draft.startAt.add(const Duration(hours: 1)),
                  locale,
                ),
                Fmt.time(
                  draft.startAt.add(const Duration(hours: 1)),
                  locale,
                  use24Hour: use24,
                ),
              ),
              key: const Key('quick-add-event-preview'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (draft.usedDefaultTime)
              Text(
                l10n.quickAddEventDefaultTime,
                key: const Key('quick-add-event-default-time'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.inkFaint),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(l10n.eventSave),
            ),
          ),
        ],
      ),
    );
  }
}
