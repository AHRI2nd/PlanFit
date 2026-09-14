import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/application/schedule_providers.dart';
import '../application/todo_providers.dart';
import '../domain/todo_delete_flow.dart';
import '../domain/todo_overdue.dart';
import '../domain/todo_priority.dart';
import 'quick_add_todo_sheet.dart';
import 'todo_detail_sheet.dart';
import 'todo_selection.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../settings/application/settings_controller.dart';

/// The day's to-dos with an inline "add" field. Lightweight checkboxes, tied
/// to the selected day. Existing items' time can be changed via their own
/// trailing time chip. The add field itself is the shared
/// [QuickAddTodoField] (day-scoped here) — see its doc for the time /
/// priority / repeat controls and the [parseQuickAdd] phrase handling.
class HourlyTodoList extends ConsumerStatefulWidget {
  const HourlyTodoList({super.key, required this.day, this.addFocusNode});

  final DateTime day;

  /// Lets a caller (the section header's "+" button — see `DayView`) drive
  /// focus into the inline add field from outside this widget. Owned and
  /// disposed by whoever passes it in; when absent this widget creates and
  /// owns its own instead, so the field still works standalone.
  final FocusNode? addFocusNode;

  @override
  ConsumerState<HourlyTodoList> createState() => _HourlyTodoListState();
}

class _HourlyTodoListState extends ConsumerState<HourlyTodoList>
    with TodoSelectionMixin<HourlyTodoList> {
  late final FocusNode _addFocusNode = widget.addFocusNode ?? FocusNode();
  late DateTime _lastDay;

  @override
  void initState() {
    super.initState();
    _lastDay = dateOnly(widget.day);
  }

  @override
  void didUpdateWidget(covariant HourlyTodoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final day = dateOnly(widget.day);
    if (day != _lastDay) {
      _lastDay = day;
      // This widget instance is reused (no key at either DayView call site)
      // when the selected day changes, so any selection made on the
      // previous day must be cleared here too — otherwise the toolbar stays
      // open and a bulk action would silently complete/delete a to-do that
      // belongs to a day no longer even visible on screen. (The add
      // field's own per-day defaults reset themselves — see
      // QuickAddTodoField.didUpdateWidget.)
      selectionMode = false;
      selectedIds.clear();
    }
  }

  @override
  void dispose() {
    // Only dispose it if we created it ourselves — a FocusNode passed in
    // via widget.addFocusNode is owned (and disposed) by its caller.
    if (widget.addFocusNode == null) _addFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final todosAsync = ref.watch(todosForDayProvider(widget.day));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectionMode)
          TodoSelectionToolbar(
            count: selectedIds.length,
            l10n: l10n,
            onCancel: exitSelection,
            onComplete: bulkComplete,
            onDelete: bulkDelete,
          ),
        todosAsync.maybeWhen(
          data: (todos) {
            // TodoDao.watchBetween sorts no-time items first, then timed
            // ones by slotStart — only the no-time bucket has no sort key
            // ahead of TodoItems.sortOrder, so it's the only one where a
            // manual drag reorder actually sticks (see
            // TodoController.reorder's doc).
            final noTime = todos.where((t) => !t.hasTime).toList();
            final timed = todos.where((t) => t.hasTime).toList();
            return Column(
              children: [
                if (noTime.isNotEmpty)
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) => ref
                        .read(todoControllerProvider)
                        .reorder(noTime, oldIndex, newIndex),
                    children: [
                      for (var i = 0; i < noTime.length; i++)
                        _TodoTile(
                          key: ValueKey(noTime[i].id),
                          todo: noTime[i],
                          locale: locale,
                          // Dragging and multi-select both hijack the
                          // trailing handle/whole-row gestures, so only one
                          // is ever active at a time.
                          dragHandleIndex: selectionMode ? null : i,
                          selectionMode: selectionMode,
                          selected: selectedIds.contains(noTime[i].id),
                          onToggleSelected: () => toggleSelected(noTime[i].id),
                          onEnterSelection: () => enterSelection(noTime[i].id),
                        ),
                    ],
                  ),
                for (final t in timed)
                  _TodoTile(
                    todo: t,
                    locale: locale,
                    selectionMode: selectionMode,
                    selected: selectedIds.contains(t.id),
                    onToggleSelected: () => toggleSelected(t.id),
                    onEnterSelection: () => enterSelection(t.id),
                  ),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        QuickAddTodoField(day: widget.day, focusNode: _addFocusNode),
      ],
    );
  }
}

class _TodoTile extends ConsumerWidget {
  const _TodoTile({
    super.key,
    required this.todo,
    required this.locale,
    this.dragHandleIndex,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
    this.onEnterSelection,
  });

  final TodoRow todo;
  final String locale;

  /// Non-null only for a tile rendered inside the "no time" section's
  /// `ReorderableListView` — its position there, passed straight through to
  /// `ReorderableDragStartListener` so a small trailing handle (not the
  /// whole row, which already has its own tap/swipe gestures) is the drag
  /// trigger.
  final int? dragHandleIndex;

  /// Whether `HourlyTodoList` is in multi-select mode — while true, every
  /// tap on this row toggles [selected] instead of its normal action
  /// (toggling done, opening the detail sheet, picking a time), and the
  /// swipe-to-delete gesture is disabled so it can't fire mid-selection.
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;

  /// Long-pressing the row while not already in selection mode enters it,
  /// pre-selecting this to-do — the standard mobile "long-press to start
  /// multi-select" gesture.
  final VoidCallback? onEnterSelection;

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final picked = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(todo.slotStart),
      dialFormat: ref.read(
        settingsControllerProvider.select((s) => s.dialTimeFormatPreference),
      ),
    );
    if (picked == null || !context.mounted) return;
    final s = todo.slotStart;
    await ref
        .read(todoControllerProvider)
        .updateTime(
          todo.id,
          DateTime(s.year, s.month, s.day, picked.hour, picked.minute),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final priority = TodoPriority.fromValue(todo.priority);
    final tags = (todo.tags ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final subtasks = ref
        .watch(todoSubtasksProvider(todo.id))
        .maybeWhen(data: (v) => v, orElse: () => null);
    final subtaskProgress = (subtasks == null || subtasks.isEmpty)
        ? null
        : '${subtasks.where((s) => s.isDone).length}/${subtasks.length}';
    final isOverdue = isTodoOverdue(todo, DateTime.now());
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );
    return Dismissible(
      key: ValueKey(todo.id),
      direction: selectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: Icon(Icons.delete_outline, color: palette.danger),
      ),
      confirmDismiss: (_) => confirmAndDeleteTodo(context, ref, todo),
      child: Container(
        color: selected ? palette.accent.withValues(alpha: 0.1) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Forced up to the 44x44 accessibility floor via SizedBox, kept
              // separate from the 22px icon's own visual size — same
              // pattern as _TitleChevron in schedule_screen.dart. This row
              // top-aligns (crossAxisAlignment.start), so the icon now sits
              // a few px lower within its taller box than before — a minor
              // shift, traded for a correctly-sized tap/long-press target.
              Semantics(
                button: true,
                checked: selectionMode ? selected : todo.isDone,
                label: selectionMode ? l10n.todoSelectItem : l10n.todoMarkDone,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: InkWell(
                    onTap: selectionMode
                        ? onToggleSelected
                        : () => ref
                              .read(todoControllerProvider)
                              .toggle(todo.id, !todo.isDone),
                    onLongPress: selectionMode ? null : onEnterSelection,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Icon(
                        selectionMode
                            ? (selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked)
                            : (todo.isDone
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked),
                        size: 22,
                        color: selectionMode
                            ? (selected ? palette.accent : palette.inkFaint)
                            : (todo.isDone
                                  ? palette.accent
                                  : isOverdue
                                  ? palette.danger
                                  : palette.inkFaint),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: InkWell(
                  onTap: selectionMode
                      ? onToggleSelected
                      : () => showTodoDetailSheet(context, todo),
                  onLongPress: selectionMode ? null : onEnterSelection,
                  borderRadius: AppRadius.cardMd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (priority.color(palette) != null) ...[
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(
                                  right: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: priority.color(palette),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Flexible(
                              child: Text(
                                todo.title,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: todo.isDone
                                      ? palette.inkFaint
                                      : palette.ink,
                                  decoration: todo.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (todo.recurrenceGroupId != null) ...[
                              const SizedBox(width: AppSpacing.xxs),
                              Icon(
                                Icons.repeat_rounded,
                                size: 14,
                                color: palette.inkFaint,
                                semanticLabel: l10n.todoRepeatIndicator,
                              ),
                            ],
                            if (todo.notify && todo.hasTime) ...[
                              const SizedBox(width: AppSpacing.xxs),
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 14,
                                color: palette.inkFaint,
                                semanticLabel: l10n.todoNotify,
                              ),
                            ],
                            if (todo.isPinned) ...[
                              const SizedBox(width: AppSpacing.xxs),
                              Icon(
                                Icons.push_pin,
                                size: 14,
                                color: palette.inkFaint,
                                semanticLabel: l10n.todoPinned,
                              ),
                            ],
                          ],
                        ),
                        if (tags.isNotEmpty || subtaskProgress != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Row(
                              children: [
                                if (tags.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      tags.join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: palette.inkFaint),
                                    ),
                                  ),
                                if (tags.isNotEmpty && subtaskProgress != null)
                                  Text(
                                    '  ·  ',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: palette.inkFaint,
                                    ),
                                  ),
                                if (subtaskProgress != null)
                                  Text(
                                    subtaskProgress,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: palette.inkFaint,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _pickTime(context, ref),
                // Long-press clears back to "no time" — picking a time via
                // the tap above is the way back in (see TodoDao.updateSlotStart).
                onLongPress: todo.hasTime
                    ? () => ref.read(todoControllerProvider).clearTime(todo.id)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Text(
                    todo.hasTime
                        ? Fmt.time(todo.slotStart, locale, use24Hour: use24)
                        : l10n.todoNoTime,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isOverdue
                          ? palette.danger
                          : todo.hasTime
                          ? palette.inkFaint
                          : palette.accent,
                      fontWeight: isOverdue ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ),
              if (dragHandleIndex != null)
                ReorderableDragStartListener(
                  index: dragHandleIndex!,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: palette.inkFaint,
                      semanticLabel: l10n.todoDragHandle,
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
