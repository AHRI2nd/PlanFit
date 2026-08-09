import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

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
    // every occurrence lands or none do.
    return _dao.transaction(() async {
      EventRow? first;
      for (var i = 0; i < occurrences.length; i++) {
        final (start, end) = occurrences[i];
        final id = i == 0 ? input.id : _uuid.v4();
        final row = await _saveSingle(
          id: id,
          input: input,
          startAt: start,
          endAt: end,
          existing: null,
          recurrenceGroupId: groupId,
          recurrenceRule: rrule,
        );
        first ??= row;
      }
      return first!;
    });
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

    // Only the time-of-day (not the date) and the duration carry across
    // occurrences — each keeps its own date. Computed once against the
    // occurrence being edited, then re-applied to every later one.
    final timeOfDayDelta =
        Duration(hours: input.startAt.hour, minutes: input.startAt.minute) -
        Duration(
          hours: existing.startAt.hour,
          minutes: existing.startAt.minute,
        );
    final duration = input.endAt.difference(input.startAt);

    final occurrences = await _dao.seriesFrom(groupId, existing.startAt);

    // Same all-or-nothing guarantee as the other series-wide operations
    // (save()'s recurring branch, deleteSeriesFrom()) — a mid-loop failure
    // shouldn't leave "this and future" half applied.
    await _dao.transaction(() async {
      for (final occurrence in occurrences) {
        final occurrenceDay = DateTime(
          occurrence.startAt.year,
          occurrence.startAt.month,
          occurrence.startAt.day,
        );
        final newStart = occurrenceDay.add(
          Duration(
                hours: occurrence.startAt.hour,
                minutes: occurrence.startAt.minute,
              ) +
              timeOfDayDelta,
        );
        final newEnd = newStart.add(duration);
        await _saveSingle(
          id: occurrence.id,
          input: input,
          startAt: newStart,
          endAt: newEnd,
          existing: occurrence,
          recurrenceGroupId: occurrence.recurrenceGroupId,
          recurrenceRule: occurrence.recurrenceRule,
        );
      }
    });
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

    var row = (await _dao.findById(id))!;

    // Notification: schedule when opted-in — scheduleForEvent judges each of
    // the event's (possibly several, see EventAlertX.reminderOffsets)
    // reminders on its own, only actually arming the ones that are still in
    // the future and within the near-term scheduling window (see
    // notificationSchedulingWindow's doc; CalendarReconciler's refill picks
    // up anything further out once it rolls inside that window). Otherwise
    // clear every one of them.
    if (input.notify) {
      await _notifications.scheduleForEvent(row);
    } else {
      await _notifications.cancelForEvent(id);
    }

    // Push through to the OS calendar when sync is enabled. Best-effort: the
    // local save above already succeeded, so a calendar-side failure (e.g.
    // permission revoked, a transient plugin error) must not surface as a
    // save failure to the caller — syncStatus stays pendingPush and
    // CalendarReconciler retries it on the next foreground resume.
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
          row = (await _dao.findById(row.id))!;
        }
      } on Exception {
        // See comment above — swallow and let the reconciler retry.
      }
    }

    return row;
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

    // Same all-or-nothing guarantee as the recurring save path (see save()):
    // a mid-loop failure shouldn't leave "delete this and future" half
    // applied. delete() itself is now resilient to calendar-side failures
    // (see its comment), so this is mainly defense against a DB-level
    // problem partway through — but costs nothing to guarantee either way.
    final rows = await _dao.seriesFrom(groupId, row.startAt);
    await _dao.transaction(() async {
      for (final r in rows) {
        await delete(r.id);
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

    // See the equivalent comment in _saveSingle above — scheduleForEvent
    // judges each reminder offset on its own.
    final restored = (await _dao.findById(row.id))!;
    if (restored.notify) {
      await _notifications.scheduleForEvent(restored);
    } else {
      await _notifications.cancelForEvent(row.id);
    }
  }
}
