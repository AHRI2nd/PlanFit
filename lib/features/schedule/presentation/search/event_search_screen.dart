import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/di.dart';
import '../../../../core/format.dart';
import '../../../../core/time_format.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../../design/widgets/section_header.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../todo/application/todo_providers.dart';
import '../../../todo/domain/todo_priority.dart';
import '../../../todo/domain/todo_tag_match.dart';
import '../../application/schedule_providers.dart';
import '../event_edit/event_editor_sheet.dart';

/// Full-text search over both events (title/memo) and to-dos (title).
/// Tapping an event result jumps the schedule tab to that day (in day view)
/// and opens it for editing; a to-do result just jumps to its day — to-dos
/// are edited inline in the day view's hourly list, not in a separate editor.
class EventSearchScreen extends ConsumerStatefulWidget {
  const EventSearchScreen({super.key});

  @override
  ConsumerState<EventSearchScreen> createState() => _EventSearchScreenState();
}

class _EventSearchScreenState extends ConsumerState<EventSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<EventRow>? _eventResults;
  List<TodoRow>? _todoResults;
  bool _loading = false;

  /// Bumped every time a new debounced search actually starts (not on every
  /// keystroke — the [Timer] cancel/reset above already coalesces those).
  /// The debounce alone only stops two *pending* searches from both firing;
  /// it doesn't stop an *in-flight* one from finishing after a newer one
  /// was kicked off. A broader query (e.g. "a") can take longer to scan
  /// than a narrower one typed right after it (e.g. "abc"), so without
  /// this, the slower/older search's results could land last and overwrite
  /// the results for a query the user has since moved past.
  int _searchGeneration = 0;
  TodoPriority? _priorityFilter;
  String? _tagFilter;
  EventColorTag? _colorFilter;
  DateTimeRange? _dateRangeFilter;

  /// [_todoResults] narrowed by the priority/tag filter chips — the title
  /// match already happened in [_onChanged]; this is a further, purely
  /// client-side refinement of that same result set.
  List<TodoRow> get _filteredTodoResults {
    final todos = _todoResults;
    if (todos == null) return const [];
    return todos.where((todo) {
      if (_priorityFilter != null && todo.priority != _priorityFilter!.value) {
        return false;
      }
      if (_tagFilter != null && !todoHasTag(todo, _tagFilter!)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// [_eventResults] narrowed by the color/date-range filter chips — same
  /// client-side refinement of the title/memo match as [_filteredTodoResults].
  /// A custom (non-preset) hex color never matches [_colorFilter], since the
  /// filter only offers the same 6 presets as the editor's color picker.
  List<EventRow> get _filteredEventResults {
    final events = _eventResults;
    if (events == null) return const [];
    return events.where((event) {
      if (_colorFilter != null &&
          EventColorTag.tryParse(event.colorTag) != _colorFilter) {
        return false;
      }
      final range = _dateRangeFilter;
      if (range != null) {
        final day = dateOnly(event.startAt);
        if (day.isBefore(range.start) || day.isAfter(range.end)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _eventResults = null;
        _todoResults = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final generation = ++_searchGeneration;
      final results = await Future.wait([
        ref.read(eventRepositoryProvider).search(trimmed),
        ref.read(todoDaoProvider).search(trimmed),
      ]);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _eventResults = results[0] as List<EventRow>;
        _todoResults = results[1] as List<TodoRow>;
        _loading = false;
      });
    });
  }

  void _openEvent(EventRow event) {
    ref.read(selectedDateProvider.notifier).select(event.startAt);
    ref.read(scheduleViewProvider.notifier).set(ScheduleView.day);
    Navigator.of(context).pop();
    showEventEditor(context, existing: event);
  }

  void _openTodo(TodoRow todo) {
    ref.read(selectedDateProvider.notifier).select(todo.slotStart);
    ref.read(scheduleViewProvider.notifier).set(ScheduleView.day);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            filled: false,
            // Zeroing this out entirely (as this used to) also zeroed the
            // horizontal inset, so the cursor/hint text started right under
            // the InputDecorationTheme's own focusedBorder's rounded corner
            // (border: InputBorder.none above only clears the *default*
            // border — the theme's focusedBorder/enabledBorder still apply
            // since neither is overridden here) instead of past it. A first
            // fix that only added `vertical: 8` to this EdgeInsets.symmetric
            // left `horizontal` defaulted right back to 0 — same bug, still
            // there. isDense trims the excess vertical height a default
            // InputDecorator would add (which is what contentPadding: zero
            // was originally trying to fix) without collapsing the
            // horizontal inset needed to clear that rounded corner.
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
          ),
        ),
      ),
      body: _buildBody(context, l10n, palette, theme, locale),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppL10n l10n,
    AppPalette palette,
    ThemeData theme,
    String locale,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final events = _eventResults;
    final todos = _todoResults;
    if (events == null || todos == null) {
      return _Placeholder(icon: Icons.search, message: l10n.searchPrompt);
    }
    if (events.isEmpty && todos.isEmpty) {
      return _Placeholder(icon: Icons.search_off, message: l10n.searchEmpty);
    }
    final filteredTodos = _filteredTodoResults;
    final filteredEvents = _filteredEventResults;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.sm,
      ),
      children: [
        if (events.isNotEmpty) ...[
          SectionHeader(l10n.searchSectionEvents),
          _EventFilterRow(
            colorFilter: _colorFilter,
            dateRangeFilter: _dateRangeFilter,
            locale: locale,
            onColorChanged: (c) => setState(() => _colorFilter = c),
            onDateRangeChanged: (r) => setState(() => _dateRangeFilter = r),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (filteredEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.searchEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.inkFaint,
                ),
              ),
            ),
          for (final event in filteredEvents)
            _EventResultTile(
              event: event,
              locale: locale,
              onTap: () => _openEvent(event),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (todos.isNotEmpty) ...[
          SectionHeader(l10n.searchSectionTodos),
          _TodoFilterRow(
            priorityFilter: _priorityFilter,
            tagFilter: _tagFilter,
            onPriorityChanged: (p) => setState(() => _priorityFilter = p),
            onTagChanged: (t) => setState(() => _tagFilter = t),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (filteredTodos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.searchEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.inkFaint,
                ),
              ),
            ),
          for (final todo in filteredTodos)
            _TodoResultTile(
              todo: todo,
              locale: locale,
              onTap: () => _openTodo(todo),
            ),
        ],
      ],
    );
  }
}

/// Color/date-range filter chips shown above the event results — narrows the
/// already title/memo-matched event list further, purely client-side (see
/// `_EventSearchScreenState._filteredEventResults`).
class _EventFilterRow extends StatelessWidget {
  const _EventFilterRow({
    required this.colorFilter,
    required this.dateRangeFilter,
    required this.locale,
    required this.onColorChanged,
    required this.onDateRangeChanged,
  });

  final EventColorTag? colorFilter;
  final DateTimeRange? dateRangeFilter;
  final String locale;
  final ValueChanged<EventColorTag?> onColorChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: dateRangeFilter,
    );
    if (picked != null) onDateRangeChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final range = dateRangeFilter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: Text(l10n.searchFilterAll),
              selected: colorFilter == null,
              onSelected: (_) => onColorChanged(null),
              showCheckmark: false,
            ),
            for (final tag in EventColorTag.values)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: tag.color),
                label: const SizedBox.shrink(),
                labelPadding: EdgeInsets.zero,
                selected: colorFilter == tag,
                onSelected: (_) => onColorChanged(tag),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        InputChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(
            range == null
                ? l10n.searchFilterDateRangePick
                : '${Fmt.monthDay(range.start, locale)} - ${Fmt.monthDay(range.end, locale)}',
          ),
          onPressed: () => _pickDateRange(context),
          onDeleted: range == null ? null : () => onDateRangeChanged(null),
          deleteIcon: const Icon(Icons.close, size: 16),
          deleteButtonTooltipMessage: l10n.searchFilterDateRangeClear,
          backgroundColor: range == null
              ? null
              : palette.accent.withValues(alpha: 0.15),
        ),
      ],
    );
  }
}

class _EventResultTile extends ConsumerWidget {
  const _EventResultTile({
    required this.event,
    required this.locale,
    required this.onTap,
  });

  final EventRow event;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final accent = EventColorTag.resolve(event.colorTag, event.startAt);
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 30,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: AppRadius.allPill,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title.isEmpty ? '—' : event.title,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    event.isAllDay
                        ? Fmt.monthDay(event.startAt, locale)
                        : '${Fmt.monthDay(event.startAt, locale)}  ${Fmt.time(event.startAt, locale, use24Hour: use24)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Priority/tag filter chips shown above the to-do results — narrows the
/// already title-matched to-do list further, purely client-side (see
/// `_EventSearchScreenState._filteredTodoResults`).
class _TodoFilterRow extends ConsumerWidget {
  const _TodoFilterRow({
    required this.priorityFilter,
    required this.tagFilter,
    required this.onPriorityChanged,
    required this.onTagChanged,
  });

  final TodoPriority? priorityFilter;
  final String? tagFilter;
  final ValueChanged<TodoPriority?> onPriorityChanged;
  final ValueChanged<String?> onTagChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final tagsAsync = ref.watch(todoTagsProvider);
    final tags = tagsAsync.value ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: Text(l10n.searchFilterAll),
              selected: priorityFilter == null,
              onSelected: (_) => onPriorityChanged(null),
              showCheckmark: false,
            ),
            for (final p in TodoPriority.values)
              ChoiceChip(
                label: Text(p.label(l10n)),
                selected: priorityFilter == p,
                onSelected: (_) => onPriorityChanged(p),
                showCheckmark: false,
                selectedColor: p.color(palette) ?? palette.accent,
                labelStyle: TextStyle(
                  color: priorityFilter == p ? Colors.white : palette.inkSoft,
                ),
              ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              ChoiceChip(
                label: Text(l10n.searchFilterAll),
                selected: tagFilter == null,
                onSelected: (_) => onTagChanged(null),
                showCheckmark: false,
              ),
              for (final tag in tags)
                ChoiceChip(
                  label: Text(tag),
                  selected: tagFilter == tag,
                  onSelected: (_) => onTagChanged(tag),
                  showCheckmark: false,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TodoResultTile extends ConsumerWidget {
  const _TodoResultTile({
    required this.todo,
    required this.locale,
    required this.onTap,
  });

  final TodoRow todo;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              todo.isDone ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: todo.isDone ? palette.inkFaint : palette.accent,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title.isEmpty ? '—' : todo.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: todo.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: todo.isDone ? palette.inkFaint : null,
                    ),
                  ),
                  Text(
                    todo.hasTime
                        ? '${Fmt.monthDay(todo.slotStart, locale)}  ${Fmt.time(todo.slotStart, locale, use24Hour: use24)}'
                        : '${Fmt.monthDay(todo.slotStart, locale)}  ${AppL10n.of(context).todoNoTime}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: palette.inkFaint),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
