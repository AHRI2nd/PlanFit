// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_dao.dart';

// ignore_for_file: type=lint
mixin _$TodoDaoMixin on DatabaseAccessor<AppDatabase> {
  $EventsTable get events => attachedDatabase.events;
  $TodoItemsTable get todoItems => attachedDatabase.todoItems;
  $TodoSubtasksTable get todoSubtasks => attachedDatabase.todoSubtasks;
  TodoDaoManager get managers => TodoDaoManager(this);
}

class TodoDaoManager {
  final _$TodoDaoMixin _db;
  TodoDaoManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$TodoItemsTableTableManager get todoItems =>
      $$TodoItemsTableTableManager(_db.attachedDatabase, _db.todoItems);
  $$TodoSubtasksTableTableManager get todoSubtasks =>
      $$TodoSubtasksTableTableManager(_db.attachedDatabase, _db.todoSubtasks);
}
