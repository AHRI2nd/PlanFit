import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_status.dart';
import '../tables.dart';

part 'event_dao.g.dart';

@DriftAccessor(tables: [Events])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  /// Events that overlap the half-open window [from, to) — i.e. the event's
  /// own [startAt, endAt) range intersects it. Both sides need to be strict
  /// on the boundary they share with the *other* range's open end for that:
  /// `endAt > from`, not `>=`. With `>=`, an event ending exactly at a day
  /// boundary (say 23:00–00:00) satisfied `endAt >= from` for *both* that
  /// day's query (from = that day's midnight) and the next day's (from =
  /// the next day's midnight, which equals this event's endAt) — showing it
  /// twice. `todo_dao.dart`'s equivalent window query already used the
  /// correct exclusive form; this just brings events in line with it.
  Expression<bool> _overlaps(DateTime from, DateTime to) =>
      events.startAt.isSmallerThanValue(to) &
      events.endAt.isBiggerThanValue(from);

  Stream<List<EventRow>> watchBetween(DateTime from, DateTime to) {
    return (select(events)
          ..where((t) => _overlaps(from, to))
          ..orderBy([(t) => OrderingTerm(expression: t.startAt)]))
        .watch();
  }

  Future<List<EventRow>> between(DateTime from, DateTime to) {
    return (select(events)
          ..where((t) => _overlaps(from, to))
          ..orderBy([(t) => OrderingTerm(expression: t.startAt)]))
        .get();
  }

  /// Next [limit] events starting at or after [from].
  Stream<List<EventRow>> watchUpcoming(DateTime from, {int limit = 5}) {
    return (select(events)
          ..where((t) => t.startAt.isBiggerOrEqualValue(from))
          ..orderBy([(t) => OrderingTerm(expression: t.startAt)])
          ..limit(limit))
        .watch();
  }

  Future<EventRow?> findById(String id) =>
      (select(events)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Every event, for a full-database export.
  Future<List<EventRow>> all() => select(events).get();

  /// Case-insensitive substring search over title, memo, and location, most
  /// recent start time first.
  Future<List<EventRow>> search(String query) {
    final pattern = '%$query%';
    return (select(events)
          ..where(
            (t) =>
                t.title.like(pattern) |
                t.memo.like(pattern) |
                t.location.like(pattern),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.startAt, mode: OrderingMode.desc),
          ])
          ..limit(100))
        .get();
  }

  Future<EventRow?> findByOsEventId(String osEventId) => (select(
    events,
  )..where((t) => t.osEventId.equals(osEventId))).getSingleOrNull();

  /// Events created/edited locally that still need pushing to the OS calendar.
  Future<List<EventRow>> needingPush() {
    return (select(
      events,
    )..where((t) => t.syncStatus.equalsValue(SyncStatus.pendingPush))).get();
  }

  Future<void> upsert(EventsCompanion companion) =>
      into(events).insertOnConflictUpdate(companion);

  /// Partial update of an existing row (e.g. writing back OS-calendar linkage
  /// without re-supplying every required column).
  Future<void> patch(String id, EventsCompanion companion) =>
      (update(events)..where((t) => t.id.equals(id))).write(companion);

  Future<void> deleteById(String id) =>
      (delete(events)..where((t) => t.id.equals(id))).go();

  /// Occurrences of a recurring series starting at or after [from] —
  /// "this and every future occurrence" for a delete/edit-forward action.
  Future<List<EventRow>> seriesFrom(String groupId, DateTime from) {
    return (select(events)..where(
          (t) =>
              t.recurrenceGroupId.equals(groupId) &
              t.startAt.isBiggerOrEqualValue(from),
        ))
        .get();
  }

  /// The local mirror row for one event of a subscribed calendar, if it's
  /// already been pulled in — used to decide update vs. insert on each sync
  /// pass. See [Events.importSourceCalendarId]'s doc.
  Future<EventRow?> findByImportSource(
    String calendarId,
    String sourceEventId,
  ) {
    return (select(events)..where(
          (t) =>
              t.importSourceCalendarId.equals(calendarId) &
              t.importSourceEventId.equals(sourceEventId),
        ))
        .getSingleOrNull();
  }

  /// Every local mirror row for [calendarId] overlapping [from, to) — used
  /// to detect which previously-mirrored events have since disappeared from
  /// the source and should be removed locally too.
  Future<List<EventRow>> mirroredFrom(
    String calendarId,
    DateTime from,
    DateTime to,
  ) {
    return (select(events)..where(
          (t) =>
              t.importSourceCalendarId.equals(calendarId) & _overlaps(from, to),
        ))
        .get();
  }
}
