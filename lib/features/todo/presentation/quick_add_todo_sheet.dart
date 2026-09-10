import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/quick_add/quick_add_parser.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/adaptive_bottom_sheet.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/application/schedule_providers.dart' show dateOnly;
import '../application/todo_providers.dart';

/// The single-line "type a to-do, optionally with a date/time/priority/tag
/// phrase" sheet — the smart-list screen's own "add a to-do" affordance,
/// for the one screen with no single day to scope an inline add row to
/// (`HourlyTodoList`'s own field, used inside a specific day, covers that
/// case instead — see [QuickAddTodoField]'s own doc).
Future<void> showQuickAddTodoSheet(BuildContext context) =>
    showAdaptiveBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAddTodoSheet(),
    );

/// A new to-do here defaults to today, no time, reusing the same
/// [parseQuickAdd] phrase-parsing the day view's own quick-add field runs.
/// Just a title plus [QuickAddTodoField] in sheet chrome — see that
/// widget's own doc for the actual field + submit logic.
class QuickAddTodoSheet extends StatelessWidget {
  const QuickAddTodoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.gutter,
          right: AppSpacing.gutter,
          top: AppSpacing.sm,
          bottom: AppSpacing.gutter + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.todoAdd, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            QuickAddTodoField(
              autofocus: true,
              onAdded: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bare "+ [text field]" that parses and creates a to-do on submit —
/// [parseQuickAdd] runs the same natural-language phrase parsing
/// `HourlyTodoList`'s own day-scoped add field does ("내일 오후 3시 병원"
/// fills in the date/time and adds just "병원" as the title), just without
/// that field's day/time/priority/repeat chips, since this one has no
/// single day already in view to default those against.
///
/// Deliberately reusable outside a sheet: the home screen's own to-dos
/// section shows this inline, always visible, at the bottom of the page —
/// the day/week views' own "+ button next to the section header reveals an
/// inline field" convention, not a FAB that hides the add affordance behind
/// an extra tap and a modal sheet the way [QuickAddTodoSheet] does for the
/// smart-list screen (which has no such section of its own to attach an
/// inline field to).
class QuickAddTodoField extends ConsumerStatefulWidget {
  const QuickAddTodoField({
    super.key,
    this.autofocus = false,
    this.focusNode,
    this.onAdded,
  });

  final bool autofocus;

  /// Lets a caller drive focus into this field from outside — see
  /// `HourlyTodoList`'s own `addFocusNode` for the pattern this mirrors.
  /// Owned and disposed by whoever passes it in; when absent this widget
  /// creates and owns its own instead, so the field still works standalone.
  final FocusNode? focusNode;

  /// Called after a to-do is successfully created. [QuickAddTodoSheet]
  /// uses this to pop itself closed; a caller that shows this field inline
  /// (not in a sheet) leaves it null — the field just clears itself and
  /// stays, ready for the next one.
  final VoidCallback? onAdded;

  @override
  ConsumerState<QuickAddTodoField> createState() => _QuickAddTodoFieldState();
}

class _QuickAddTodoFieldState extends ConsumerState<QuickAddTodoField> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = dateOnly(DateTime.now());

    final parsed = parseQuickAdd(text, now: DateTime.now());
    final base = parsed.date ?? today;
    final time = parsed.time;
    final title = parsed.title.isEmpty ? text : parsed.title;

    await ref
        .read(todoControllerProvider)
        .add(
          title: title,
          slotStart: time == null
              ? base
              : DateTime(
                  base.year,
                  base.month,
                  base.day,
                  time.hour,
                  time.minute,
                ),
          hasTime: time != null,
          priority: parsed.priority ?? 0,
          tags: parsed.tags.isEmpty ? null : parsed.tags.join(','),
        );

    if (!mounted) return;
    _controller.clear();
    widget.onAdded?.call();
    if (parsed.date != null && !dateOnly(base).isAtSameMomentAs(today)) {
      messenger.showAutoDismissSnackBar(
        SnackBar(
          content: Text(
            l10n.todoQuickAddAddedToOtherDay(Fmt.monthDay(base, locale)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: l10n.todoHint,
        prefixIcon: Icon(Icons.add, color: palette.inkFaint),
      ),
    );
  }
}
