import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../features/schedule/domain/ports.dart';
import '../db/app_database.dart';
import '../db/daos/event_dao.dart';
import '../db/daos/sync_log_dao.dart';
import '../db/sync_status.dart';
import '../notifications/notification_window.dart';
import 'calendar_import_service.dart';
import 'calendar_service.dart';

/// Reconciles PlanFit's events with the device calendar on app foreground.
///
/// The plugin's [dc.Event] carries no last-modified timestamp, so this can't do
/// timestamp-based three-way merge. Instead it leans on an invariant the write
/// path guarantees: right after a push, the local row equals the OS event and
/// is marked [SyncStatus.synced]. So at reconciliation time:
///   * a synced row whose OS event is **gone** → deleted in the calendar app.
///   * a synced row whose OS values **differ** → edited in the calendar app;
///     pull those values back (last-write-wins toward the calendar app), and
///     flag it a conflict in the log when the row was also edited locally
///     since the last sync.
/// It also (re)pushes anything still [SyncStatus.pendingPush], e.g. events
/// created while sync was off.
///
/// Every branch is idempotent, so running it repeatedly is safe.
class CalendarReconciler {
  CalendarReconciler({
    required this._service,
    required this._eventDao,
    required this._syncLogDao,
    required this._notifications,
    required this._calendarImportService,
  });

  final CalendarService _service;
  final EventDao _eventDao;
  final SyncLogDao _syncLogDao;
  final NotificationPort _notifications;
  final CalendarImportService _calendarImportService;

  static const _uuid = Uuid();

  /// Reconcile events within a rolling window around now. Returns the number of
  /// changes applied (useful for tests and a subtle "synced" affordance).
  Future<int> reconcile({
    DateTime? now,
    Duration lookBack = const Duration(days: 7),
    Duration lookAhead = const Duration(days: 90),
  }) async {
    final at = now ?? DateTime.now();
    final from = at.subtract(lookBack);
    final to = at.add(lookAhead);

    // Notification refill and subscribed-calendar mirroring must both run
    // regardless of calendar *push* sync being on — they're independent
    // directions/concerns (see notificationSchedulingWindow's doc and
    // CalendarImportService's doc respectively).
    await _refillNotifications(at);
    if (_service.subscribedCalendarIds.isNotEmpty) {
      await _calendarImportService.syncMirroredCalendars(
        _service.subscribedCalendarIds,
        from: from,
        to: to,
      );
    }

    if (!_service.isEnabled) return 0;

    var changes = 0;

    // 1) Push anything still waiting (created while sync was off, or a failed
    //    earlier push). Deliberately unbounded by [from, to] — every pending
    //    row eventually needs to land in the calendar app, however far out
    //    it is. Step 2 below, by contrast, only *pulls* edits from within
    //    the rolling window: an edit made in the calendar app to an event
    //    more than [lookAhead] out won't be seen until that event's date
    //    rolls inside the window on some later reconcile. Accepted scope
    //    limit, not a bug — keeps the diff bounded on every run.
    for (final row in await _eventDao.needingPush()) {
      final osId = await _service.pushEvent(row);
      if (osId != null) {
        await _eventDao.patch(
          row.id,
          EventsCompanion(
            osEventId: Value(osId),
            osLastKnownModified: Value(at),
            syncStatus: const Value(SyncStatus.synced),
          ),
        );
        changes++;
      }
    }

    // 2) Pull edits/deletes made in the calendar app for events we own.
    final linked = await _eventDao.between(from, to);
    for (final row in linked) {
      final osId = row.osEventId;
      if (osId == null || row.syncStatus != SyncStatus.synced) continue;

      final osEvent = await _service.fetchEvent(osId);

      if (osEvent == null) {
        // The event no longer exists anywhere — cancel its notification
        // before dropping the row, same as EventRepository.delete() does.
        // This reconciler bypasses the repository (it isn't a user-driven
        // delete), so that cancellation doesn't happen automatically.
        await _notifications.cancelForEvent(row.id);
        await _eventDao.deleteById(row.id);
        await _log(row.title, SyncResolution.deletedRemotely,
            'Removed in the calendar app');
        changes++;
        continue;
      }

      if (!_matches(row, osEvent)) {
        final locallyEdited =
            row.updatedAt.isAfter(row.osLastKnownModified ?? row.createdAt);
        await _eventDao.patch(
          row.id,
          _pullCompanion(osEvent, at),
        );
        // The pulled values may have moved the alert time(s) (or the
        // notify/all-day flags feeding them) — re-sync the local
        // notifications so they don't keep firing at a stale time.
        // scheduleForEvent judges each reminder offset on its own.
        final updated = await _eventDao.findById(row.id);
        if (updated != null) {
          if (updated.notify) {
            await _notifications.scheduleForEvent(updated);
          } else {
            await _notifications.cancelForEvent(updated.id);
          }
        }
        await _log(
          osEvent.title,
          locallyEdited
              ? SyncResolution.conflictRemoteWon
              : SyncResolution.pulled,
          locallyEdited
              ? 'Both sides changed — kept the calendar app version'
              : 'Updated from the calendar app',
        );
        changes++;
      }
    }

    // 3) Auto-import (opt-in, off by default — see
    //    AppSettings.autoImportCalendarEnabled's doc): events created
    //    *directly* in the calendar app, rather than through PlanFit, have
    //    no local row at all — step 2 above only walks rows we already know
    //    about, so it can never notice these. Scan the relevant calendars
    //    (see _autoImportCalendarIds's doc on why it's not just the target
    //    calendar) and materialize anything not already linked.
    if (_service.autoImportEnabled) {
      final calendarColors = await _autoImportCalendarColors();
      final linkedOsIds =
          linked.map((r) => r.osEventId).whereType<String>().toSet();
      for (final entry in calendarColors.entries) {
        final osEvents =
            await _service.listEvents(entry.key, from: from, to: to);
        for (final osEvent in osEvents) {
          if (linkedOsIds.contains(osEvent.eventId)) continue;
          await _importNewEvent(osEvent, at, entry.value);
          changes++;
        }
      }
    }

    return changes;
  }

  /// Calendars step 3 scans, mapped to each one's own OS color (`#RRGGBB`,
  /// or null if the OS didn't provide one) — the sync target itself (an
  /// event added straight into "PlanFit" in the calendar app) plus the
  /// device's primary/default calendar(s), the OS's actual destination for
  /// an event created via the calendar app's own "+" button or Siri, not
  /// the PlanFit-dedicated calendar most users never explicitly pick.
  /// Scanning only the target calendar (the original, narrower version of
  /// this feature) meant it silently never noticed anything a user added
  /// the ordinary way.
  ///
  /// The color travels with the id so [_importNewEvent] can tag the
  /// materialized row with the calendar it actually came from — see
  /// [CalendarImportService]'s matching fix for why leaving `colorTag`
  /// unset made every imported event fall back to
  /// [EventColorTag.resolve]'s generic time-of-day gradient instead.
  ///
  /// Excludes calendars already covered by a read-only subscription
  /// ([CalendarService.subscribedCalendarIds]) so the same OS event doesn't
  /// materialize twice — once as a mirror row via [CalendarImportService],
  /// once as a real PlanFit-owned row here.
  Future<Map<String, String?>> _autoImportCalendarColors() async {
    final ids = <String>{};
    final target = _service.targetCalendarId;
    if (target != null) ids.add(target);
    final writable = await _service.writableCalendars();
    for (final c in writable) {
      if (c.isPrimary) ids.add(c.id);
    }
    ids.removeWhere(_service.subscribedCalendarIds.contains);

    final colors = <String, String?>{};
    for (final id in ids) {
      colors[id] = null;
    }
    for (final c in writable) {
      if (colors.containsKey(c.id)) colors[c.id] = c.colorHex;
    }
    return colors;
  }

  /// Materializes a PlanFit event for [osEvent], an event found in the
  /// target calendar with no corresponding local row — see step 3 above.
  /// [colorHex] is that calendar's own OS color (from
  /// [_autoImportCalendarColors]), stored as-is since [Events.colorTag]
  /// already accepts a `#RRGGBB` hex string alongside its preset tag names
  /// (see [EventColorTag]'s doc). Notifications default off, same reasoning
  /// as `CalendarImportService._upsertMirrorRow`: the user didn't create
  /// this through PlanFit, so it shouldn't silently start alerting them
  /// without an explicit opt-in.
  Future<void> _importNewEvent(
    dc.Event osEvent,
    DateTime at,
    String? colorHex,
  ) async {
    final id = _uuid.v4();
    await _eventDao.upsert(
      EventsCompanion(
        id: Value(id),
        title: Value(osEvent.title),
        memo: Value(osEvent.description),
        location: Value(osEvent.location),
        startAt: Value(osEvent.startDate),
        endAt: Value(osEvent.endDate),
        isAllDay: Value(osEvent.isAllDay),
        notify: const Value(false),
        colorTag: Value(colorHex),
        osCalendarId: Value(osEvent.calendarId),
        osEventId: Value(osEvent.eventId),
        osLastKnownModified: Value(at),
        syncStatus: const Value(SyncStatus.synced),
        createdAt: Value(at),
        updatedAt: Value(at),
      ),
    );
    await _log(
      osEvent.title,
      SyncResolution.pulled,
      'Added directly in the calendar app',
    );
  }

  /// Whether the stored row already agrees with the OS event on the fields we
  /// sync. Times are compared to the minute to tolerate sub-minute rounding in
  /// the platform layer.
  bool _matches(EventRow row, dc.Event os) {
    return row.title == os.title &&
        _sameMinute(row.startAt, os.startDate) &&
        _sameMinute(row.endAt, os.endDate) &&
        row.isAllDay == os.isAllDay &&
        (row.memo ?? '') == (os.description ?? '') &&
        (row.location ?? '') == (os.location ?? '');
  }

  EventsCompanion _pullCompanion(dc.Event os, DateTime at) {
    return EventsCompanion(
      title: Value(os.title),
      memo: Value(os.description),
      location: Value(os.location),
      startAt: Value(os.startDate),
      endAt: Value(os.endDate),
      isAllDay: Value(os.isAllDay),
      osLastKnownModified: Value(at),
      updatedAt: Value(at),
      syncStatus: const Value(SyncStatus.synced),
    );
  }

  bool _sameMinute(DateTime a, DateTime b) =>
      a.difference(b).inMinutes.abs() < 1;

  /// Longest reminder lead time the editor offers ("a day before") — widens
  /// the DB query below so an event whose *start* sits just past the
  /// scheduling window, but whose earliest reminder (start minus lead time)
  /// actually falls inside it, still gets picked up.
  static const _maxLeadTime = Duration(days: 1);

  /// (Re)schedules notifications for events whose start falls within (or
  /// just past) [notificationSchedulingWindow] — scheduleForEvent judges
  /// each of an event's reminder offsets on its own (see its doc), so this
  /// just needs to give it a chance to run again for anything nearby;
  /// offsets already correctly scheduled are a harmless no-op, and any that
  /// have since rolled inside the window get armed. Safe to run on every
  /// foreground resume.
  Future<void> _refillNotifications(DateTime at) async {
    final windowEnd = at.add(notificationSchedulingWindow);
    final candidates =
        await _eventDao.between(at, windowEnd.add(_maxLeadTime));
    for (final row in candidates) {
      if (!row.notify) continue;
      await _notifications.scheduleForEvent(row);
    }
  }

  Future<void> _log(
      String? title, SyncResolution resolution, String detail) {
    return _syncLogDao.add(SyncLogsCompanion(
      eventTitle: Value(title),
      resolution: Value(resolution),
      detail: Value(detail),
    ));
  }
}
