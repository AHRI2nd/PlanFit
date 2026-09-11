import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'sync_log_dao.g.dart';

@DriftAccessor(tables: [SyncLogs])
class SyncLogDao extends DatabaseAccessor<AppDatabase> with _$SyncLogDaoMixin {
  SyncLogDao(super.db);

  /// [watchRecent] never reads past its own `limit`, but nothing else was
  /// keeping this table itself from growing without bound over a long-lived
  /// install — every conflict/pull/push resolution ever logged, forever.
  /// Entries are purely diagnostic ([watchRecent]'s own settings-screen
  /// activity feed), so once there are more than this many, [add] drops the
  /// oldest.
  static const int _maxRetained = 500;

  Stream<List<SyncLogRow>> watchRecent({int limit = 50}) {
    return (select(syncLogs)
          ..orderBy([
            (t) => OrderingTerm(expression: t.at, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<void> add(SyncLogsCompanion companion) async {
    await into(syncLogs).insert(companion);
    await customStatement(
      'DELETE FROM sync_logs WHERE id NOT IN '
      '(SELECT id FROM sync_logs ORDER BY at DESC LIMIT $_maxRetained)',
    );
  }
}
