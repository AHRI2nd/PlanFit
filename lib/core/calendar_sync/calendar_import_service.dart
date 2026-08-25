import 'package:device_calendar_plus/device_calendar_plus.dart'
    show Calendar, Event;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/daos/event_dao.dart';
import '../db/sync_status.dart';
import 'calendar_service.dart';

/// Copies another device calendar's events into PlanFit's own local data —
/// for a user who already keeps events in some other calendar (work, a
/// shared family calendar, a subscribed holiday feed, ...) and wants them
/// visible inside PlanFit too. [CalendarReconciler]/[EventRepository] only
/// ever *publish* PlanFit's own events outward to a single sync-target
/// calendar; nothing pulls a whole foreign calendar in, which is what this
/// fills in — either as a one-time snapshot ([importFrom]) or a
/// continuously-refreshed read-only mirror ([syncMirroredCalendars]).
///
/// Deliberately bypasses `EventRepository.save` and writes rows straight
/// through [EventDao]: mirrored rows are stored as already
/// [SyncStatus.synced] with no `osEventId`/`osCalendarId` — inert from
/// [CalendarReconciler]'s single-target push/pull machinery, so mirroring a
/// calendar the user still keeps around externally doesn't turn around and
/// push copies of it back out (into that same calendar, or worse, into the
/// user's own separate sync target). Mirrored rows are meant to be
/// read-only in the UI for the same reason: an edit that *did* flow through
/// `EventRepository.save` would flip `syncStatus` to `pendingPush` and
/// attempt to push the edit somewhere — there's no calendar it should push
/// to, and the source calendar may not even be writable. Notifications
/// default off so a large import/mirror doesn't flood the user with alerts.
///
/// Re-running an import, or a mirror sync, updates existing rows rather
/// than duplicating them — matched via [Events.importSourceCalendarId] +
/// [Events.importSourceEventId], not by a derived id.
class CalendarImportService {
  CalendarImportService({
    required this.calendarService,
    required this.eventDao,
  });

  final CalendarService calendarService;
  final EventDao eventDao;

  static const _uuid = Uuid();

  /// Every calendar on the device (including read-only feeds) the user can
  /// pick as an import/subscribe source.
  Future<List<Calendar>> availableCalendars() => calendarService.allCalendars();

  /// Copies events on [calendarId] within `[from, to)` into PlanFit once.
  /// Returns how many were imported.
  Future<int> importFrom(
    String calendarId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final events = await calendarService.listEvents(
      calendarId,
      from: from,
      to: to,
    );
    final colorHex = await _colorHexOf(calendarId);
    await eventDao.transaction(() async {
      for (final e in events) {
        await _upsertMirrorRow(calendarId, e, colorHex);
      }
    });
    return events.length;
  }

  /// Continuously-mirrored counterpart to [importFrom], run on every
  /// [CalendarReconciler] pass for each of the user's subscribed calendars:
  /// upserts events currently in `[from, to)`, and removes local mirror rows
  /// for events that were previously pulled in but have since disappeared
  /// from the source (deleted, or moved outside the window).
  Future<void> syncMirroredCalendars(
    Set<String> calendarIds, {
    required DateTime from,
    required DateTime to,
  }) async {
    final colorByCalendar = await _colorHexByCalendar(calendarIds);
    for (final calendarId in calendarIds) {
      final events = await calendarService.listEvents(
        calendarId,
        from: from,
        to: to,
      );
      final currentSourceIds = events.map((e) => e.instanceId).toSet();

      await eventDao.transaction(() async {
        for (final e in events) {
          await _upsertMirrorRow(calendarId, e, colorByCalendar[calendarId]);
        }
        final existingMirrors = await eventDao.mirroredFrom(
          calendarId,
          from,
          to,
        );
        for (final row in existingMirrors) {
          if (!currentSourceIds.contains(row.importSourceEventId)) {
            await eventDao.deleteById(row.id);
          }
        }
      });
    }
  }

  /// Deletes every local mirror row for [calendarId] — used when the user
  /// unsubscribes, so stale copies don't linger after they stop wanting them
  /// kept in sync.
  Future<void> removeMirroredCalendar(String calendarId) async {
    // A far-reaching window: mirrored rows can exist anywhere a prior sync
    // pass's [from, to) covered.
    final rows = await eventDao.mirroredFrom(
      calendarId,
      DateTime(2000),
      DateTime(2100),
    );
    await eventDao.transaction(() async {
      for (final row in rows) {
        await eventDao.deleteById(row.id);
      }
    });
  }

  /// [calendarId]'s own OS color, if it has one — looked up once per
  /// [importFrom] call rather than per event.
  Future<String?> _colorHexOf(String calendarId) async {
    final calendars = await calendarService.allCalendars();
    for (final c in calendars) {
      if (c.id == calendarId) return c.colorHex;
    }
    return null;
  }

  /// Batched counterpart to [_colorHexOf] for [syncMirroredCalendars],
  /// which mirrors several calendars per pass — one [availableCalendars]
  /// call covers all of them instead of one per calendar.
  Future<Map<String, String?>> _colorHexByCalendar(
    Set<String> calendarIds,
  ) async {
    final calendars = await calendarService.allCalendars();
    final colors = <String, String?>{for (final id in calendarIds) id: null};
    for (final c in calendars) {
      if (colors.containsKey(c.id)) colors[c.id] = c.colorHex;
    }
    return colors;
  }

  /// [colorHex] is [calendarId]'s own OS color (`#RRGGBB`, straight from
  /// [_colorHexOf]/[_colorHexByCalendar]) — stored as-is in
  /// [Events.colorTag], which already accepts a hex string alongside its
  /// preset tag names (see [EventColorTag]'s doc). Without this, a mirrored
  /// row's `colorTag` was always left null, so every imported event fell
  /// back to [EventColorTag.resolve]'s generic time-of-day gradient instead
  /// of reading as belonging to the calendar it actually came from.
  Future<void> _upsertMirrorRow(
    String calendarId,
    Event e,
    String? colorHex,
  ) async {
    final existing = await eventDao.findByImportSource(
      calendarId,
      e.instanceId,
    );
    final now = DateTime.now();
    await eventDao.upsert(
      EventsCompanion(
        id: Value(existing?.id ?? _uuid.v4()),
        title: Value(e.title),
        memo: Value(e.description),
        location: Value(e.location),
        startAt: Value(e.startDate),
        endAt: Value(e.endDate),
        isAllDay: Value(e.isAllDay),
        notify: const Value(false),
        colorTag: Value(colorHex),
        syncStatus: const Value(SyncStatus.synced),
        importSourceCalendarId: Value(calendarId),
        importSourceEventId: Value(e.instanceId),
        createdAt: existing == null ? Value(now) : Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );
  }
}
