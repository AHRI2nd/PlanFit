import '../../../core/db/app_database.dart';
import 'event_input.dart';

/// The one interface both the UI and the calendar reconciler go through to
/// read and write events. Keeping it abstract is the "keep the door open"
/// investment: a later phase can supply a remote-backed implementation (for
/// sharing / accounts) without touching any screen.
abstract class EventRepository {
  Stream<List<EventRow>> watchBetween(DateTime from, DateTime to);
  Stream<List<EventRow>> watchUpcoming(DateTime from, {int limit});
  Future<EventRow?> findById(String id);

  /// Case-insensitive substring search over title and memo.
  Future<List<EventRow>> search(String query);

  /// Every event, for a full-database backup export.
  Future<List<EventRow>> allEvents();

  /// Creates or updates an event, then keeps its notification and the OS
  /// calendar in step. Returns the stored row.
  ///
  /// If [input] is new (no existing row for its id) and carries a recurrence,
  /// this materializes one row per occurrence, all sharing a fresh
  /// `recurrenceGroupId`, and returns the first occurrence. Editing an
  /// existing row always edits just that occurrence — recurrence on [input]
  /// is ignored in that case.
  Future<EventRow> save(EventInput input);

  /// Applies [input]'s title/memo/color/notify/reminder — plus the delta
  /// between [input]'s start time-of-day and [id]'s occurrence's own — to
  /// [id] and every later occurrence in its recurring series ("this and
  /// future"), the edit-side counterpart to [deleteSeriesFrom]. Each
  /// occurrence keeps its own date; only the shared fields and the
  /// time-of-day/duration shift together. No-ops the series part (behaves
  /// like plain [save]) if [id] isn't part of one.
  Future<void> saveSeriesFrom(String id, EventInput input);

  Future<void> delete(String id);

  /// Deletes [id] and every later occurrence in its recurring series
  /// ("this and future"). No-ops the series part if [id] isn't part of one.
  Future<void> deleteSeriesFrom(String id);

  /// Restores [row] as-is from a backup: writes every field directly
  /// (bypassing the recurrence-materialization in [save], since a backup
  /// already contains one row per occurrence) and re-arms its notification.
  /// OS-calendar linkage is reset to [SyncStatus.pendingPush] — the ids in
  /// the backup may point at a calendar on a different device/reinstall, so
  /// re-syncing from scratch is the only safe option. A thin wrapper around
  /// [restoreEvents] for a single row.
  Future<void> restoreEvent(EventRow row);

  /// Same as [restoreEvent], batched: every row's DB write happens inside
  /// one transaction, so restoring a full backup doesn't hold the database
  /// open across hundreds of individual commits. Use this instead of a loop
  /// of [restoreEvent] calls whenever more than one row is being restored
  /// at once.
  Future<void> restoreEvents(List<EventRow> rows);
}
