// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_log_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncLogDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncLogsTable get syncLogs => attachedDatabase.syncLogs;
  SyncLogDaoManager get managers => SyncLogDaoManager(this);
}

class SyncLogDaoManager {
  final _$SyncLogDaoMixin _db;
  SyncLogDaoManager(this._db);
  $$SyncLogsTableTableManager get syncLogs =>
      $$SyncLogsTableTableManager(_db.attachedDatabase, _db.syncLogs);
}
