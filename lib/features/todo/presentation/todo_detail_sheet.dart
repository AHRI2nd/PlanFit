import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/adaptive_bottom_sheet.dart';
import '../../../design/widgets/multi_chip_row.dart';
import '../../../l10n/app_localizations.dart';
import '../application/todo_providers.dart';
import '../domain/todo_priority.dart';

/// Opens the editable detail view for [todo] — title, priority, tags, and
/// its subtask checklist. Everything here auto-saves on change (no explicit
/// "save" step), same as the rest of the to-do row's inline controls (time
/// chip, repeat icon) — there's nothing to lose by closing the sheet early.
Future<void> showTodoDetailSheet(BuildContext context, TodoRow todo) {
  return showAdaptiveBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _TodoDetailSheet(todo: todo),
  );
}

class _TodoDetailSheet extends ConsumerStatefulWidget {
  const _TodoDetailSheet({required this.todo});
  final TodoRow todo;

  @override
  ConsumerState<_TodoDetailSheet> createState() => _TodoDetailSheetState();
}

class _TodoDetailSheetState extends ConsumerState<_TodoDetailSheet> {
  late final TextEditingController _title;
  late final TextEditingController _tags;
  final _subtaskController = TextEditingController();
  late TodoPriority _priority;
  late bool _notify;
  late bool _pinned;

  /// Extra reminder offsets on top of the implicit "at due time" alert —
  /// see `TodoAlertX.reminderOffsets`. Never includes 0: that offset is
  /// always on whenever [_notify] is, so it isn't part of this "additional"
  /// set (mirrors the event editor's primary/additional reminder split).
  late Set<int> _additionalReminders;

  static const List<int> _leadTimeOptions = [0, 5, 10, 30, 60, 1440];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.todo.title);
    _tags = TextEditingController(text: widget.todo.tags ?? '');
    _priority = TodoPriority.fromValue(widget.todo.priority);
    _notify = widget.todo.notify;
    _pinned = widget.todo.isPinned;
    _additionalReminders = (widget.todo.additionalReminderMinutes ?? '')
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
  }

  String _leadTimeLabel(AppL10n l10n, int minutes) {
    if (minutes == 0) return l10n.eventReminderAtStart;
    if (minutes == 1440) return l10n.eventReminderDayBefore;
    if (minutes % 60 == 0) return l10n.eventReminderHoursBefore(minutes ~/ 60);
    return l10n.eventReminderMinutesBefore(minutes);
  }

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  void _saveTitle() {
    final text = _title.text.trim();
    if (text.isEmpty || text == widget.todo.title) return;
    ref.read(todoControllerProvider).updateTitle(widget.todo.id, text);
  }

  void _saveTags() {
    final text = _tags.text.trim();
    ref
        .read(todoControllerProvider)
        .setTags(widget.todo.id, text.isEmpty ? null : text);
  }

  void _addSubtask() {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;
    ref.read(todoControllerProvider).addSubtask(widget.todo.id, text);
    _subtaskController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final subtasksAsync = ref.watch(todoSubtasksProvider(widget.todo.id));

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: AppRadius.lg),
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
                children: [
                  Expanded(
                    child: Text(
                      l10n.todoEditTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: _pinned ? l10n.todoUnpin : l10n.todoPin,
                    onPressed: () {
                      setState(() => _pinned = !_pinned);
                      ref
                          .read(todoControllerProvider)
                          .setPinned(widget.todo.id, _pinned);
                    },
                    icon: Icon(
                      _pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: _pinned ? palette.accent : palette.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _title,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.todoTitleLabel,
                      ),
                      onSubmitted: (_) => _saveTitle(),
                      onTapOutside: (_) => _saveTitle(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.todoNotify,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: widget.todo.hasTime
                                      ? null
                                      : palette.inkFaint,
                                ),
                          ),
                        ),
                        Switch(
                          value: _notify && widget.todo.hasTime,
                          onChanged: widget.todo.hasTime
                              ? (v) {
                                  setState(() => _notify = v);
                                  ref
                                      .read(todoControllerProvider)
                                      .setNotify(widget.todo.id, v);
                                }
                              : null,
                        ),
                      ],
                    ),
                    if (!widget.todo.hasTime)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          l10n.todoNotifyNoTimeHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palette.inkFaint),
                        ),
                      ),
                    if (_notify && widget.todo.hasTime) ...[
                      const SizedBox(height: AppSpacing.sm),
                      MultiChipRow(
                        label: l10n.todoReminderAdditional,
                        options: _leadTimeOptions.where((m) => m != 0).toList(),
                        selected: _additionalReminders,
                        labelFor: (m) => _leadTimeLabel(l10n, m),
                        accent: palette.accent,
                        onChanged: (v) {
                          setState(() {
                            if (_additionalReminders.contains(v)) {
                              _additionalReminders.remove(v);
                            } else {
                              _additionalReminders.add(v);
                            }
                          });
                          ref
                              .read(todoControllerProvider)
                              .setAdditionalReminders(
                                widget.todo.id,
                                _additionalReminders,
                              );
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.todoPriorityLabel,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final p in TodoPriority.values)
                          ChoiceChip(
                            label: Text(p.label(l10n)),
                            selected: _priority == p,
                            onSelected: (_) {
                              setState(() => _priority = p);
                              ref
                                  .read(todoControllerProvider)
                                  .setPriority(widget.todo.id, p.value);
                            },
                            showCheckmark: false,
                            selectedColor: p.color(palette) ?? palette.accent,
                            labelStyle: TextStyle(
                              color: _priority == p
                                  ? Colors.white
                                  : palette.inkSoft,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _tags,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.todoTagsLabel,
                        hintText: l10n.todoTagsHint,
                      ),
                      onSubmitted: (_) => _saveTags(),
                      onTapOutside: (_) => _saveTags(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.todoSubtasksLabel,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    subtasksAsync.maybeWhen(
                      data: (subtasks) => Column(
                        children: [
                          for (final s in subtasks) _SubtaskRow(subtask: s),
                        ],
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                    Row(
                      children: [
                        Icon(Icons.add, size: 18, color: palette.inkFaint),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: TextField(
                            controller: _subtaskController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addSubtask(),
                            decoration: InputDecoration(
                              hintText: l10n.todoSubtaskHint,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtaskRow extends ConsumerWidget {
  const _SubtaskRow({required this.subtask});
  final TodoSubtaskRow subtask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = AppL10n.of(context);
    return Dismissible(
      key: ValueKey(subtask.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: Icon(
          Icons.delete_outline,
          color: palette.danger,
          semanticLabel: l10n.todoSubtaskDelete,
        ),
      ),
      onDismissed: (_) =>
          ref.read(todoControllerProvider).removeSubtask(subtask.id),
      child: InkWell(
        onTap: () => ref
            .read(todoControllerProvider)
            .toggleSubtask(subtask.id, !subtask.isDone),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            children: [
              Icon(
                subtask.isDone
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 18,
                color: subtask.isDone ? palette.accent : palette.inkFaint,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  subtask.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: subtask.isDone ? palette.inkFaint : palette.ink,
                    decoration: subtask.isDone
                        ? TextDecoration.lineThrough
                        : null,
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
