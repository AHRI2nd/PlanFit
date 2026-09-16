import 'package:device_calendar_plus/device_calendar_plus.dart';

import '../db/app_database.dart';
import '../serial_queue.dart';
import '../../features/schedule/domain/ports.dart';

/// Thin wrapper over `device_calendar_plus` that also implements the
/// [CalendarPort] the event repository drives. It owns the "is sync on and
/// which calendar do we write to" configuration; the settings screen flips
/// [enabled] and picks [targetCalendarId].
///
/// This service is a singleton (`di.dart`) reached from two independent
/// paths that can run concurrently: [EventRepositoryImpl] pushes/deletes
/// directly off a user edit, and [CalendarReconciler] does its own
/// `needingPush`-driven push pass on every app-foreground resume. A local
/// row stays [SyncStatus.pendingPush] in the database for the whole
/// platform-channel round trip [pushEvent] takes — right up until the
/// caller patches its `osEventId`/`syncStatus` back afterward — so a
/// reconcile landing in that exact window used to see the same row as
/// "still needing a push" and push it again independently, racing the
/// original call and creating a second, duplicate OS event for one local
/// row (whichever push resolved last "won" the `osEventId` link; the other
/// was silently orphaned). [_writeQueue] serializes every [pushEvent]/
/// [deleteEvent]/[deleteEventById] call through this instance, so two
/// concurrent callers' writes can never interleave — same pattern (and
/// same underlying [SerialQueue]) already used by
/// `SettingsController._writeQueue` and `TodoController._reorderQueue`.
class CalendarService implements CalendarPort {
  CalendarService({
    this.enabled = false,
    this.targetCalendarId,
    this.autoImportEnabled = false,
    this.subscribedCalendarIds = const {},
  });

  final DeviceCalendar _plugin = DeviceCalendar.instance;

  /// See this class's own doc comment for why every write below is
  /// serialized through this.
  final _writeQueue = SerialQueue();

  /// Whether device-calendar sync is on. Flipped from settings.
  bool enabled;

  /// The calendar events are written to; resolved lazily if unset.
  String? targetCalendarId;

  /// Whether [CalendarReconciler] also imports events created *directly* in
  /// the calendar app (not PlanFit) as new PlanFit events — scanning both
  /// [targetCalendarId] and the device's primary calendar, see
  /// `CalendarReconciler._autoImportCalendarIds`'s doc. Flipped from
  /// settings, off by default.
  bool autoImportEnabled;

  /// Calendars continuously mirrored *in* (read-only) — see
  /// [AppSettings.subscribedCalendarIds]/[CalendarImportService]. The
  /// opposite direction from [targetCalendarId], and independent of
  /// [enabled].
  Set<String> subscribedCalendarIds;

  @override
  bool get isEnabled => enabled;

  // --- Permissions ---

  Future<bool> hasFullAccess() async {
    final status = await _plugin.hasPermissions();
    return status == CalendarPermissionStatus.granted;
  }

  /// Prompts for full (read+write) access — read is needed so we can reconcile
  /// edits made in the device calendar app back into PlanFit.
  Future<bool> requestAccess() async {
    final status = await _plugin.requestPermissions(
      level: CalendarAccessLevel.full,
    );
    return status == CalendarPermissionStatus.granted;
  }

  Future<void> openSettings() => _plugin.openAppSettings();

  /// Writable calendars the user can be offered as a sync target (excludes
  /// subscribed/read-only feeds).
  Future<List<Calendar>> writableCalendars() async {
    final calendars = await _plugin.listCalendars();
    return calendars.where((c) => !c.readOnly).toList();
  }

  /// Every calendar on the device, including read-only/subscribed feeds —
  /// used to offer an import *source*, where read-only is fine (a holiday
  /// calendar, a shared work calendar the user can't write to), unlike
  /// [writableCalendars]'s sync-*target* use.
  Future<List<Calendar>> allCalendars() => _plugin.listCalendars();

  /// Events on [calendarId] within `[from, to)`, for [CalendarImportService]
  /// to copy into PlanFit. Recurring events already arrive pre-expanded into
  /// one [Event] per occurrence (see `listEvents`'s doc on the plugin side).
  Future<List<Event>> listEvents(
    String calendarId, {
    required DateTime from,
    required DateTime to,
  }) {
    return _plugin.listEvents(from, to, calendarIds: [calendarId]);
  }

  static const String _ownCalendarName = 'PlanFit';
  // Mirrors the brand accent (dawnIndigo); duplicated as a literal rather
  // than importing design/ tokens, since core/ shouldn't depend on it.
  static const String _ownCalendarColorHex = '#4B5FD6';

  /// Resolves where PlanFit writes events. The first time this runs (no
  /// [targetCalendarId] persisted yet), it creates a dedicated "PlanFit"
  /// calendar rather than writing into whatever the OS calls the primary
  /// calendar — so PlanFit's events show up as their own separate, toggleable
  /// entry in the device's calendar app instead of mixed into the user's
  /// personal/work calendar. The created id is cached here and should be
  /// persisted by the caller (see SettingsScreen) so this only runs once.
  ///
  /// [targetCalendarId] being unset doesn't always mean no "PlanFit" calendar
  /// exists yet — uninstalling the app (or clearing its storage) resets that
  /// persisted id but does *not* delete calendars already created at the OS
  /// level, since those live in EventKit/CalendarProvider, outside the app's
  /// own storage. Reusing a same-named calendar if one's already there keeps
  /// every reinstall/data-clear from piling up a fresh duplicate.
  ///
  /// Single-flighted via [_resolving]: this service is a singleton
  /// (`di.dart`), and `pushEvent`/settings-screen toggles/the reconciler can
  /// all call this independently — e.g. an app-resume reconcile and a
  /// settings toggle landing close together. Without a guard, two calls that
  /// both start while [targetCalendarId] is still null would each run the
  /// find-or-create sequence and could each end up creating their own
  /// "PlanFit" calendar. Caching the in-flight `Future` itself (not just the
  /// eventual result) means every concurrent caller awaits the *same*
  /// resolution instead of racing a second one.
  Future<String?> resolveTargetCalendarId() {
    if (targetCalendarId != null) return Future.value(targetCalendarId);
    return _resolving ??= _doResolveTargetCalendarId().whenComplete(
      () => _resolving = null,
    );
  }

  Future<String?>? _resolving;

  Future<String?> _doResolveTargetCalendarId({
    int authorizationRetry = 0,
  }) async {
    final Calendar? existing;
    try {
      existing = await _findOwnCalendar();
    } on DeviceCalendarException catch (error) {
      // Listing calendars can fail on the very call that follows the user
      // granting access. The platform plugin holds one long-lived event
      // store built at app launch, and it gates every read on re-reading
      // the OS authorization status — which, on iOS, has not caught up by
      // the time the grant's own completion handler has already reported
      // success. So the toggle asks for access, is told yes, and its next
      // call is refused.
      //
      // A freshly-granted iOS permission can take more than one run-loop
      // turn to become visible to the plugin's long-lived EventStore. Give
      // that specific stale-permission case one short, bounded retry before
      // reporting "no target". The retry stays here (rather than in the UI)
      // so resume reconciliation and direct repository writes get the same
      // behavior.
      if (error.errorCode == DeviceCalendarError.permissionDenied &&
          authorizationRetry == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return _doResolveTargetCalendarId(authorizationRetry: 1);
      }

      // Report "no target" instead of letting that escape. The settings
      // toggle already treats a null here as "nothing to sync into, leave
      // the switch off" — the branch right below its call — so this lands
      // in a path that was already designed for it. Before, the throw sailed
      // past that branch and out of the button handler entirely, surfacing
      // as an unhandled exception while the UI just sat there.
      //
      // Sync starts working on the next launch, when the store is rebuilt
      // with the permission already in place. Telling the user that is a
      // separate concern from not crashing, and is not done here.
      return null;
    }
    if (existing != null) {
      targetCalendarId = existing.id;
      return existing.id;
    }

    try {
      final id = await _plugin.createCalendar(
        name: _ownCalendarName,
        colorHex: _ownCalendarColorHex,
      );
      targetCalendarId = id;
      return id;
    } catch (_) {
      // Calendar creation can fail on some accounts/platforms (e.g. no
      // account eligible to host a new local calendar) — fall back to an
      // existing writable calendar rather than leaving sync silently broken.
      final List<Calendar> writable;
      try {
        writable = await writableCalendars();
      } on DeviceCalendarException {
        // Same stale-authorization case as above, reached by the other
        // route: creation failed *because* of it, so the fallback read
        // fails too. Without this the exception would escape from inside a
        // catch block, which is the same unhandled crash by a longer path.
        return null;
      }
      if (writable.isEmpty) return null;
      final primary = writable.firstWhere(
        (c) => c.isPrimary,
        orElse: () => writable.first,
      );
      targetCalendarId = primary.id;
      return primary.id;
    }
  }

  /// A previously-created "PlanFit" calendar, if the OS still has one —
  /// see [resolveTargetCalendarId]. Picks the first match when more than
  /// one exists (e.g. left over from this exact bug before it was fixed);
  /// it doesn't try to merge or clean up the rest.
  Future<Calendar?> _findOwnCalendar() async {
    final calendars = await writableCalendars();
    for (final c in calendars) {
      if (c.name == _ownCalendarName) return c;
    }
    return null;
  }

  // --- CalendarPort ---

  @override
  Future<String?> pushEvent(EventRow event) => _writeQueue.run(() async {
    final calendarId = await resolveTargetCalendarId();
    if (calendarId == null) return null;

    if (event.osEventId != null) {
      try {
        await _plugin.updateEvent(
          eventId: event.osEventId!,
          title: event.title,
          startDate: event.startAt,
          endDate: event.endAt,
          isAllDay: event.isAllDay,
          description: event.memo == null
              ? const Patch.clear()
              : Patch.set(event.memo!),
          location: event.location == null
              ? const Patch.clear()
              : Patch.set(event.location!),
        );
        return event.osEventId;
      } on DeviceCalendarException catch (e) {
        if (e.errorCode != DeviceCalendarError.notFound) rethrow;
        // The OS event this row was linked to is gone (deleted in the
        // calendar app, or its calendar itself removed) — fall through to
        // create a fresh one instead of leaving the row stuck forever
        // retrying an update against a dead id.
      }
    }

    return _plugin.createEvent(
      calendarId: calendarId,
      title: event.title.isEmpty ? ' ' : event.title,
      startDate: event.startAt,
      endDate: event.endAt,
      isAllDay: event.isAllDay,
      description: event.memo,
      location: event.location,
    );
  });

  @override
  Future<void> deleteEvent(EventRow event) async {
    final osId = event.osEventId;
    if (osId == null) return;
    await deleteEventById(osId);
  }

  /// Same as [deleteEvent], for a caller that only has the raw OS event id
  /// and no [EventRow] to go with it — [CalendarReconciler]'s retry of a
  /// [PendingCalendarDeletions] tombstone, where the local row is already
  /// gone by definition.
  Future<void> deleteEventById(String osId) => _writeQueue.run(() async {
    try {
      await _plugin.deleteEvent(eventId: osId);
    } on DeviceCalendarException catch (e) {
      if (e.errorCode != DeviceCalendarError.notFound) rethrow;
      // Already gone from the OS calendar — deleting it is already the
      // desired end state, so this isn't actually a failure.
    }
  });

  /// Reads a single OS event back (used by the reconciler to detect edits or
  /// deletions made in the calendar app). Returns null if it no longer exists.
  Future<Event?> fetchEvent(String osEventId) => _plugin.getEvent(osEventId);
}
