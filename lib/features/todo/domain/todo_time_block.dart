import 'package:drift/drift.dart' show Value;
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/todo_dao.dart';
import '../../../core/db/sync_status.dart';

class TodoTimeBlock {
  TodoTimeBlock(this.start, this.end) {
    if (!end.isAfter(start)) throw ArgumentError('End must follow start');
  }
  final DateTime start;
  final DateTime end;
  Duration get duration => end.difference(start);
  bool overlaps(TodoTimeBlock other) =>
      start.isBefore(other.end) && end.isAfter(other.start);
  static TodoTimeBlock? of(TodoRow row) =>
      row.hasTime && row.slotEnd != null && row.slotEnd!.isAfter(row.slotStart)
      ? TodoTimeBlock(row.slotStart, row.slotEnd!)
      : null;
}

class TimeBlockSaveResult {
  const TimeBlockSaveResult({
    required this.saved,
    this.deferred = false,
    this.conflicts = const [],
  });
  final bool saved;
  final bool deferred;
  final List<TimeBlockConflict> conflicts;
}

class TodoTimeBlockWriter {
  TodoTimeBlockWriter({required this.dao, required this.synchronize});
  final TodoDao dao;
  final Future<void> Function(String) synchronize;
  Future<TimeBlockSaveResult> save(
    String id,
    TodoTimeBlock block, {
    Set<String> acknowledgedConflicts = const {},
    bool blockAllDay = false,
  }) async {
    final conflicts = await dao.transaction(() async {
      final row = await dao.findById(id);
      if (row == null || row.isDone) {
        throw StateError('Todo is no longer available for planning');
      }
      final current = await findTimeBlockConflicts(
        dao,
        id,
        block,
        blockAllDay: blockAllDay,
      );
      final unconfirmed = current
          .where((c) => !acknowledgedConflicts.contains(c.token))
          .toList();
      if (unconfirmed.isNotEmpty) return unconfirmed;
      await dao.patch(
        id,
        TodoItemsCompanion(
          slotStart: Value(block.start),
          slotEnd: Value(block.end),
          hasTime: const Value(true),
          reminderSyncStatus: const Value(SyncStatus.pendingPush),
        ),
      );
      return <TimeBlockConflict>[];
    });
    if (conflicts.isNotEmpty) {
      return TimeBlockSaveResult(saved: false, conflicts: conflicts);
    }
    try {
      await synchronize(id);
    } catch (_) {
      return const TimeBlockSaveResult(saved: true, deferred: true);
    }
    return const TimeBlockSaveResult(saved: true);
  }
}

class TimeBlockConflict {
  const TimeBlockConflict(this.kind, this.id, this.title, this.start, this.end);
  final String kind, id, title;
  final DateTime start, end;
  String get token =>
      '$kind:$id:${start.toIso8601String()}:${end.toIso8601String()}';
}

Future<List<TimeBlockConflict>> findTimeBlockConflicts(
  TodoDao dao,
  String targetId,
  TodoTimeBlock block, {
  bool blockAllDay = false,
}) async {
  final events = await dao.attachedDatabase.eventDao.between(
    block.start,
    block.end,
  );
  final todos = await dao.between(block.start, block.end);
  return [
    for (final e in events)
      if (!e.isAllDay || blockAllDay)
        TimeBlockConflict('event', e.id, e.title, e.startAt, e.endAt),
    for (final t in todos)
      if (t.id != targetId &&
          !t.isDone &&
          TodoTimeBlock.of(t) != null &&
          block.overlaps(TodoTimeBlock.of(t)!))
        TimeBlockConflict('todo', t.id, t.title, t.slotStart, t.slotEnd!),
  ];
}

/// Suggestions use half-open intervals. Point todos reserve no implicit time.
List<TodoTimeBlock> availableTimeBlocks({
  required TodoTimeBlock work,
  required Duration duration,
  required Iterable<TodoTimeBlock> busy,
  DateTime? notBefore,
}) {
  if (duration <= Duration.zero) {
    throw ArgumentError('Duration must be positive');
  }
  final occupied = busy.toList();
  final result = <TodoTimeBlock>[];
  for (
    var start = work.start;
    !start.add(duration).isAfter(work.end);
    start = start.add(const Duration(minutes: 15))
  ) {
    if (notBefore != null && start.isBefore(notBefore)) continue;
    final candidate = TodoTimeBlock(start, start.add(duration));
    if (occupied.every((other) => !candidate.overlaps(other))) {
      result.add(candidate);
    }
  }
  return result;
}
