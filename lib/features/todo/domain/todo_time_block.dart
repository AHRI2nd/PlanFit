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
  bool overlaps(TodoTimeBlock other) => start.isBefore(other.end) && end.isAfter(other.start);
  static TodoTimeBlock? of(TodoRow row) => row.hasTime && row.slotEnd != null && row.slotEnd!.isAfter(row.slotStart)
    ? TodoTimeBlock(row.slotStart, row.slotEnd!) : null;
}
class TimeBlockSaveResult {
  const TimeBlockSaveResult({required this.saved, this.deferred = false});
  final bool saved;
  final bool deferred;
}
class TodoTimeBlockWriter {
  TodoTimeBlockWriter({required this.dao, required this.synchronize});
  final TodoDao dao;
  final Future<void> Function(String) synchronize;
  Future<TimeBlockSaveResult> save(String id, TodoTimeBlock block) async {
    await dao.transaction(() async {
      final row = await dao.findById(id);
      if (row == null || row.isDone) throw StateError('Todo is no longer available for planning');
      await dao.patch(id, TodoItemsCompanion(slotStart: Value(block.start), slotEnd: Value(block.end),
        hasTime: const Value(true), reminderSyncStatus: const Value(SyncStatus.pendingPush)));
    });
    try { await synchronize(id); } catch (_) { return const TimeBlockSaveResult(saved: true, deferred: true); }
    return const TimeBlockSaveResult(saved: true);
  }
}
