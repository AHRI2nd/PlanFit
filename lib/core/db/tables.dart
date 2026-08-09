import 'package:drift/drift.dart';

import 'sync_status.dart';

/// Scheduled events. These are the objects that mirror into the OS calendar,
/// so they carry the linkage columns (`os*`) and a [SyncStatus].
///
/// All datetimes are stored as instants (epoch); convert to the device zone
/// only at the presentation / notification layer.
@DataClassName('EventRow')
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get memo => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  TextColumn get colorTag => text().nullable()();

  /// Whether a local notification fires for this event.
  BoolColumn get notify => boolean().withDefault(const Constant(true))();

  /// Minutes before [startAt] the primary notification fires. 0 = at start
  /// time.
  IntColumn get reminderMinutesBefore =>
      integer().withDefault(const Constant(0))();

  /// Extra reminder offsets (minutes before [startAt]) on top of
  /// [reminderMinutesBefore], comma-separated (e.g. "60,1440" for "1 hour
  /// before" + "1 day before" in addition to the primary one). Null/empty
  /// when there are none. See `EventAlertX.reminderOffsets`.
  TextColumn get additionalReminderMinutes => text().nullable()();

  /// RFC 5545-style RRULE string (e.g. `FREQ=WEEKLY;UNTIL=...`), informational
  /// — recurrence is materialized as individual rows (see
  /// [recurrenceGroupId]), not expanded from this at query time.
  TextColumn get recurrenceRule => text().nullable()();

  /// Shared id linking every materialized occurrence of one recurring series,
  /// so "delete this and future" can bulk-target them. Null for one-off
  /// events.
  TextColumn get recurrenceGroupId => text().nullable()();

  // --- OS calendar linkage (events PlanFit *pushes* to its own single sync
  // target — see CalendarService.resolveTargetCalendarId) ---
  TextColumn get osCalendarId => text().nullable()();
  TextColumn get osEventId => text().nullable()();
  DateTimeColumn get osLastKnownModified => dateTime().nullable()();
  TextColumn get syncStatus => textEnum<SyncStatus>().withDefault(
    Constant(SyncStatus.pendingPush.name),
  )();

  // --- Mirrored-in linkage (events *pulled* from a calendar the user
  // subscribed to — see CalendarImportService.syncMirroredCalendars).
  // Deliberately separate from the os*/syncStatus columns above: a mirrored
  // row is read-only in the UI and never pushed anywhere, so it must never
  // be mistaken for (or interact with) the single-target push/pull machinery
  // those columns drive. Both null for an event PlanFit owns. ---
  TextColumn get importSourceCalendarId => text().nullable()();
  TextColumn get importSourceEventId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lightweight, time-slotted to-dos. Deliberately separate from [Events]: a
/// to-do is a checkbox in an hour, not something that syncs to the OS calendar.
/// It may stand alone or hang off a parent event via [eventId].
@DataClassName('TodoRow')
class TodoItems extends Table {
  TextColumn get id => text()();
  TextColumn get eventId =>
      text().nullable().references(Events, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text().withDefault(const Constant(''))();
  DateTimeColumn get slotStart => dateTime()();
  DateTimeColumn get slotEnd => dateTime().nullable()();

  /// Whether [slotStart] represents an actual time the user picked, or just
  /// a day this to-do belongs to with no specific hour ("today, sometime").
  /// [slotStart] is never null either way (a to-do always belongs to some
  /// day) — this flag alone decides whether the UI shows/sorts by its
  /// time-of-day or groups it into that day's "no time" bucket instead.
  BoolColumn get hasTime => boolean().withDefault(const Constant(true))();

  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  /// When [isDone] last flipped true — null while not done, and cleared
  /// back to null if un-checked. Distinct from [slotStart] (when it was
  /// *due*): the settings > "완료된 할 일 자동 정리" auto-prune
  /// (`TodoController.pruneCompleted`) measures staleness from completion,
  /// not from the due slot, since a to-do finished late shouldn't vanish
  /// immediately just because its slot was days ago.
  DateTimeColumn get completedAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 0 = none, 1 = low, 2 = medium, 3 = high — see `TodoPriority` for the
  /// enum this maps to in the UI/domain layer.
  IntColumn get priority => integer().withDefault(const Constant(0))();

  /// Comma-separated free-form tags (e.g. "업무,급함") — same
  /// deliberately-simple storage as [Events.additionalReminderMinutes]
  /// rather than a join table, since tags here are just labels with no
  /// identity of their own to look up by.
  TextColumn get tags => text().nullable()();

  /// Whether a local notification fires at [slotStart] — meaningless (and
  /// never actually scheduled, see `TodoController.add`) when [hasTime] is
  /// false, since there's no specific moment to fire at. Unlike
  /// [Events.reminderMinutesBefore], a to-do has no separate "primary" lead
  /// time of its own — the due-time alert (offset 0) is always implicitly
  /// included whenever this is on, with [additionalReminderMinutes] only
  /// ever adding extra earlier ones on top of it.
  BoolColumn get notify => boolean().withDefault(const Constant(false))();

  /// Extra reminder offsets (minutes before [slotStart]) on top of the
  /// implicit "at due time" (offset 0) alert, comma-separated — same storage
  /// shape as [Events.additionalReminderMinutes]. Null/empty when there are
  /// none. See `TodoAlertX.reminderOffsets`.
  TextColumn get additionalReminderMinutes => text().nullable()();

  /// RFC 5545-style RRULE string, informational only — see
  /// [Events.recurrenceRule] for why recurrence is materialized as separate
  /// rows instead of expanded from this at query time.
  TextColumn get recurrenceRule => text().nullable()();

  /// Shared id linking every materialized occurrence of one recurring
  /// series, so "delete this and future" can bulk-target them. Null for a
  /// one-off to-do.
  TextColumn get recurrenceGroupId => text().nullable()();

  /// Pinned to-dos surface first on the smart list's "고정됨" tab and carry
  /// a small badge wherever else they're shown — purely a visibility aid,
  /// never a sort override in the day view's own timeline (that view's
  /// whole point is chronological order; forcing a pinned 3pm item ahead of
  /// a 9am one there would fight that, unlike the no-time bucket's
  /// `sortOrder` drag reorder, which has no chronological meaning to
  /// protect).
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A checklist item under a parent [TodoItems] row — "부하위작업" (e.g. a
/// "Prep talk" to-do split into "Write slides"/"Rehearse"/"Print handouts").
/// Deliberately its own table rather than a comma-separated column like
/// [TodoItems.tags]: each subtask has its own identity (id, done state) that
/// needs to be toggled/deleted individually, unlike a tag.
@DataClassName('TodoSubtaskRow')
class TodoSubtasks extends Table {
  TextColumn get id => text()();
  TextColumn get todoId =>
      text().references(TodoItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withDefault(const Constant(''))();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A saved event preset ("헬스", "주간 회의", ...) a user can reuse instead of
/// re-entering the same title/duration/color/reminder every time. Templates
/// carry a relative [durationMinutes] rather than absolute times — applying
/// one just fills the editor's fields, it never becomes an [Events] row on
/// its own.
@DataClassName('EventTemplateRow')
class EventTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get memo => text().nullable()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(60))();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  TextColumn get colorTag => text().nullable()();
  BoolColumn get notify => boolean().withDefault(const Constant(true))();
  IntColumn get reminderMinutesBefore =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A human-readable trail of what the calendar reconciler did, surfaced on the
/// "Sync activity" screen so last-write-wins is never fully silent.
@DataClassName('SyncLogRow')
class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime().withDefault(currentDateAndTime)();
  TextColumn get eventTitle => text().nullable()();
  TextColumn get resolution => textEnum<SyncResolution>()();
  TextColumn get detail => text().nullable()();
}
