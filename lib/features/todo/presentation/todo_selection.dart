import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../l10n/app_localizations.dart';
import '../application/todo_providers.dart';
import '../../../core/date_math.dart';
import '../../../design/widgets/app_dialog.dart';
import '../../schedule/application/schedule_providers.dart' show todayProvider;

/// Long-press-to-multi-select state and bulk actions, shared by every
/// to-do list surface that offers it (`HourlyTodoList`, `TodoSmartListScreen`)
/// — none of this depends on a single day the way those widgets' own
/// per-day scoping does, so it lives here rather than in either of them.
mixin TodoSelectionMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Only ever non-empty while this is true; the last deselect exits the
  /// mode automatically (see [toggleSelected]).
  bool selectionMode = false;
  bool selectionBusy = false;
  final Set<String> selectedIds = {};

  /// Long-pressing a row while not already in selection mode enters it,
  /// pre-selecting that one to-do — the standard mobile "long-press to
  /// start multi-select" gesture.
  void enterSelection(String id) {
    if (selectionBusy) return;
    setState(() {
      selectionMode = true;
      selectedIds
        ..clear()
        ..add(id);
    });
  }

  void toggleSelected(String id) {
    if (selectionBusy) return;
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
        if (selectedIds.isEmpty) selectionMode = false;
      } else {
        selectedIds.add(id);
      }
    });
  }

  void exitSelection() {
    setState(() {
      selectionMode = false;
      selectedIds.clear();
    });
  }

  Future<void> bulkReschedule() async {
    if (selectionBusy || selectedIds.isEmpty) return;
    final ids = selectedIds.toSet();
    final l10n = AppL10n.of(context);
    setState(() => selectionBusy = true);
    try {
      final choice = await showAppDialog<int>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text(l10n.todoMoveTitle(ids.length)), content: Text(l10n.todoMoveKeepTime),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 0), child: Text(l10n.commonToday)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 1), child: Text(l10n.todoMoveTomorrow)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 2), child: Text(l10n.todoMoveChooseDate))],
      ));
      if (!mounted || choice == null) return;
      final today = ref.read(todayProvider);
      final day = choice == 2 ? await showAppDatePicker(context: context, initialDate: today,
        firstDate: DateTime(1900), lastDate: DateTime(2200)) : addCalendarDays(today, choice);
      if (day == null || !mounted) return;
      final result = await ref.read(todoControllerProvider).reschedule(ids, day);
      if (!mounted) return;
      exitSelection();
      ScaffoldMessenger.of(context).showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.todoMoveCompleted(result.moves.length))));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.todoMoveFailed)));
    } finally { if (mounted) setState(() => selectionBusy = false); }
  }

  Future<void> bulkComplete() async {
    final controller = ref.read(todoControllerProvider);
    for (final id in selectedIds.toList()) {
      await controller.toggle(id, true);
    }
    if (mounted) exitSelection();
  }

  Future<void> bulkDelete() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(todoControllerProvider);
    final ids = selectedIds.toList();

    final removed = <RemovedTodo>[];
    for (final id in ids) {
      removed.addAll(await controller.remove(id));
    }
    if (mounted) exitSelection();

    messenger.showAutoDismissSnackBar(
      SnackBar(
        content: Text(l10n.todoSelectionDeleted(removed.length)),
        action: SnackBarAction(
          label: l10n.eventUndo,
          onPressed: () async {
            for (final r in removed) {
              await controller.restore(r);
            }
          },
        ),
      ),
    );
  }
}

/// Shown above a to-do list in place of its usual header while multi-select
/// is active — see [TodoSelectionMixin].
class TodoSelectionToolbar extends StatelessWidget {
  const TodoSelectionToolbar({
    super.key,
    required this.count,
    required this.l10n,
    required this.onCancel,
    required this.onComplete,
    required this.onDelete,
    this.onReschedule,
    this.busy = false,
  });

  final int count;
  final AppL10n l10n;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback? onReschedule;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.commonCancel,
            onPressed: busy ? null : onCancel,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 20, color: palette.inkFaint),
          ),
          Expanded(
            child: Text(
              l10n.todoSelectionCount(count),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
            ),
          ),
          if (busy) const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
          if (onReschedule != null) IconButton(tooltip: l10n.todoSelectionReschedule,
            onPressed: busy ? null : onReschedule, icon: const Icon(Icons.event_repeat)),
          IconButton(
            tooltip: l10n.todoSelectionComplete,
            onPressed: busy ? null : onComplete,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.check_circle_outline, color: palette.accent),
          ),
          IconButton(
            tooltip: l10n.todoSelectionDelete,
            onPressed: busy ? null : onDelete,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline, color: palette.danger),
          ),
        ],
      ),
    );
  }
}
