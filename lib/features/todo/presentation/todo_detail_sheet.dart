import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../design/glass/glass_nav_bar.dart' show navBarVisibleHeight;
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/adaptive_bottom_sheet.dart';
import '../../../design/widgets/app_dialog.dart';
import '../../../design/widgets/multi_chip_row.dart';
import '../../../design/widgets/snackbar_x.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/application/settings_controller.dart';
import '../application/todo_providers.dart';
import '../domain/todo_priority.dart';

/// Opens the editable detail view for [todo] — title, priority, tags, and
/// its subtask checklist. Priority/notify/pin/reminder controls save
/// immediately on change, same as the rest of the to-do row's inline
/// controls (time chip, repeat icon). Title and tags autosave on a short
/// debounce as you type, AND are force-flushed right before the sheet
/// actually closes (via `PopScope`) — submitting, tapping outside, swiping
/// the sheet down, and the Android back gesture all end up here, but only
/// submit/tap-outside fire `onSubmitted`/`onTapOutside`, so the flush is
/// what guarantees nothing typed is lost on the other two dismissal paths.
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
  // Last value of `_title` actually confirmed persisted — see
  // `_lastSavedTags`'s own doc for why this can't just be
  // `widget.todo.title` (that field is a fixed snapshot from when the sheet
  // opened, never refreshed as saves land): without tracking this
  // separately, `_saveTitle`'s no-op guard compared every debounce firing
  // against that same stale snapshot, so typing past a save and then back
  // down to the *original* title (e.g. "Buy milk" -> "Buy milk and eggs"
  // -> "Buy milk" again, all in one sheet session) matched the snapshot and
  // silently skipped saving the reverted title, leaving the DB stuck on the
  // intermediate value.
  late String _lastSavedTitle;
  late final TextEditingController _tags;
  final _subtaskController = TextEditingController();
  late TodoPriority _priority;
  late bool _notify;
  late bool _pinned;
  // Last value of `_tags` actually confirmed persisted — the revert target
  // if a save throws (see `_saveTags`), since the field's own displayed
  // text is the optimistic state here (there's no separate bool/enum to
  // roll back, unlike pin/priority).
  late String _lastSavedTags;
  Timer? _titleDebounce;
  Timer? _tagsDebounce;

  // Bumped on every pin/priority tap, respectively — a failed save only
  // reverts its own optimistic setState if its own request is still the
  // most recent one. A plain "does the field still show what I optimistically
  // set it to" check (like `_saveTags`'s own guard) isn't enough here: pin
  // is a bare bool, so a *third* tap can cycle back to the exact same
  // optimistic value a still-in-flight first attempt set, and a value
  // comparison alone can't tell that apart from "nothing happened since".
  // Comparing request ids can — this is the standard "ignore stale async
  // responses" pattern.
  var _pinRequestId = 0;
  var _priorityRequestId = 0;
  var _notifyRequestId = 0;
  var _additionalRemindersRequestId = 0;

  static const _saveDebounce = Duration(milliseconds: 400);

  /// Extra reminder offsets on top of the implicit "at due time" alert —
  /// see `TodoAlertX.reminderOffsets`. Never includes 0: that offset is
  /// always on whenever [_notify] is, so it isn't part of this "additional"
  /// set (mirrors the event editor's primary/additional reminder split).
  late Set<int> _additionalReminders;

  /// This sheet is handed a [TodoRow] snapshot rather than watching the
  /// row, so — like `_priority`, `_notify` and `_pinned` — the slot is
  /// mirrored here and updated optimistically. Without it, changing the date
  /// would write to the database and leave the row on screen showing the old
  /// one.
  late DateTime _slotStart;
  late bool _hasTime;

  static const List<int> _leadTimeOptions = [0, 5, 10, 30, 60, 1440];

  /// Runs [write], reverting nothing but surfacing a failure the same way
  /// every other edit on this sheet does.
  Future<void> _guard(Future<void> Function() write, VoidCallback apply) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    try {
      await write();
      if (!mounted) return;
      setState(apply);
    } catch (_) {
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.todoUpdateFailed)),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _slotStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    await _guard(
      () => ref.read(todoControllerProvider).updateDate(widget.todo.id, picked),
      () => _slotStart = _hasTime
          ? DateTime(
              picked.year,
              picked.month,
              picked.day,
              _slotStart.hour,
              _slotStart.minute,
            )
          : DateTime(picked.year, picked.month, picked.day),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_slotStart),
      dialFormat: ref.read(
        settingsControllerProvider.select((s) => s.dialTimeFormatPreference),
      ),
    );
    if (picked == null || !mounted) return;
    final next = DateTime(
      _slotStart.year,
      _slotStart.month,
      _slotStart.day,
      picked.hour,
      picked.minute,
    );
    await _guard(
      () => ref.read(todoControllerProvider).updateTime(widget.todo.id, next),
      () {
        // updateTime turns a no-time to-do back into a timed one — picking a
        // time is exactly how a user opts back in (TodoDao.updateSlotStart).
        _slotStart = next;
        _hasTime = true;
      },
    );
  }

  Future<void> _clearTime() => _guard(
    () => ref.read(todoControllerProvider).clearTime(widget.todo.id),
    () {
      _hasTime = false;
      _slotStart = DateTime(_slotStart.year, _slotStart.month, _slotStart.day);
    },
  );

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.todo.title);
    _lastSavedTitle = _title.text;
    _tags = TextEditingController(text: widget.todo.tags ?? '');
    _lastSavedTags = _tags.text;
    _slotStart = widget.todo.slotStart;
    _hasTime = widget.todo.hasTime;
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
    _titleDebounce?.cancel();
    _tagsDebounce?.cancel();
    _title.dispose();
    _tags.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  void _saveTitle() {
    final text = _title.text.trim();
    if (text.isEmpty || text == _lastSavedTitle) return;
    ref.read(todoControllerProvider).updateTitle(widget.todo.id, text);
    _lastSavedTitle = text;
  }

  /// Cancels any pending debounce and saves the title immediately — used
  /// wherever a save should happen right now (submit, tap-outside, or the
  /// pop-time flush) rather than waiting out `_saveDebounce`.
  void _commitTitle() {
    _titleDebounce?.cancel();
    _saveTitle();
  }

  void _onTitleChanged(String _) {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(_saveDebounce, _saveTitle);
  }

  Future<void> _saveTags() async {
    final text = _tags.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    try {
      await ref
          .read(todoControllerProvider)
          .setTags(widget.todo.id, text.isEmpty ? null : text);
      _lastSavedTags = text;
    } catch (_) {
      if (!mounted) return;
      // Only revert if the field still shows exactly what this failed save
      // attempt was for — otherwise the user has already typed something
      // newer, and clobbering that would be worse than leaving the stale
      // (but at-least-visible) unsaved text in place.
      if (_tags.text == text) {
        _tags.text = _lastSavedTags;
      }
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.todoUpdateFailed)),
      );
    }
  }

  void _commitTags() {
    _tagsDebounce?.cancel();
    _saveTags();
  }

  void _onTagsChanged(String _) {
    _tagsDebounce?.cancel();
    _tagsDebounce = Timer(_saveDebounce, _saveTags);
  }

  /// The safety net for swipe-to-dismiss / the Android back gesture, which
  /// close the sheet without ever calling `onSubmitted` or `onTapOutside`.
  /// Wired to fire from `PopScope` right as the sheet closes, so whatever
  /// was typed in the last `_saveDebounce` window is never lost.
  void _flushPendingSaves() {
    _commitTitle();
    _commitTags();
  }

  Future<void> _addSubtask() async {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    try {
      await ref.read(todoControllerProvider).addSubtask(widget.todo.id, text);
      // Only cleared on confirmed success — otherwise a failed add would
      // silently drop what the user typed.
      if (mounted) _subtaskController.clear();
    } catch (_) {
      if (!mounted) return;
      messenger.showAutoDismissSnackBar(
        SnackBar(content: Text(l10n.todoUpdateFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final use24Hour = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );
    final subtasksAsync = ref.watch(todoSubtasksProvider(widget.todo.id));

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _flushPendingSaves();
      },
      // No SafeArea around the box: the sheet's surface has to run all the
      // way to the bottom of the screen so its glass blurs the page rather
      // than the barrier scrim behind the floating tab bar — inset by the
      // home indicator, it left the bar's pill peeking out below its own
      // rounded edge. The inset is applied to the scrolling content
      // instead, where it keeps the last field clear of the indicator
      // without shortening the surface. (The sheet itself stays on the
      // branch navigator, so the tab bar remains visible and live while
      // it is open.)
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
                    onPressed: () async {
                      final myRequestId = ++_pinRequestId;
                      final previous = _pinned;
                      setState(() => _pinned = !previous);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref
                            .read(todoControllerProvider)
                            .setPinned(widget.todo.id, _pinned);
                      } catch (_) {
                        if (!mounted) return;
                        // Only revert if no newer pin attempt has started
                        // since this one — see `_pinRequestId`'s own doc.
                        if (myRequestId == _pinRequestId) {
                          setState(() => _pinned = previous);
                        }
                        messenger.showAutoDismissSnackBar(
                          SnackBar(content: Text(l10n.todoUpdateFailed)),
                        );
                      }
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
                // Reserves the *visible* bar — the glass pill and the
                // gap above it — not navBarControlClearance's whole widget
                // footprint. The sheet's surface runs under the bar on
                // purpose: that is what the bar's glass blurs, and why it
                // reads white instead of picking the scrim up and turning
                // grey. So what the content has to clear is only as far up
                // as the pill. Reserving the full footprint, and stacking
                // the home-indicator inset and a large gap on top of it,
                // is what left a visible band of empty surface above the
                // bar.
                //
                // The keyboard inset is added because
                // showAdaptiveBottomSheet's isScrollControlled: true
                // bypasses Flutter's automatic viewInsets padding
                // (bottom_sheet.dart never references viewInsets at all),
                // so without it the tags/subtask fields sit behind the
                // keyboard.
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  MediaQuery.of(context).viewInsets.bottom +
                      navBarVisibleHeight(context) +
                      AppSpacing.sm,
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
                      onChanged: _onTitleChanged,
                      onSubmitted: (_) => _commitTitle(),
                      onTapOutside: (_) => _commitTitle(),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Date and time, which this sheet had no way to change
                    // at all: the time was only editable from the day
                    // list's own trailing chip, and the date from nowhere
                    // — a to-do put on the wrong day could be deleted and
                    // retyped, but not moved.
                    //
                    // Both on one row rather than a labelled row each.
                    // This sheet is already tall enough that its last
                    // field sits near the bottom of the screen, and a
                    // second full row buys nothing: the two values are
                    // read together and the time's own "시간 없음" state
                    // labels itself.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.todoDateLabel,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: _pickDate,
                          child: Text(Fmt.monthDay(_slotStart, locale)),
                        ),
                        TextButton(
                          onPressed: _pickTime,
                          child: Text(
                            _hasTime
                                ? Fmt.time(
                                    _slotStart,
                                    locale,
                                    use24Hour: use24Hour,
                                  )
                                : l10n.todoNoTime,
                          ),
                        ),
                        // Only offered once there is a time to remove. The
                        // day list clears one by long-pressing its chip,
                        // fine as a shortcut on a row but not as the only
                        // way to reach it.
                        if (_hasTime)
                          IconButton(
                            tooltip: l10n.todoClearTime,
                            onPressed: _clearTime,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: palette.inkFaint,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
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
                              ? (v) async {
                                  final myRequestId = ++_notifyRequestId;
                                  final previous = _notify;
                                  setState(() => _notify = v);
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    await ref
                                        .read(todoControllerProvider)
                                        .setNotify(widget.todo.id, v);
                                  } catch (_) {
                                    if (!mounted) return;
                                    if (myRequestId == _notifyRequestId) {
                                      setState(() => _notify = previous);
                                    }
                                    messenger.showAutoDismissSnackBar(
                                      SnackBar(
                                        content: Text(l10n.todoUpdateFailed),
                                      ),
                                    );
                                  }
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
                        onChanged: (v) async {
                          final myRequestId = ++_additionalRemindersRequestId;
                          final previous = Set<int>.of(_additionalReminders);
                          setState(() {
                            if (_additionalReminders.contains(v)) {
                              _additionalReminders.remove(v);
                            } else {
                              _additionalReminders.add(v);
                            }
                          });
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ref
                                .read(todoControllerProvider)
                                .setAdditionalReminders(
                                  widget.todo.id,
                                  _additionalReminders,
                                );
                          } catch (_) {
                            if (!mounted) return;
                            if (myRequestId == _additionalRemindersRequestId) {
                              setState(() => _additionalReminders = previous);
                            }
                            messenger.showAutoDismissSnackBar(
                              SnackBar(content: Text(l10n.todoUpdateFailed)),
                            );
                          }
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
                            onSelected: (_) async {
                              final myRequestId = ++_priorityRequestId;
                              final previous = _priority;
                              setState(() => _priority = p);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await ref
                                    .read(todoControllerProvider)
                                    .setPriority(widget.todo.id, p.value);
                              } catch (_) {
                                if (!mounted) return;
                                // Only revert if no newer priority attempt
                                // has started since this one — see
                                // `_priorityRequestId`'s own doc.
                                if (myRequestId == _priorityRequestId) {
                                  setState(() => _priority = previous);
                                }
                                messenger.showAutoDismissSnackBar(
                                  SnackBar(
                                    content: Text(l10n.todoUpdateFailed),
                                  ),
                                );
                              }
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
                      onChanged: _onTagsChanged,
                      onSubmitted: (_) => _commitTags(),
                      onTapOutside: (_) => _commitTags(),
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
      onDismissed: (_) async {
        // The Dismissible's own dismiss animation has already run and the
        // row is gone from view by the time this fires, so there's nothing
        // to visually revert on failure — just surface it rather than let
        // the exception vanish silently. Full "un-delete" UX is out of
        // scope here.
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(todoControllerProvider).removeSubtask(subtask.id);
        } catch (_) {
          if (!context.mounted) return;
          messenger.showAutoDismissSnackBar(
            SnackBar(content: Text(l10n.todoUpdateFailed)),
          );
        }
      },
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
