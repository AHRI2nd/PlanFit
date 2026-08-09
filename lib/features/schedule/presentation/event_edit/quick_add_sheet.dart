import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di.dart';
import '../../../../core/format.dart';
import '../../../../core/quick_add/quick_add_parser.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/event_input.dart';

/// A one-line free-text entry point for creating an event straight from a
/// phrase like "내일 오후 3시 회의" — [parseQuickAdd] pulls the date/time
/// out and only the remaining text becomes the title. Anything it can't
/// recognize (no date, no time, or both) still creates the event, just
/// anchored on [anchorDay] at a default hour — never worse than typing the
/// same text into the plain title field of the full editor.
Future<void> showQuickAddEvent(BuildContext context, {required DateTime anchorDay}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => QuickAddEventSheet(anchorDay: anchorDay),
  );
}

class QuickAddEventSheet extends ConsumerStatefulWidget {
  const QuickAddEventSheet({super.key, required this.anchorDay});

  final DateTime anchorDay;

  @override
  ConsumerState<QuickAddEventSheet> createState() =>
      _QuickAddEventSheetState();
}

class _QuickAddEventSheetState extends ConsumerState<QuickAddEventSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final parsed = parseQuickAdd(text, now: DateTime.now());
    final day = parsed.date ?? widget.anchorDay;
    final time = parsed.time ?? const TimeOfDay(hour: 9, minute: 0);
    final title = parsed.title.isEmpty ? text : parsed.title;
    final startAt =
        DateTime(day.year, day.month, day.day, time.hour, time.minute);
    final endAt = startAt.add(const Duration(hours: 1));

    setState(() => _saving = true);
    try {
      await ref.read(eventRepositoryProvider).save(EventInput(
            title: title,
            startAt: startAt,
            endAt: endAt,
          ));
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.quickAddEventCreated(
          title,
          Fmt.monthDay(day, locale),
          Fmt.time(startAt, locale),
        )),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.quickAddEventTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.quickAddEventHint,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: palette.inkFaint),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: l10n.quickAddEventExample,
            ),
          ),
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
