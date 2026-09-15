import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/widgets/app_dialog.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../l10n/app_localizations.dart';
import '../application/todo_providers.dart';

/// Asks which scope to delete when [todo] is part of a recurring series
/// ("this occurrence" vs "this and every future one"), then deletes and
/// shows an undo SnackBar — shared by every surface that offers a
/// swipe-to-delete gesture on a to-do (`HourlyTodoList`, the home screen's
/// own to-do list, the smart-list screen), so the "this vs. all future"
/// decision and its undo path stay identical no matter where a to-do was
/// swiped from. Returns whether the swipe should actually dismiss the tile
/// (mirrors `Dismissible.confirmDismiss`'s own contract) — `false` when a
/// recurring-series dialog was cancelled outright rather than answered.
Future<bool> confirmAndDeleteTodo(
  BuildContext context,
  WidgetRef ref,
  TodoRow todo,
) async {
  final l10n = AppL10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(todoControllerProvider);

  List<RemovedTodo> removed;
  if (todo.recurrenceGroupId == null) {
    removed = await controller.remove(todo.id);
  } else {
    final deleteSeries = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.todoDeleteSeriesTitle),
        content: Text(l10n.todoDeleteSeriesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.todoDeleteThisOnly),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.danger,
            ),
            child: Text(l10n.todoDeleteThisAndFuture),
          ),
        ],
      ),
    );
    if (deleteSeries == null) return false;
    removed = deleteSeries
        ? await controller.removeSeriesFrom(todo)
        : await controller.remove(todo.id);
  }

  messenger.showAutoDismissSnackBar(
    SnackBar(
      content: Text(l10n.todoDeleted),
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
  return true;
}
