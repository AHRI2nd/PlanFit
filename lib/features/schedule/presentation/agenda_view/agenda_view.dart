import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date_math.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/di.dart';
import '../../../../core/format.dart';
import '../../../../core/time_format.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../../design/widgets/section_header.dart';
import '../../../../design/widgets/snackbar_x.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../todo/application/todo_providers.dart';
import '../../../todo/domain/todo_overdue.dart';
import '../../../todo/presentation/todo_detail_sheet.dart';
import '../../application/schedule_providers.dart';
import '../../domain/agenda_grouping.dart';
import '../event_edit/event_editor_sheet.dart';

/// One row of the agenda's flattened, `ListView.builder`-indexable list —
/// either a day header or an entry (event or to-do) tile, never both.
/// [isLastInGroup] only means anything for a tile row: it's the last entry
/// under its day header, so it gets the wider trailing gap before the next
/// header that the plain [ListView] version got from a separate spacer
/// widget.
class _AgendaRow {
  const _AgendaRow.header(this.day) : entry = null, isLastInGroup = false;
  const _AgendaRow.tile(this.entry, {required this.isLastInGroup}) : day = null;

  final DateTime? day;
  final AgendaEntry? entry;
  final bool isLastInGroup;
}

/// A flat, scrollable list of upcoming events grouped under date headers —
/// the "everything at a glance" counterpart to the day/week/month/year
/// grids, closer to how most calendar apps' list view reads. See
/// [eventsForAgendaProvider] for the window this covers.
///
/// Also the one event surface with a multi-select mode (long-press a tile):
/// unlike the day/week grids, these tiles have no drag-to-move/resize or
/// swipe-to-delete gesture of their own to fight over the same touch input,
/// so selection can safely repurpose tap/long-press here without conflict.
class AgendaView extends ConsumerStatefulWidget {
  const AgendaView({super.key, required this.anchor});

  final DateTime anchor;

  @override
  ConsumerState<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends ConsumerState<AgendaView> {
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

  Future<void> _bulkDelete(List<EventRow> current) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(eventRepositoryProvider);
    final byId = {for (final e in current) e.id: e};
    final removed = [for (final id in _selectedIds) ?byId[id]];

    for (final e in removed) {
      await repo.delete(e.id);
    }
    if (mounted) _exitSelection();

    messenger.showAutoDismissSnackBar(
      SnackBar(
        content: Text(l10n.eventSelectionDeleted(removed.length)),
        action: SnackBarAction(
          label: l10n.eventUndo,
          // restoreEvent(), not save() — see day_view.dart's _EventCard._delete
          // for why save() would silently sever recurrence/OS-calendar links.
          onPressed: () async {
            for (final e in removed) {
              await repo.restoreEvent(e);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final eventsAsync = ref.watch(eventsForAgendaProvider(widget.anchor));
    // Watched leniently (loading/error both read as "no to-dos yet") —
    // same pattern month_view.dart/year_view.dart already use for their own
    // secondary to-do watch, so a slow or momentarily-erroring to-do stream
    // never blocks the event list (the primary data this screen gates on)
    // from rendering.
    final todos =
        ref.watch(todosForAgendaProvider(widget.anchor)).asData?.value ??
        const <TodoRow>[];

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (events) {
        final groups = groupAgendaEntriesByDay(events, todos);
        if (groups.isEmpty) {
          return _AgendaEmpty(l10n: l10n);
        }
        // Flattened to one (row-kind, payload) list so ListView.builder can
        // build lazily by index — the window this provider watches spans up
        // to 187 days (see eventsForAgendaProvider's doc), so building every
        // day header and tile eagerly (the previous plain ListView) meant
        // ~400-550 widgets constructed on every open/data change instead of
        // just what the viewport shows.
        final rows = <_AgendaRow>[
          for (final (day, dayEntries) in groups) ...[
            _AgendaRow.header(day),
            for (var i = 0; i < dayEntries.length; i++)
              _AgendaRow.tile(
                dayEntries[i],
                isLastInGroup: i == dayEntries.length - 1,
              ),
          ],
        ];
        return Column(
          children: [
            if (_selectionMode)
              _AgendaSelectionToolbar(
                count: _selectedIds.length,
                l10n: l10n,
                onCancel: _exitSelection,
                onDelete: () => _bulkDelete(events),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xs,
                  AppSpacing.gutter,
                  140,
                ),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final day = row.day;
                  if (day != null) return _DayHeader(day: day);
                  return Padding(
                    // The last tile in a group carries its own AppSpacing.xs
                    // gap *plus* the AppSpacing.sm the old layout gave the
                    // group as a whole (a separate trailing SizedBox) — same
                    // combined gap before the next day's header, just folded
                    // into one Padding instead of two sibling widgets.
                    padding: EdgeInsets.only(
                      bottom: row.isLastInGroup
                          ? AppSpacing.xs + AppSpacing.sm
                          : AppSpacing.xs,
                    ),
                    child: switch (row.entry!) {
                      AgendaEventEntry(:final event) => _AgendaTile(
                        event: event,
                        selectionMode: _selectionMode,
                        selected: _selectedIds.contains(event.id),
                        onToggleSelected: () => _toggleSelected(event.id),
                        onEnterSelection: () => _enterSelection(event.id),
                      ),
                      // To-dos are tap-only — deliberately outside this
                      // view's multi-select/bulk-delete mode, which is
                      // event-only (TodoController has no bulk-remove path
                      // to hook up), regardless of whether that mode is
                      // currently active for events.
                      AgendaTodoEntry(:final todo) => _AgendaTodoTile(
                        todo: todo,
                      ),
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Mirrors `_SelectionToolbar` in hourly_todo_list.dart, minus the "mark
/// done" action — events have no done state to bulk-toggle, only delete.
class _AgendaSelectionToolbar extends StatelessWidget {
  const _AgendaSelectionToolbar({
    required this.count,
    required this.l10n,
    required this.onCancel,
    required this.onDelete,
  });

  final int count;
  final AppL10n l10n;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xs,
      ),
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
              l10n.eventSelectionCount(count),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.inkSoft),
            ),
          ),
          IconButton(
            tooltip: l10n.eventSelectionDelete,
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline, color: palette.danger),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = dateOnly(DateTime.now());
    final tomorrow = addCalendarDays(today, 1);

    final label = day == today
        ? '${l10n.commonToday} · ${Fmt.monthDay(day, locale)}'
        : day == tomorrow
        ? '${l10n.commonTomorrow} · ${Fmt.monthDay(day, locale)}'
        : '${Fmt.monthDay(day, locale)} ${Fmt.weekdayShort(day, locale)}';

    return SectionHeader(label);
  }
}

class _AgendaTile extends ConsumerWidget {
  const _AgendaTile({
    required this.event,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
    this.onEnterSelection,
  });

  final EventRow event;

  /// Whether the agenda view is in multi-select mode — while true, tapping
  /// this tile toggles [selected] instead of opening the editor, and
  /// long-press is disabled (there's no "enter" to do from inside the mode
  /// that's already active).
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;

  /// Long-pressing the tile while not already in selection mode enters it,
  /// pre-selecting this event.
  final VoidCallback? onEnterSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final accent = EventColorTag.resolve(event.colorTag, event.startAt);
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );

    return Container(
      color: selected ? palette.accent.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: selectionMode
            ? onToggleSelected
            : () => showEventEditor(context, existing: event),
        onLongPress: selectionMode ? null : onEnterSelection,
        borderRadius: AppRadius.cardMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? palette.accent : palette.inkFaint,
                  ),
                ),
              SizedBox(
                width: 52,
                child: Text(
                  event.isAllDay
                      ? l10n.eventAllDay
                      : Fmt.time(event.startAt, locale, use24Hour: use24),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.inkSoft,
                  ),
                ),
              ),
              Container(
                width: 3,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (event.location != null && event.location!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: palette.inkFaint,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              event.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.inkFaint,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (event.notify)
                Icon(
                  Icons.notifications_active_outlined,
                  size: 15,
                  color: palette.inkFaint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A to-do's row in the merged agenda list — same visual language as
/// [_AgendaTile] (52px time column, 3px accent bar, title) but tap-only:
/// no selection checkbox, no long-press-to-select, since to-dos sit outside
/// this view's event-only multi-select/bulk-delete mode (see the switch in
/// [_AgendaViewState.build] for why).
class _AgendaTodoTile extends ConsumerWidget {
  const _AgendaTodoTile({required this.todo});

  final TodoRow todo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final overdue = isTodoOverdue(todo, DateTime.now());
    final accent = overdue ? palette.danger : palette.todoAccent;
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Text(
                !todo.hasTime
                    ? l10n.todoNoTime
                    : Fmt.time(todo.slotStart, locale, use24Hour: use24),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.inkSoft,
                ),
              ),
            ),
            Container(
              width: 3,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: AppRadius.allPill,
              ),
            ),
            Icon(
              todo.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: todo.isDone ? palette.todoAccent : palette.inkFaint,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                todo.title.isEmpty ? '—' : todo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: todo.isDone ? palette.inkFaint : null,
                  decoration: todo.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaEmpty extends StatelessWidget {
  const _AgendaEmpty({required this.l10n});
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 40,
              color: palette.inkFaint,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.agendaEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
