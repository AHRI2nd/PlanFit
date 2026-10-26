import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/date_math.dart';
import '../../../core/db/app_database.dart';
import '../../../core/di.dart';
import '../../../design/widgets/app_dialog.dart';
import '../../../design/widgets/async_content.dart';
import '../../../design/glass/glass_nav_bar.dart' show navBarClearance;
import '../../../l10n/app_localizations.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../settings/application/settings_controller.dart';
import '../../todo/presentation/todo_detail_sheet.dart';
import '../../todo/presentation/todo_selection.dart';

final weeklyPlannedProvider = StreamProvider.autoDispose
    .family<List<TodoRow>, DateTime>(
      (ref, start) => ref
          .watch(todoDaoProvider)
          .watchScheduledBetween(start, addCalendarDays(start, 7)),
    );
final weeklyCompletedProvider = StreamProvider.autoDispose
    .family<List<TodoRow>, DateTime>(
      (ref, start) => ref
          .watch(todoDaoProvider)
          .watchCompletedBetween(start, addCalendarDays(start, 7)),
    );

class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});
  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen>
    with TodoSelectionMixin<WeeklyReviewScreen> {
  DateTime? _anchor;
  void _change(DateTime day) {
    if (selectionBusy) return;
    setState(() {
      _anchor = day;
      selectionMode = false;
      selectedIds.clear();
    });
  }

  String _date(DateTime value) => '${value.year}/${value.month}/${value.day}';
  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final start = startOfWeek(
      _anchor ?? ref.watch(todayProvider),
      startWeekday: ref.watch(weekStartWeekdayProvider),
    );
    final planned = ref.watch(weeklyPlannedProvider(start));
    final completed = ref.watch(weeklyCompletedProvider(start));
    final retention = ref
        .watch(settingsControllerProvider)
        .completedTodoRetentionDays;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewTitle)),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: selectionBusy
                    ? null
                    : () => _change(addCalendarDays(start, -7)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  onPressed: selectionBusy
                      ? null
                      : () async {
                          final date = await showAppDatePicker(
                            context: context,
                            initialDate: start,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2200),
                          );
                          if (mounted && date != null) _change(date);
                        },
                  child: Text(
                    '${_date(start)} – ${_date(addCalendarDays(start, 6))}',
                  ),
                ),
              ),
              IconButton(
                onPressed: selectionBusy
                    ? null
                    : () => _change(addCalendarDays(start, 7)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (selectionMode)
            TodoSelectionToolbar(
              count: selectedIds.length,
              l10n: l10n,
              busy: selectionBusy,
              onCancel: exitSelection,
              onComplete: bulkComplete,
              onDelete: bulkDelete,
              onReschedule: () =>
                  bulkReschedule(suggestedDay: addCalendarDays(start, 7)),
            ),
          Expanded(
            child: AsyncContent<List<TodoRow>>(
              value: planned,
              onRetry: () => ref.invalidate(weeklyPlannedProvider(start)),
              builder: (scheduled) => ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  navBarClearance(context) + 16,
                ),
                children: [
                  Text(l10n.reviewRetained),
                  if (retention != null)
                    Text('${l10n.reviewRetention} ($retention)'),
                  const SizedBox(height: 16),
                  Text(
                    '${l10n.reviewPlanned} · ${scheduled.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (scheduled.isEmpty) Text(l10n.commonNoRecords),
                  for (final row in scheduled)
                    ListTile(
                      leading: row.isDone
                          ? const Icon(Icons.check_circle_outline)
                          : Checkbox(
                              value: selectedIds.contains(row.id),
                              onChanged: selectionBusy
                                  ? null
                                  : (_) => selectionMode
                                        ? toggleSelected(row.id)
                                        : enterSelection(row.id),
                            ),
                      title: Text(row.title),
                      subtitle: Text(
                        '${_date(row.slotStart)}${row.isDone ? ' · ${row.completedAt == null ? l10n.reviewUnknown : _date(row.completedAt!)}' : ''}',
                      ),
                      onLongPress: row.isDone
                          ? null
                          : () => enterSelection(row.id),
                      onTap: selectionBusy
                          ? null
                          : () => selectionMode && !row.isDone
                                ? toggleSelected(row.id)
                                : showTodoDetailSheet(context, row),
                    ),
                  const SizedBox(height: 16),
                  AsyncContent<List<TodoRow>>(
                    value: completed,
                    onRetry: () =>
                        ref.invalidate(weeklyCompletedProvider(start)),
                    builder: (done) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.reviewCompleted} · ${done.length}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (done.isEmpty) Text(l10n.commonNoRecords),
                        for (final row in done)
                          ListTile(
                            title: Text(row.title),
                            subtitle: Text(_date(row.completedAt!)),
                            onTap: () => showTodoDetailSheet(context, row),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
