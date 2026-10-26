import '../../schedule/domain/day_clock_geometry.dart' show clampedMinutesOfDay;
import '../../schedule/application/schedule_providers.dart' show dateOnly;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/date_math.dart';
import '../../../core/db/app_database.dart';
import '../../../core/format.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/todo_time_block.dart';
import 'todo_time_block_sheet.dart';

/// A dedicated lane keeps todo intervals distinct from regular calendar events.
/// Cards use their actual clipped bounds; details provide full-size editing controls.
class TodoBlockLane extends StatelessWidget {
  const TodoBlockLane({super.key, required this.rows, required this.day, required this.hourHeight, required this.use24Hour});
  final List<TodoRow> rows;
  final DateTime day;
  final double hourHeight;
  final bool use24Hour;
  @override
  Widget build(BuildContext context) {
    final blocks = rows.where((r) => !r.isDone && TodoTimeBlock.of(r) != null)
      .where((r) => r.slotStart.isBefore(addCalendarDays(dateOnly(day), 1)) && r.slotEnd!.isAfter(dateOnly(day))).toList()
      ..sort((a,b) => a.slotStart.compareTo(b.slotStart));
    final columns = <DateTime>[];
    final placements = <(TodoRow, int)>[];
    for (final row in blocks) {
      var column = columns.indexWhere((end) => !end.isAfter(row.slotStart));
      if (column < 0) { column = columns.length; columns.add(row.slotEnd!); } else { columns[column] = row.slotEnd!; }
      placements.add((row, column));
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final l10n = AppL10n.of(context);
    double offset(DateTime value) => clampedMinutesOfDay(day, value) / 60 * hourHeight;
    return LayoutBuilder(builder: (context, constraints) => Stack(children: [
      for (final (row, column) in placements) Positioned(
        key: ValueKey('todo-block-${row.id}-${dateOnly(day)}'),
        top: offset(row.slotStart), height: math.max(1, offset(row.slotEnd!) - offset(row.slotStart)),
        left: column * constraints.maxWidth / columns.length, width: constraints.maxWidth / columns.length,
        child: Semantics(button: true, label: '${l10n.blockTimeline}: ${row.title}', child: Tooltip(
          message: '${row.title}\n${Fmt.monthDay(row.slotStart, locale)} ${Fmt.time(row.slotStart, locale, use24Hour: use24Hour)} – ${Fmt.monthDay(row.slotEnd!, locale)} ${Fmt.time(row.slotEnd!, locale, use24Hour: use24Hour)} · ${l10n.durationMinutes(row.slotEnd!.difference(row.slotStart).inMinutes)}',
          child: Material(color: context.palette.accent.withValues(alpha: .18),
            shape: RoundedRectangleBorder(side: BorderSide(color: context.palette.accent), borderRadius: BorderRadius.circular(4)),
            clipBehavior: Clip.hardEdge, child: InkWell(onTap: () => showTodoTimeBlockSheet(context, row),
              child: Padding(padding: const EdgeInsets.all(2), child: Text(row.title, overflow: TextOverflow.clip, style: Theme.of(context).textTheme.labelSmall))))))),
    ]));
  }
}
