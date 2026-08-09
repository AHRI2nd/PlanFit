import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'event_template_dao.g.dart';

@DriftAccessor(tables: [EventTemplates])
class EventTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$EventTemplateDaoMixin {
  EventTemplateDao(super.db);

  Stream<List<EventTemplateRow>> watchAll() {
    return (select(eventTemplates)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<void> upsert(EventTemplatesCompanion companion) =>
      into(eventTemplates).insertOnConflictUpdate(companion);

  Future<void> deleteById(String id) =>
      (delete(eventTemplates)..where((t) => t.id.equals(id))).go();
}
