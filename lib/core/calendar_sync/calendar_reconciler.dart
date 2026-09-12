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

  /// Guards against two overlapping [reconcile] runs — `app.dart` calls this
  /// on every `AppLifecycleState.resumed`, and that can fire twice in quick
  /// succession (an incoming call, a fast app-switch gesture) before the
  /// first run's platform-channel calls finish. Without this, two runs can
  /// both see the same [EventDao.needingPush] row before either has written
  /// its new `osEventId` back, and both push it — creating a duplicate event
  /// in the OS calendar — or both see the same not-yet-imported OS event and
  /// materialize it twice.
  bool _reconciling = false;

  /// Reconcile events within a rolling window around now. Returns the number of
  /// changes applied (useful for tests and a subtle "synced" affordance).
  /// A no-op (returns 0) while a previous call is still running — see
  /// [_reconciling].
  Future<int> reconcile({
    DateTime? now,
    Duration lookBack = const Duration(days: 7),
    Duration lookAhead = const Duration(days: 90),
  }) async {
    if (_reconciling) return 0;
    _reconciling = true;
    try {
      return await _reconcile(
        now: now,
        lookBack: lookBack,
        lookAhead: lookAhead,
      );
    } finally {
      _reconciling = false;
    }
  }

  Future<int> _reconcile({
    DateTime? now,
    required Duration lookBack,
    required Duration lookAhead,
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
      // One event's push failing (a transient platform-channel error, a
      // calendar removed mid-sync) used to `rethrow` straight out of this
      // whole method — aborting every other row still waiting in this same
      // loop, plus steps 1.5-3 below, until whatever caused it happened to
      // clear up on its own. Logged and skipped instead, same as every
      // other best-effort platform-channel call in this file already is.
      try {
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
      } on Exception catch (e) {
        await _log(row.title, SyncResolution.failed, 'Push failed: $e');
      }
    }

    // 1.5) Retry OS-calendar deletions that couldn't be confirmed when the
    //    user originally deleted the event locally (see
    //    PendingCalendarDeletions' doc) — most such failures are transient
    //    (a brief plugin/IO error), so a later reconcile pass usually
    //    finishes what the original delete couldn't. Whatever's still
    //    pending after this is filtered out of step 3's auto-import below,
    //    so a genuinely stuck one is never resurrected either.
    final pendingDeletions = await _eventDao.pendingCalendarDeletionIds();
    for (final osId in pendingDeletions.toList()) {
      try {
        await _service.deleteEventById(osId);
        await _eventDao.clearPendingCalendarDeletion(osId);
        pendingDeletions.remove(osId);
      } on Exception {
        // Still stuck — leave the tombstone in place and try again next
        // reconcile.
      }
    }

    // 2) Pull edits/deletes made in the calendar app for events we own.
    final linked = await _eventDao.between(from, to);
    final needsPull = linked.any(
      (row) => row.osEventId != null && row.syncStatus == SyncStatus.synced,
    );
    // One batched fetch of every OS event PlanFit has ever pushed, instead
    // of a fetchEvent() platform-channel round trip per synced row below —
    // each is a real IPC call, so this used to make one per event in
    // [from, to] on *every single app resume* (see this method's own
    // history for the N+1 this replaces). Null (as opposed to an empty
    // map) specifically means "couldn't even ask" — no target calendar
    // resolved — so the loop below leaves every synced row untouched this
    // pass rather than reading that as "everything in it was deleted".
    final osEventsById = needsPull ? await _fetchLinkedOsEventsById() : null;

    for (final row in linked) {
      final osId = row.osEventId;
      if (osId == null || row.syncStatus != SyncStatus.synced) continue;
      if (osEventsById == null) continue;

      final osEvent = osEventsById[osId];

      // Same reasoning as step 1's own try/catch: one row's pull failing
      // must not stop every other row in this loop (or step 3 below) from
      // being reconciled.
      try {
        if (osEvent == null) {
          // The event no longer exists anywhere — cancel its notification
          // before dropping the row, same as EventRepository.delete() does.
          // This reconciler bypasses the repository (it isn't a user-driven
          // delete), so that cancellation doesn't happen automatically.
          await _notifications.cancelForEvent(row.id);
          await _eventDao.deleteById(row.id);
          await _log(
            row.title,
            SyncResolution.deletedRemotely,
            'Removed in the calendar app',
          );
          changes++;
          continue;
        }

        if (!_matches(row, osEvent)) {
          final locallyEdited = row.updatedAt.isAfter(
            row.osLastKnownModified ?? row.createdAt,
          );
          await _eventDao.patch(row.id, _pullCompanion(osEvent, at));
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
      } on Exception catch (e) {
        await _log(row.title, SyncResolution.failed, 'Pull failed: $e');
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
      final linkedOsIds = linked
          .map((r) => r.osEventId)
          .whereType<String>()
          .toSet();
      for (final entry in calendarColors.entries) {
        // One calendar failing to scan (or one of its events failing to
        // import) must not skip every other calendar/event this step would
        // otherwise still get to.
        List<dc.Event> osEvents;
        try {
          osEvents = await _service.listEvents(entry.key, from: from, to: to);
        } on Exception catch (e) {
          await _log(
            null,
            SyncResolution.failed,
            'Auto-import scan failed for a calendar: $e',
          );
          continue;
        }
        for (final osEvent in osEvents) {
          if (linkedOsIds.contains(osEvent.eventId)) continue;
          if (pendingDeletions.contains(osEvent.eventId)) continue;
          try {
            await _importNewEvent(osEvent, at, entry.value);
            changes++;
          } on Exception catch (e) {
            await _log(
              osEvent.title,
              SyncResolution.failed,
              'Auto-import failed: $e',
            );
          }
        }
      }
    }

    return changes;
  }

  /// Every OS event currently in the sync target calendar, by id — step 2's
  /// own batched replacement for calling `fetchEvent` once per synced row.
  ///
  /// Deliberately `[DateTime(2000), DateTime(2100)]`, not `[from, to]`: an
  /// event step 2 already knows as synced may since have been *moved* (in
  /// the calendar app) to a date outside this reconcile's own window —
  /// scoping this fetch to `[from, to]` would make that event vanish from
  /// this map and read as "deleted" to step 2's `osEvent == null` branch,
  /// when it was only moved. `[2000, 2100]` is the same bound this app
  /// already uses for every other user-facing date (see
  /// `event_editor_sheet.dart`'s own date picker), so nothing created
  /// through the app can ever fall outside it.
  ///
  /// Null (never an empty map, in this one case) when no target calendar
  /// can be resolved at all — step 2's caller treats that as "couldn't
  /// check", not "checked and found nothing".
  Future<Map<String, dc.Event>?> _fetchLinkedOsEventsById() async {
    final targetId = await _service.resolveTargetCalendarId();
    if (targetId == null) return null;
    final events = await _service.listEvents(
      targetId,
      from: DateTime(2000),
      to: DateTime(2100),
    );
    return {for (final e in events) e.eventId: e};
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
  /// just past) [notificationSchedulingWindow] — each of an event's reminder
  /// offsets is judged on its own (see [NotificationService.refillEvents]),
  /// so this just needs to give every candidate a chance to be re-evaluated;
  /// offsets already correctly scheduled are skipped without a platform
  /// call, and any that have since rolled inside the window get armed. Safe
  /// to run on every foreground resume — batched through [refillEvents]
  /// rather than one [NotificationPort.scheduleForEvent] call per event, so
  /// a resume with dozens of upcoming events doesn't cost a platform call
  /// per offset per event just to confirm most of them are unchanged.
  Future<void> _refillNotifications(DateTime at) async {
    final windowEnd = at.add(notificationSchedulingWindow);
    final candidates = await _eventDao.between(at, windowEnd.add(_maxLeadTime));
    final notifiable = [
      for (final row in candidates)
        if (row.notify) row,
    ];
    await _notifications.refillEvents(notifiable);
  }

  Future<void> _log(String? title, SyncResolution resolution, String detail) {
    return _syncLogDao.add(
      SyncLogsCompanion(
        eventTitle: Value(title),
        resolution: Value(resolution),
        detail: Value(detail),
      ),
    );
  }
}
