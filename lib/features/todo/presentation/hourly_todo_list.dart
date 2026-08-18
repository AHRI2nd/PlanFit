import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/quick_add/quick_add_parser.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/recurrence.dart';
import '../application/todo_providers.dart';
import '../domain/todo_overdue.dart';
import '../domain/todo_priority.dart';
import 'todo_detail_sheet.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../settings/application/settings_controller.dart';

/// The day's to-dos with an inline "add" field. Lightweight checkboxes, tied to
/// the selected day. New items default to 9am on that day, adjustable via the
/// time chip before adding; existing items' time can be changed the same way.
/// A repeat icon next to the time chip lets a new item be materialized as a
/// recurring series (see [TodoController.add]).
///
/// The add field also runs [parseQuickAdd] on submit — typing "내일 오후
/// 3시 병원" fills in the date/time from the phrase and adds just "병원" as
/// the title, overriding the day/time chips below rather than requiring
/// them to be set by hand first. A recognized date can point at a *different*
/// day than [day] (e.g. typing "내일" while looking at today) — the to-do
/// still gets created there, it just won't appear in this list until the
/// user navigates to that day, so a SnackBar names which day it landed on.
class HourlyTodoList extends ConsumerStatefulWidget {
  const HourlyTodoList({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<HourlyTodoList> createState() => _HourlyTodoListState();
}

class _HourlyTodoListState extends ConsumerState<HourlyTodoList> {
  final _controller = TextEditingController();
  late TimeOfDay _addTime;
  late DateTime _lastDay;
  RecurrenceFrequency _addRecurrence = RecurrenceFrequency.none;
  bool _addHasTime = true;
  TodoPriority _addPriority = TodoPriority.none;

  /// Multi-select state, entered by long-pressing any tile — see
  /// `_TodoTile.onEnterSelection`. `_selectedIds` is only ever non-empty
  /// while [_selectionMode] is true; the last deselect exits the mode
  /// automatically (see `_toggleSelected`).
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(id);
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkComplete() async {
    final controller = ref.read(todoControllerProvider);
    for (final id in _selectedIds.toList()) {
      await controller.toggle(id, true);
    }
    if (mounted) _exitSelection();
  }

  Future<void> _bulkDelete() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(todoControllerProvider);
    final ids = _selectedIds.toList();

    final removed = <RemovedTodo>[];
    for (final id in ids) {
      removed.addAll(await controller.remove(id));
    }
    if (mounted) _exitSelection();

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

  @override
  void initState() {
    super.initState();
    _addTime = const TimeOfDay(hour: 9, minute: 0);
    _lastDay = dateOnly(widget.day);
  }

  @override
  void didUpdateWidget(covariant HourlyTodoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final day = dateOnly(widget.day);
    if (day != _lastDay) {
      _lastDay = day;
      _addTime = const TimeOfDay(hour: 9, minute: 0);
      _addRecurrence = RecurrenceFrequency.none;
      _addHasTime = true;
      _addPriority = TodoPriority.none;
      // This widget instance is reused (no key at either DayView call site)
      // when the selected day changes, so any selection made on the
      // previous day must be cleared here too — otherwise the toolbar stays
      // open and a bulk action would silently complete/delete a to-do that
      // belongs to a day no longer even visible on screen.
      _selectionMode = false;
      _selectedIds.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAddTime() async {
    final picked = await showAppTimePicker(
      context: context,
      initialTime: _addTime,
      dialFormat: ref.read(
        settingsControllerProvider.select((s) => s.dialTimeFormatPreference),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _addTime = picked;
      _addHasTime = true;
    });
  }

  String _recurrenceLabel(AppL10n l10n, RecurrenceFrequency f) => switch (f) {
    RecurrenceFrequency.none => l10n.eventRepeatNone,
    RecurrenceFrequency.daily => l10n.eventRepeatDaily,
    RecurrenceFrequency.weekly => l10n.eventRepeatWeekly,
    RecurrenceFrequency.monthly => l10n.eventRepeatMonthly,
    RecurrenceFrequency.yearly => l10n.eventRepeatYearly,
  };

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    final parsed = parseQuickAdd(text, now: DateTime.now());
    final base = parsed.date ?? dateOnly(widget.day);
    final time = parsed.time ?? _addTime;
    final title = parsed.title.isEmpty ? text : parsed.title;

    await ref
        .read(todoControllerProvider)
        .add(
          title: title,
          slotStart: DateTime(
            base.year,
            base.month,
            base.day,
            time.hour,
            time.minute,
          ),
          hasTime: parsed.time != null || _addHasTime,
          frequency: _addRecurrence,
          // A parsed !priority/#tag overrides the chip/(future) picker,
          // same "explicit phrase wins over the UI default" rule the
          // date/time fields already follow.
          priority: parsed.priority ?? _addPriority.value,
          tags: parsed.tags.isEmpty ? null : parsed.tags.join(','),
        );
    _controller.clear();
    setState(() {
      _addRecurrence = RecurrenceFrequency.none;
      _addPriority = TodoPriority.none;
    });

    if (parsed.date != null &&
        !dateOnly(base).isAtSameMomentAs(dateOnly(widget.day))) {
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final todosAsync = ref.watch(todosForDayProvider(widget.day));
    final repeating = _addRecurrence != RecurrenceFrequency.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectionMode)
          _SelectionToolbar(
            count: _selectedIds.length,
            l10n: l10n,
            onCancel: _exitSelection,
            onComplete: _bulkComplete,
            onDelete: _bulkDelete,
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
                          dragHandleIndex: _selectionMode ? null : i,
                          selectionMode: _selectionMode,
                          selected: _selectedIds.contains(noTime[i].id),
                          onToggleSelected: () => _toggleSelected(noTime[i].id),
                          onEnterSelection: () => _enterSelection(noTime[i].id),
                        ),
                    ],
                  ),
                for (final t in timed)
                  _TodoTile(
                    todo: t,
                    locale: locale,
                    selectionMode: _selectionMode,
                    selected: _selectedIds.contains(t.id),
                    onToggleSelected: () => _toggleSelected(t.id),
                    onEnterSelection: () => _enterSelection(t.id),
                  ),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.add, size: 20, color: palette.inkFaint),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: l10n.todoHint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              PopupMenuButton<TodoPriority>(
                tooltip: l10n.todoPriorityLabel,
                initialValue: _addPriority,
                onSelected: (v) => setState(() => _addPriority = v),
                itemBuilder: (context) => TodoPriority.values
                    .map(
                      (p) =>
                          PopupMenuItem(value: p, child: Text(p.label(l10n))),
                    )
                    .toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Icon(
                    _addPriority == TodoPriority.none
                        ? Icons.flag_outlined
                        : Icons.flag,
                    size: 18,
                    color: _addPriority.color(palette) ?? palette.inkFaint,
                  ),
                ),
              ),
              PopupMenuButton<RecurrenceFrequency>(
                tooltip: l10n.todoRepeat,
                initialValue: _addRecurrence,
                onSelected: (v) => setState(() => _addRecurrence = v),
                itemBuilder: (context) => RecurrenceFrequency.values
                    .map(
                      (f) => PopupMenuItem(
                        value: f,
                        child: Text(_recurrenceLabel(l10n, f)),
                      ),
                    )
                    .toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Icon(
                    Icons.repeat_rounded,
                    size: 18,
                    color: repeating ? palette.accent : palette.inkFaint,
                  ),
                ),
              ),
              InkWell(
                onTap: _pickAddTime,
                borderRadius: BorderRadius.all(AppRadius.xs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Text(
                    _addHasTime ? _addTime.format(context) : l10n.todoNoTime,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _addHasTime ? palette.inkSoft : palette.accent,
                    ),
                  ),
                ),
              ),
              // Toggles between a picked time and no-time-at-all — tapping
              // the chip above always sets a concrete time (that's what
              // showTimePicker does), so clearing it needs its own control.
              IconButton(
                tooltip: l10n.todoNoTime,
                onPressed: () => setState(() => _addHasTime = !_addHasTime),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _addHasTime
                      ? Icons.timer_off_outlined
                      : Icons.access_time_outlined,
                  size: 16,
                  color: palette.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown above the to-do list in place of nothing while multi-select is
/// active — see `_HourlyTodoListState._selectionMode`.
class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.count,
    required this.l10n,
    required this.onCancel,
    required this.onComplete,
    required this.onDelete,
  });

  final int count;
  final AppL10n l10n;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.commonCancel,
            onPressed: onCancel,
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
          IconButton(
            tooltip: l10n.todoSelectionComplete,
            onPressed: onComplete,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.check_circle_outline, color: palette.accent),
          ),
          IconButton(
            tooltip: l10n.todoSelectionDelete,
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline, color: palette.danger),
          ),
        ],
      ),
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
    if (picked == null) return;
    final s = todo.slotStart;
    await ref
        .read(todoControllerProvider)
        .updateTime(
          todo.id,
          DateTime(s.year, s.month, s.day, picked.hour, picked.minute),
        );
  }

  /// Asks which scope to delete when [todo] is part of a recurring series;
  /// for a one-off item this just confirms the swipe itself (always true).
  /// Mirrors the event editor's own series-delete dialog. Either way, shows
  /// an undo SnackBar afterward — the event swipe-delete's counterpart (see
  /// day_view.dart's _EventCard._delete).
  Future<bool> _confirmDismiss(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(todoControllerProvider);

    List<RemovedTodo> removed;
    if (todo.recurrenceGroupId == null) {
      removed = await controller.remove(todo.id);
    } else {
      final deleteSeries = await showDialog<bool>(
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
      confirmDismiss: (_) => _confirmDismiss(context, ref),
      child: Container(
        color: selected ? palette.accent.withValues(alpha: 0.1) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                checked: selectionMode ? selected : todo.isDone,
                label: selectionMode ? l10n.todoSelectItem : l10n.todoMarkDone,
                child: InkWell(
                  onTap: selectionMode
                      ? onToggleSelected
                      : () => ref
                            .read(todoControllerProvider)
                            .toggle(todo.id, !todo.isDone),
                  onLongPress: selectionMode ? null : onEnterSelection,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
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
