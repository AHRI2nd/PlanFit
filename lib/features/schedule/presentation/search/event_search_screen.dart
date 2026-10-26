import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/date_math.dart';
import '../../../../core/search/search_options.dart';
import '../../../../core/di.dart';
import '../../../../core/format.dart';
import '../../../../core/time_format.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../../design/widgets/section_header.dart';
import '../../../../design/widgets/app_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../todo/application/todo_providers.dart';
import '../../../todo/domain/todo_priority.dart';
import '../../../todo/domain/todo_tag_match.dart';
import '../../../todo/presentation/todo_detail_sheet.dart';
import '../../application/schedule_providers.dart';
import '../../application/search_memory.dart';
import '../event_edit/event_editor_sheet.dart';
import '../event_edit/event_preview_sheet.dart';

/// Full-text search over both events (title/memo) and to-dos (title).
/// Tapping an event result jumps the schedule tab to that day (in day view)
/// and opens it for editing; a to-do result opens its detail sheet above the
/// search results so the query stays available when the detail is dismissed.
class EventSearchScreen extends ConsumerStatefulWidget {
  const EventSearchScreen({super.key});

  @override
  ConsumerState<EventSearchScreen> createState() => _EventSearchScreenState();
}

class _EventSearchScreenState extends ConsumerState<EventSearchScreen> {
  late final TextEditingController _controller;
  Timer? _debounce;
  List<EventRow>? _eventResults;
  List<TodoRow>? _todoResults;
  bool _loading = false;
  static const _pageSize = 50;
  bool _hasMoreEvents = false;
  bool _hasMoreTodos = false;
  bool _loadingMoreEvents = false;
  bool _loadingMoreTodos = false;

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
  String? _colorFilter;
  bool _includeCompleted = true;
  SearchResultType _type = SearchResultType.all;
  DateTimeRange? _dateRangeFilter;

  @override
  void initState() {
    super.initState();
    final memory = ref.read(searchMemoryProvider);
    _priorityFilter = memory.options.priority == null ? null
        : TodoPriority.fromValue(memory.options.priority!);
    _tagFilter = memory.options.tag;
    _colorFilter = memory.options.colorTag;
    _includeCompleted = memory.options.includeCompleted;
    _type = memory.type;
    if (memory.options.from != null && memory.options.to != null) {
      _dateRangeFilter = DateTimeRange(start: memory.options.from!,
        end: addCalendarDays(memory.options.to!, -1));
    }
    final query = ref.read(eventSearchQueryProvider);
    _controller = TextEditingController(text: query);
    if (query.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onChanged(query);
      });
    }
  }

  SearchOptions get _options => SearchOptions(
    from: _dateRangeFilter?.start,
    to: _dateRangeFilter == null ? null : addCalendarDays(_dateRangeFilter!.end, 1),
    colorTag: _colorFilter, priority: _priorityFilter?.value, tag: _tagFilter,
    includeCompleted: _includeCompleted, limit: _pageSize,
  );

  void _changeFilters(VoidCallback update) {
    setState(update);
    ref.read(searchMemoryProvider.notifier).save(SearchMemory(options: _options, type: _type));
    _onChanged(_controller.text);
  }

  /// [_todoResults] narrowed by the priority/tag filter chips — the title
  /// match already happened in [_onChanged]; this is a further, purely
  /// client-side refinement of that same result set.
  List<TodoRow> get _filteredTodoResults {
    final todos = _todoResults;
    if (todos == null) return const [];
    return todos.where((todo) {
      if (!_includeCompleted && todo.isDone) return false;
      if (_options.from != null && todo.slotStart.isBefore(_options.from!)) return false;
      if (_options.to != null && !todo.slotStart.isBefore(_options.to!)) return false;
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
          event.colorTag?.toUpperCase() != _colorFilter?.toUpperCase()) {
        return false;
      }
      final range = _dateRangeFilter;
      if (range != null) {
        if (!event.endAt.isAfter(range.start) ||
            !event.startAt.isBefore(addCalendarDays(range.end, 1))) {
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
    ref.read(eventSearchQueryProvider.notifier).set(trimmed);
    if (trimmed.isEmpty) {
      // Invalidate any search still in flight from before the box was
      // cleared — cancelling the debounce Timer above only stops a
      // *pending* search from starting, not one that already started and
      // is still awaiting its Future.wait. Without bumping the generation
      // here too, that older search's captured generation still matches
      // _searchGeneration when it finally resolves, so its results
      // silently overwrite the empty state this clear just set.
      _searchGeneration++;
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
        ref.read(eventRepositoryProvider).search(trimmed, options: _options),
        ref.read(todoDaoProvider).search(trimmed, options: _options),
      ]);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _eventResults = results[0] as List<EventRow>;
        _todoResults = results[1] as List<TodoRow>;
        _hasMoreEvents = _eventResults!.length == _pageSize;
        _hasMoreTodos = _todoResults!.length == _pageSize;
        _loadingMoreEvents = false;
        _loadingMoreTodos = false;
        _loading = false;
      });
    });
  }

  Future<void> _loadMore(bool events) async {
    if ((events ? _loadingMoreEvents : _loadingMoreTodos) || _loading) return;
    final generation = _searchGeneration;
    final query = _controller.text.trim();
    final cursor = events
        ? SearchCursor(_eventResults!.last.startAt, _eventResults!.last.id)
        : SearchCursor(_todoResults!.last.slotStart, _todoResults!.last.id);
    final options = _options.pageAfter(cursor);
    setState(() { if (events) { _loadingMoreEvents = true; } else { _loadingMoreTodos = true; } });
    try {
      if (events) {
        final rows = await ref.read(eventRepositoryProvider).search(query, options: options);
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _eventResults = {for (final row in [..._eventResults!, ...rows]) row.id: row}.values.toList();
          _hasMoreEvents = rows.length == _pageSize;
        });
      } else {
        final rows = await ref.read(todoDaoProvider).search(query, options: options);
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _todoResults = {for (final row in [..._todoResults!, ...rows]) row.id: row}.values.toList();
          _hasMoreTodos = rows.length == _pageSize;
        });
      }
    } catch (_) {
      if (mounted && generation == _searchGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppL10n.of(context).errorWidgetFallback)));
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() { if (events) { _loadingMoreEvents = false; } else { _loadingMoreTodos = false; } });
      }
    }
  }

  /// Tap target: closes search, jumps the day view to the event's own day,
  /// then opens the read-only preview over it — same as every other event
  /// surface's tap now does.
  void _previewEvent(EventRow event) {
    ref.read(selectedDateProvider.notifier).select(event.startAt);
    ref.read(scheduleViewProvider.notifier).set(ScheduleView.day);
    Navigator.of(context).pop();
    showEventPreview(context, event: event);
  }

  /// Long-press target: same jump-and-close, but straight to the full
  /// editor instead of the preview.
  void _editEvent(EventRow event) {
    ref.read(selectedDateProvider.notifier).select(event.startAt);
    ref.read(scheduleViewProvider.notifier).set(ScheduleView.day);
    Navigator.of(context).pop();
    showEventEditor(context, existing: event);
  }

  void _openTodo(TodoRow todo) {
    showTodoDetailSheet(context, todo);
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
    final filteredTodos = _filteredTodoResults;
    final filteredEvents = _filteredEventResults;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.sm,
      ),
      children: [
        DropdownButton<SearchResultType>(
          value: _type, isExpanded: true,
          items: [
            DropdownMenuItem(value: SearchResultType.all, child: Text(l10n.searchFilterAll)),
            DropdownMenuItem(value: SearchResultType.events, child: Text(l10n.searchSectionEvents)),
            DropdownMenuItem(value: SearchResultType.todos, child: Text(l10n.searchSectionTodos)),
          ],
          onChanged: (type) { if (type != null) _changeFilters(() => _type = type); },
        ),
        _EventFilterRow(colorFilter: _colorFilter, dateRangeFilter: _dateRangeFilter,
          locale: locale, onColorChanged: (c) => _changeFilters(() => _colorFilter = c),
          onDateRangeChanged: (r) => _changeFilters(() => _dateRangeFilter = r)),
        if (_type != SearchResultType.events)
          FilterChip(label: Text(l10n.searchIncludeCompleted), selected: _includeCompleted,
            onSelected: (value) => _changeFilters(() => _includeCompleted = value)),
        if (filteredEvents.isEmpty && filteredTodos.isEmpty)
          _Placeholder(icon: Icons.search_off, message: l10n.searchEmpty),
        if (events.isNotEmpty && _type != SearchResultType.todos) ...[
          SectionHeader(l10n.searchSectionEvents),

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
              onTap: () => _previewEvent(event),
              onLongPress: () => _editEvent(event),
            ),
          if (_hasMoreEvents) TextButton(onPressed: _loadingMoreEvents ? null : () => _loadMore(true),
            child: Text(l10n.searchMoreEvents)),
          const SizedBox(height: AppSpacing.md),
        ],
        if (todos.isNotEmpty && _type != SearchResultType.events) ...[
          SectionHeader(l10n.searchSectionTodos),
          _TodoFilterRow(
            priorityFilter: _priorityFilter,
            tagFilter: _tagFilter,
            onPriorityChanged: (p) => _changeFilters(() => _priorityFilter = p),
            onTagChanged: (t) => _changeFilters(() => _tagFilter = t),
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
          if (_hasMoreTodos) TextButton(onPressed: _loadingMoreTodos ? null : () => _loadMore(false),
            child: Text(l10n.searchMoreTodos)),
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

  final String? colorFilter;
  final DateTimeRange? dateRangeFilter;
  final String locale;
  final ValueChanged<String?> onColorChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;

  Future<void> _pickCustomColor(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final controller = TextEditingController(text: colorFilter?.startsWith('#') == true ? colorFilter : '');
    String? error;
    final value = await showAppDialog<String>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text(l10n.searchCustomColor),
        content: TextField(controller: controller, decoration: InputDecoration(
          hintText: '#RRGGBB', errorText: error)),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () {
            final color = controller.text.trim().toUpperCase();
            if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(color)) {
              setDialogState(() => error = l10n.searchInvalidColor); return;
            }
            Navigator.pop(dialogContext, color);
          }, child: Text(l10n.eventSave))],
      )));
    controller.dispose();
    if (value != null && context.mounted) onColorChanged(value);
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: dateRangeFilter,
      useRootNavigator: kDialogUsesRootNavigator,
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
                selected: colorFilter == tag.name,
                onSelected: (_) => onColorChanged(tag.name),
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
    required this.onLongPress,
  });

  final EventRow event;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
      onLongPress: onLongPress,
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
