import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/format.dart';
import '../../../core/time_format.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/application/schedule_providers.dart' show dateOnly;
import '../../settings/application/settings_controller.dart';
import '../application/todo_providers.dart';
import '../domain/todo_overdue.dart';
import '../domain/todo_priority.dart';
import 'todo_detail_sheet.dart';

enum _SmartListTab { today, overdue, highPriority, pinned, byTag }

/// A cross-day view of to-dos, filtered by one of a few fixed "smart list"
/// criteria — the counterpart to the day/week/month views' own per-day
/// framing, for questions like "what's overdue?" or "what's tagged 업무?"
/// that don't have a single day to anchor on.
class TodoSmartListScreen extends ConsumerStatefulWidget {
  const TodoSmartListScreen({super.key});

  @override
  ConsumerState<TodoSmartListScreen> createState() =>
      _TodoSmartListScreenState();
}

class _TodoSmartListScreenState extends ConsumerState<TodoSmartListScreen> {
  _SmartListTab _tab = _SmartListTab.today;
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.smartListTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                        onSelected: (_) => setState(() => _tab = tab),
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
        );
      case _SmartListTab.overdue:
        return _TodoListView(
          watch: (ref) => ref.watch(overdueTodosProvider),
          emptyMessage: l10n.smartListEmptyOverdue,
        );
      case _SmartListTab.highPriority:
        return _TodoListView(
          watch: (ref) => ref.watch(highPriorityTodosProvider),
          emptyMessage: l10n.smartListEmptyHighPriority,
        );
      case _SmartListTab.pinned:
        return _TodoListView(
          watch: (ref) => ref.watch(pinnedTodosProvider),
          emptyMessage: l10n.smartListEmptyPinned,
        );
      case _SmartListTab.byTag:
        return _ByTagView(
          selectedTag: _selectedTag,
          onSelectTag: (tag) => setState(() => _selectedTag = tag),
        );
    }
  }
}

class _ByTagView extends ConsumerWidget {
  const _ByTagView({required this.selectedTag, required this.onSelectTag});

  final String? selectedTag;
  final ValueChanged<String> onSelectTag;

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
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TodoListView extends ConsumerWidget {
  const _TodoListView({required this.watch, required this.emptyMessage});

  /// `(ref) => ref.watch(someProvider)` — passed as a closure rather than a
  /// provider reference directly, since the different tabs' sources are a
  /// mix of plain providers and `.family` ones instantiated with an
  /// argument, which don't share one convenient static type to hold here.
  final AsyncValue<List<TodoRow>> Function(WidgetRef ref) watch;
  final String emptyMessage;

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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.xs,
          ),
          itemCount: todos.length,
          itemBuilder: (context, i) => _SmartTodoTile(todo: todos[i]),
        );
      },
    );
  }
}

class _SmartTodoTile extends ConsumerWidget {
  const _SmartTodoTile({required this.todo});
  final TodoRow todo;

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

    return InkWell(
      onTap: () => showTodoDetailSheet(context, todo),
      borderRadius: AppRadius.cardMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            InkWell(
              onTap: () => ref
                  .read(todoControllerProvider)
                  .toggle(todo.id, !todo.isDone),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: Icon(
                  todo.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: todo.isDone
                      ? palette.accent
                      : isOverdue
                      ? palette.danger
                      : palette.inkFaint,
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
                            color: todo.isDone ? palette.inkFaint : palette.ink,
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
    );
  }
}
