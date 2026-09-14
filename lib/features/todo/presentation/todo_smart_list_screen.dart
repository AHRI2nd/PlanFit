import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/adaptive_bottom_sheet.dart'
    show kFloatingNavBarClearance, kListBottomFade;
import '../../../l10n/app_localizations.dart';
import '../../schedule/application/schedule_providers.dart' show dateOnly;
import '../../settings/application/settings_controller.dart';
import '../application/todo_providers.dart';
import '../domain/todo_delete_flow.dart';
import '../domain/todo_overdue.dart';
import '../domain/todo_priority.dart';
import 'quick_add_todo_sheet.dart';
import 'todo_detail_sheet.dart';
import 'todo_selection.dart';

enum _SmartListTab { today, overdue, highPriority, pinned, byTag }

/// Which tab [TodoSmartListScreen] opens on — only the tabs another screen
/// actually has a reason to deep-link into (e.g. the home screen's overdue
/// list linking to "see the rest here") are exposed; the others are only
/// ever reached by tapping a chip inside this screen itself.
enum SmartListInitialTab { today, overdue }

/// A cross-day view of to-dos, filtered by one of a few fixed "smart list"
/// criteria — the counterpart to the day/week/month views' own per-day
/// framing, for questions like "what's overdue?" or "what's tagged 업무?"
/// that don't have a single day to anchor on.
class TodoSmartListScreen extends ConsumerStatefulWidget {
  const TodoSmartListScreen({
    super.key,
    this.initialTab = SmartListInitialTab.today,
  });

  final SmartListInitialTab initialTab;

  @override
  ConsumerState<TodoSmartListScreen> createState() =>
      _TodoSmartListScreenState();
}

class _TodoSmartListScreenState extends ConsumerState<TodoSmartListScreen>
    with TodoSelectionMixin<TodoSmartListScreen> {
  late _SmartListTab _tab = switch (widget.initialTab) {
    SmartListInitialTab.today => _SmartListTab.today,
    SmartListInitialTab.overdue => _SmartListTab.overdue,
  };
  String? _selectedTag;

  /// Switching tabs (or the selected tag, within the 태그별 tab) swaps the
  /// entire list a selection was made against — same reasoning as
  /// HourlyTodoList's own day-change reset, just triggered by a tab/tag
  /// pick here instead of paging to a different day.
  void _switchTab(_SmartListTab tab) {
    setState(() {
      _tab = tab;
      selectionMode = false;
      selectedIds.clear();
    });
  }

  void _switchTag(String tag) {
    setState(() {
      _selectedTag = tag;
      selectionMode = false;
      selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.smartListTitle)),
      // This screen (unlike the day view's own inline field) has no single
      // day to anchor a quick-add row to, so it gets the app's other
      // "add" affordance — a FAB opening a tiny quick-add sheet — instead.
      // Lifted clear of the floating glass nav bar, which lives outside this
      // nested Scaffold (in AppShell) so it isn't reserved for automatically
      // — same reasoning as schedule_screen.dart's own FAB.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: kFloatingNavBarClearance),
        child: FloatingActionButton(
          tooltip: l10n.todoAdd,
          onPressed: () => showQuickAddTodoSheet(context),
          child: const Icon(Icons.add),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: TodoSelectionToolbar(
                count: selectedIds.length,
                l10n: l10n,
                onCancel: exitSelection,
                onComplete: bulkComplete,
                onDelete: bulkDelete,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.xs,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in _SmartListTab.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: ChoiceChip(
                          label: Text(_tabLabel(l10n, tab)),
                          selected: _tab == tab,
                          onSelected: (_) => _switchTab(tab),
                          showCheckmark: false,
                          selectedColor: palette.accent,
                          labelStyle: TextStyle(
                            color: _tab == tab ? Colors.white : palette.inkSoft,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(child: _buildBody(context, l10n)),
        ],
      ),
    );
  }

  String _tabLabel(AppL10n l10n, _SmartListTab tab) => switch (tab) {
    _SmartListTab.today => l10n.smartListToday,
    _SmartListTab.overdue => l10n.smartListOverdue,
    _SmartListTab.highPriority => l10n.smartListHighPriority,
    _SmartListTab.pinned => l10n.smartListPinned,
    _SmartListTab.byTag => l10n.smartListByTag,
  };

  Widget _buildBody(BuildContext context, AppL10n l10n) {
    switch (_tab) {
      case _SmartListTab.today:
        return _TodoListView(
          watch: (ref) =>
              ref.watch(todosForDayProvider(dateOnly(DateTime.now()))),
          emptyMessage: l10n.smartListEmptyToday,
          selectionMode: selectionMode,
          selectedIds: selectedIds,
          onToggleSelected: toggleSelected,
          onEnterSelection: enterSelection,
        );
      case _SmartListTab.overdue:
        return _TodoListView(
          watch: (ref) => ref.watch(overdueTodosProvider),
          emptyMessage: l10n.smartListEmptyOverdue,
          selectionMode: selectionMode,
          selectedIds: selectedIds,
          onToggleSelected: toggleSelected,
          onEnterSelection: enterSelection,
        );
      case _SmartListTab.highPriority:
        return _TodoListView(
          watch: (ref) => ref.watch(highPriorityTodosProvider),
          emptyMessage: l10n.smartListEmptyHighPriority,
          selectionMode: selectionMode,
          selectedIds: selectedIds,
          onToggleSelected: toggleSelected,
          onEnterSelection: enterSelection,
        );
      case _SmartListTab.pinned:
        return _TodoListView(
          watch: (ref) => ref.watch(pinnedTodosProvider),
          emptyMessage: l10n.smartListEmptyPinned,
          selectionMode: selectionMode,
          selectedIds: selectedIds,
          onToggleSelected: toggleSelected,
          onEnterSelection: enterSelection,
        );
      case _SmartListTab.byTag:
        return _ByTagView(
          selectedTag: _selectedTag,
          onSelectTag: _switchTag,
          selectionMode: selectionMode,
          selectedIds: selectedIds,
          onToggleSelected: toggleSelected,
          onEnterSelection: enterSelection,
        );
    }
  }
}

class _ByTagView extends ConsumerWidget {
  const _ByTagView({
    required this.selectedTag,
    required this.onSelectTag,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelected,
    required this.onEnterSelection,
  });

  final String? selectedTag;
  final ValueChanged<String> onSelectTag;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelected;
  final ValueChanged<String> onEnterSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final tagsAsync = ref.watch(todoTagsProvider);

    return tagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tags) {
        if (tags.isEmpty) {
          return Center(
            child: Text(
              l10n.smartListNoTags,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.inkFaint),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xs,
                AppSpacing.gutter,
                AppSpacing.xs,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tag in tags)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: ChoiceChip(
                          label: Text(tag),
                          selected: selectedTag == tag,
                          onSelected: (_) => onSelectTag(tag),
                          showCheckmark: false,
                          selectedColor: palette.accent,
                          labelStyle: TextStyle(
                            color: selectedTag == tag
                                ? Colors.white
                                : palette.inkSoft,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: selectedTag == null
                  ? Center(
                      child: Text(
                        l10n.smartListPickTag,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.inkFaint,
                        ),
                      ),
                    )
                  : _TodoListView(
                      watch: (ref) =>
                          ref.watch(todosByTagProvider(selectedTag!)),
                      emptyMessage: l10n.smartListEmptyByTag,
                      selectionMode: selectionMode,
                      selectedIds: selectedIds,
                      onToggleSelected: onToggleSelected,
                      onEnterSelection: onEnterSelection,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TodoListView extends ConsumerWidget {
  const _TodoListView({
    required this.watch,
    required this.emptyMessage,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelected,
    required this.onEnterSelection,
  });

  /// `(ref) => ref.watch(someProvider)` — passed as a closure rather than a
  /// provider reference directly, since the different tabs' sources are a
  /// mix of plain providers and `.family` ones instantiated with an
  /// argument, which don't share one convenient static type to hold here.
  final AsyncValue<List<TodoRow>> Function(WidgetRef ref) watch;
  final String emptyMessage;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelected;
  final ValueChanged<String> onEnterSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final async = watch(ref);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (todos) {
        if (todos.isEmpty) {
          return Center(
            child: Text(
              emptyMessage,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.inkFaint),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xs,
            AppSpacing.gutter,
            kListBottomFade,
          ),
          itemCount: todos.length,
          itemBuilder: (context, i) => _SmartTodoTile(
            todo: todos[i],
            selectionMode: selectionMode,
            selected: selectedIds.contains(todos[i].id),
            onToggleSelected: () => onToggleSelected(todos[i].id),
            onEnterSelection: () => onEnterSelection(todos[i].id),
          ),
        );
      },
    );
  }
}

class _SmartTodoTile extends ConsumerWidget {
  const _SmartTodoTile({
    required this.todo,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
    this.onEnterSelection,
  });

  final TodoRow todo;

  /// Whether the screen is in multi-select mode — while true, every tap on
  /// this row toggles [selected] instead of its normal action (toggling
  /// done, opening the detail sheet), and the swipe-to-delete gesture is
  /// disabled so it can't fire mid-selection. Same pattern as
  /// HourlyTodoList's own `_TodoTile`.
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;

  /// Long-pressing the row while not already in selection mode enters it,
  /// pre-selecting this to-do.
  final VoidCallback? onEnterSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final priority = TodoPriority.fromValue(todo.priority);
    final tags = (todo.tags ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
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
        child: InkWell(
          onTap: selectionMode
              ? onToggleSelected
              : () => showTodoDetailSheet(context, todo),
          onLongPress: selectionMode ? null : onEnterSelection,
          borderRadius: AppRadius.cardMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                // Forced up to the 44x44 accessibility floor via SizedBox,
                // kept separate from the 20px icon's own visual size — same
                // pattern as _TitleChevron in schedule_screen.dart.
                Semantics(
                  button: true,
                  checked: selectionMode ? selected : todo.isDone,
                  label: selectionMode
                      ? l10n.todoSelectItem
                      : l10n.todoMarkDone,
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
                          size: 20,
                          color: selectionMode
                              ? (selected ? palette.accent : palette.inkFaint)
                              : todo.isDone
                              ? palette.accent
                              : isOverdue
                              ? palette.danger
                              : palette.inkFaint,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (priority.color(palette) != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: priority.color(palette),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              todo.title.isEmpty ? '—' : todo.title,
                              maxLines: 1,
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
                          if (todo.isPinned) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            Icon(
                              Icons.push_pin,
                              size: 12,
                              color: palette.inkFaint,
                              semanticLabel: l10n.todoPinned,
                            ),
                          ],
                        ],
                      ),
                      if (tags.isNotEmpty)
                        Text(
                          tags.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.inkFaint,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  todo.hasTime
                      ? '${Fmt.monthDay(todo.slotStart, locale)} ${Fmt.time(todo.slotStart, locale, use24Hour: use24)}'
                      : Fmt.monthDay(todo.slotStart, locale),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isOverdue ? palette.danger : palette.inkFaint,
                    fontWeight: isOverdue ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
