import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'sync_log_dao.g.dart';

@DriftAccessor(tables: [SyncLogs])
class SyncLogDao extends DatabaseAccessor<AppDatabase> with _$SyncLogDaoMixin {
  SyncLogDao(super.db);

  Stream<List<SyncLogRow>> watchRecent({int limit = 50}) {
    return (select(syncLogs)
          ..orderBy([
            (t) => OrderingTerm(expression: t.at, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<void> add(SyncLogsCompanion companion) =>
      into(syncLogs).insert(companion);
}
