import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/date_math.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/daos/event_dao.dart';
import '../../../core/db/sync_status.dart';
import '../domain/event_input.dart';
import '../domain/event_repository.dart';
import '../domain/ports.dart';
import '../domain/recurrence.dart';

/// drift-backed [EventRepository] that also fans a write out to the local
/// notification scheduler and the device calendar, so those can never drift out
/// of sync with the stored event.
class EventRepositoryImpl implements EventRepository {
  EventRepositoryImpl({
    required this._dao,
    required this._notifications,
    required this._calendar,
  });

  final EventDao _dao;
  final NotificationPort _notifications;
  final CalendarPort _calendar;

  static const _uuid = Uuid();

  @override
  Stream<List<EventRow>> watchBetween(DateTime from, DateTime to) =>
      _dao.watchBetween(from, to);

  @override
  Stream<List<EventRow>> watchUpcoming(DateTime from, {int limit = 5}) =>
      _dao.watchUpcoming(from, limit: limit);

  @override
  Future<EventRow?> findById(String id) => _dao.findById(id);

  @override
  Future<List<EventRow>> search(String query) => _dao.search(query);

  @override
  Future<List<EventRow>> allEvents() => _dao.all();

  @override
  Future<EventRow> save(EventInput input) async {
    final existing = await _dao.findById(input.id);

    final isNewRecurring =
        existing == null &&
        input.recurrenceFrequency != RecurrenceFrequency.none &&
        (input.recurrenceUntil != null || input.recurrenceCount != null);

    if (!isNewRecurring) {
      // A brand-new one-off event, or an edit of an existing occurrence —
      // preserve whatever series membership/RRULE that occurrence already
      // had rather than letting an edit (which never carries recurrence
      // fields from the UI) wipe it.
      return _saveSingle(
        id: input.id,
        input: input,
        startAt: input.startAt,
        endAt: input.endAt,
        existing: existing,
        recurrenceGroupId: existing?.recurrenceGroupId,
        recurrenceRule: existing?.recurrenceRule,
      );
    }

    final groupId = _uuid.v4();
    final rrule = RecurrenceExpansion.toRruleString(
      input.recurrenceFrequency,
      until: input.recurrenceUntil,
      count: input.recurrenceCount,
      byWeekdays: input.recurrenceByWeekdays,
    );
    final occurrences = RecurrenceExpansion.occurrences(
      start: input.startAt,
      end: input.endAt,
      frequency: input.recurrenceFrequency,
      until: input.recurrenceUntil,
      count: input.recurrenceCount,
      byWeekdays: input.recurrenceByWeekdays,
    );

    // A failure partway through (e.g. occurrence 50 of 200 hits a constraint
    // error) must not leave the series half-materialized in the DB — either
    // every occurrence lands or none do. Only the DB writes happen inside
    // the transaction, though: notification scheduling and the calendar
    // push are platform-channel round trips, and holding the single sqlite
    // writer connection open across up to 200 of those would block every
    // other write in the app for the duration, and risks an unrelated late
    // IO hiccup rolling back an otherwise-successful batch. Those side
    // effects run afterward instead, per row, outside the transaction.
    final rowsToSync = <EventRow>[];
    final first = await _dao.transaction(() async {
      EventRow? firstRow;
      for (var i = 0; i < occurrences.length; i++) {
        final (start, end) = occurrences[i];
        final id = i == 0 ? input.id : _uuid.v4();
        final row = await _upsertRow(
          id: id,
          input: input,
          startAt: start,
          endAt: end,
          existing: null,
          recurrenceGroupId: groupId,
          recurrenceRule: rrule,
        );
        rowsToSync.add(row);
        firstRow ??= row;
      }
      return firstRow!;
    });

    for (final row in rowsToSync) {
      await _applySideEffects(row, notify: input.notify);
    }
    return (await _dao.findById(first.id)) ?? first;
  }

  @override
  Future<void> saveSeriesFrom(String id, EventInput input) async {
    final existing = await _dao.findById(id);
    if (existing == null) {
      await save(input);
      return;
    }
    final groupId = existing.recurrenceGroupId;
    if (groupId == null) {
      // Not part of a series — same single-occurrence behavior as save().
      await save(input);
      return;
    }

    // Time-of-day (not the date) and the duration carry across *future*
    // occurrences — each of those keeps its own date. The occurrence being
    // edited is the one exception: it's written exactly as input says,
    // date included, since that's what the user is looking at when they
    // choose "this and future" — silently reverting a date change they can
    // see on screen would contradict the edit they just made.
    final timeOfDayDelta =
        Duration(hours: input.startAt.hour, minutes: input.startAt.minute) -
        Duration(
          hours: existing.startAt.hour,
          minutes: existing.startAt.minute,
        );
    final duration = input.endAt.difference(input.startAt);

    final occurrences = await _dao.seriesFrom(groupId, existing.startAt);

    // Same all-or-nothing guarantee (for the DB writes) and same
    // side-effects-outside-the-transaction reasoning as save()'s recurring
    // branch above.
    final rowsToSync = <EventRow>[];
    await _dao.transaction(() async {
      for (final occurrence in occurrences) {
        final DateTime newStart;
        final DateTime newEnd;
        if (occurrence.id == id) {
          newStart = input.startAt;
          newEnd = input.endAt;
        } else {
          newStart = shiftTimeOfDay(occurrence.startAt, timeOfDayDelta);
          newEnd = newStart.add(duration);
        }
        final row = await _upsertRow(
          id: occurrence.id,
          input: input,
          startAt: newStart,
          endAt: newEnd,
          existing: occurrence,
          recurrenceGroupId: occurrence.recurrenceGroupId,
          recurrenceRule: occurrence.recurrenceRule,
        );
        rowsToSync.add(row);
      }
    });

    for (final row in rowsToSync) {
      await _applySideEffects(row, notify: input.notify);
    }
  }

  /// Writes one occurrence's row only — no notification/calendar side
  /// effects. Batch callers ([save]'s recurring branch, [saveSeriesFrom])
  /// use this inside their transaction and run [_applySideEffects]
  /// afterward, per row; single-occurrence callers go through [_saveSingle]
  /// instead, which does both in sequence.
  Future<EventRow> _upsertRow({
    required String id,
    required EventInput input,
    required DateTime startAt,
    required DateTime endAt,
    required EventRow? existing,
    String? recurrenceGroupId,
    String? recurrenceRule,
  }) async {
    final now = DateTime.now();

    await _dao.upsert(
      EventsCompanion(
        id: Value(id),
        title: Value(input.title),
        memo: Value(input.memo),
        location: Value(input.location),
        startAt: Value(startAt),
        endAt: Value(endAt),
        isAllDay: Value(input.isAllDay),
        notify: Value(input.notify),
        reminderMinutesBefore: Value(input.reminderMinutesBefore),
        additionalReminderMinutes: Value(
          input.additionalReminderMinutes.isEmpty
              ? null
              : input.additionalReminderMinutes.join(','),
        ),
        colorTag: Value(input.colorTag),
        recurrenceRule: Value(recurrenceRule),
        recurrenceGroupId: Value(recurrenceGroupId),
        // Preserve OS linkage across edits.
        osCalendarId: Value(existing?.osCalendarId),
        osEventId: Value(existing?.osEventId),
        syncStatus: const Value(SyncStatus.pendingPush),
        createdAt: existing == null ? Value(now) : Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );

    return (await _dao.findById(id))!;
  }

  /// Notification scheduling and the OS-calendar push for one already-
  /// written row. Both are best-effort: the local save already succeeded,
  /// so a failure here (permission revoked between check and call, a
  /// transient plugin error, ...) must not surface as a save failure to the
  /// caller — CalendarReconciler retries the calendar push on the next
  /// foreground resume, and the notification refill picks up anything that
  /// didn't get scheduled.
  Future<void> _applySideEffects(EventRow row, {required bool notify}) async {
    try {
      if (notify) {
        await _notifications.scheduleForEvent(row);
      } else {
        await _notifications.cancelForEvent(row.id);
      }
    } on Exception {
      // See doc comment above.
    }

    if (_calendar.isEnabled) {
      try {
        final osEventId = await _calendar.pushEvent(row);
        if (osEventId != null) {
          await _dao.patch(
            row.id,
            EventsCompanion(
              osEventId: Value(osEventId),
              osLastKnownModified: Value(DateTime.now()),
              syncStatus: const Value(SyncStatus.synced),
            ),
          );
        }
      } on Exception {
        // See doc comment above.
      }
    }
  }

  /// Writes one occurrence and keeps its notification and OS-calendar
  /// linkage in step. Each occurrence of a recurring series is pushed to the
  /// calendar as its own plain (non-recurring) event — recurring-event
  /// support is the flakiest part of the calendar-plugin ecosystem, so we
  /// sidestep it entirely by materializing rows instead of an RRULE.
  Future<EventRow> _saveSingle({
    required String id,
    required EventInput input,
    required DateTime startAt,
    required DateTime endAt,
    required EventRow? existing,
    String? recurrenceGroupId,
    String? recurrenceRule,
  }) async {
    final row = await _upsertRow(
      id: id,
      input: input,
      startAt: startAt,
      endAt: endAt,
      existing: existing,
      recurrenceGroupId: recurrenceGroupId,
      recurrenceRule: recurrenceRule,
    );
    await _applySideEffects(row, notify: input.notify);
    return (await _dao.findById(id)) ?? row;
  }

  @override
  Future<void> delete(String id) async {
    final row = await _dao.findById(id);
    if (row == null) return;

    await _notifications.cancelForEvent(id);
    if (_calendar.isEnabled && row.osEventId != null) {
      // Best-effort, same reasoning as the push above: the user's delete
      // must go through locally even if the OS-calendar side fails for some
      // reason CalendarService itself doesn't already treat as a no-op.
      try {
        await _calendar.deleteEvent(row);
      } on Exception {
        // Nothing to reconcile after this — the row is gone either way.
      }
    }
    await _dao.deleteById(id);
  }

  @override
  Future<void> deleteSeriesFrom(String id) async {
    final row = await _dao.findById(id);
    if (row == null) return;

    final groupId = row.recurrenceGroupId;
    if (groupId == null) {
      await delete(id);
      return;
    }

    final rows = await _dao.seriesFrom(groupId, row.startAt);

    // Side effects (best-effort, same reasoning as delete()) run first,
    // outside the transaction — a platform-channel round trip per row must
    // not hold the single sqlite writer connection open for the whole loop.
    for (final r in rows) {
      await _notifications.cancelForEvent(r.id);
      if (_calendar.isEnabled && r.osEventId != null) {
        try {
          await _calendar.deleteEvent(r);
        } on Exception {
          // Nothing to reconcile after this — the row is gone either way.
        }
      }
    }

    // Same all-or-nothing guarantee as the recurring save path (see save()):
    // a mid-loop DB failure shouldn't leave "delete this and future" half
    // applied.
    await _dao.transaction(() async {
      for (final r in rows) {
        await _dao.deleteById(r.id);
      }
    });
  }

  @override
  Future<void> restoreEvent(EventRow row) async {
    final now = DateTime.now();
    await _dao.upsert(
      EventsCompanion(
        id: Value(row.id),
        title: Value(row.title),
        memo: Value(row.memo),
        location: Value(row.location),
        startAt: Value(row.startAt),
        endAt: Value(row.endAt),
        isAllDay: Value(row.isAllDay),
        colorTag: Value(row.colorTag),
        notify: Value(row.notify),
        reminderMinutesBefore: Value(row.reminderMinutesBefore),
        additionalReminderMinutes: Value(row.additionalReminderMinutes),
        recurrenceRule: Value(row.recurrenceRule),
        recurrenceGroupId: Value(row.recurrenceGroupId),
        // Not carried over — see the doc comment on restoreEvent.
        osCalendarId: const Value(null),
        osEventId: const Value(null),
        osLastKnownModified: const Value(null),
        syncStatus: const Value(SyncStatus.pendingPush),
        createdAt: Value(row.createdAt),
        updatedAt: Value(now),
      ),
    );

    final restored = (await _dao.findById(row.id))!;
    await _applySideEffects(restored, notify: restored.notify);
  }
}
