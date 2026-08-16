import 'package:device_calendar_plus/device_calendar_plus.dart';

import '../db/app_database.dart';
import '../../features/schedule/domain/ports.dart';

/// Thin wrapper over `device_calendar_plus` that also implements the
/// [CalendarPort] the event repository drives. It owns the "is sync on and
/// which calendar do we write to" configuration; the settings screen flips
/// [enabled] and picks [targetCalendarId].
class CalendarService implements CalendarPort {
  CalendarService({
    this.enabled = false,
    this.targetCalendarId,
    this.autoImportEnabled = false,
    this.subscribedCalendarIds = const {},
  });

  final DeviceCalendar _plugin = DeviceCalendar.instance;

  /// Whether device-calendar sync is on. Flipped from settings.
  bool enabled;

  /// The calendar events are written to; resolved lazily if unset.
  String? targetCalendarId;

  /// Whether [CalendarReconciler] also imports events created *directly* in
  /// [targetCalendarId] (the calendar app, not PlanFit) as new PlanFit
  /// events — see `AppSettings.autoImportCalendarEnabled`'s doc. Flipped
  /// from settings, off by default.
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
    final status =
        await _plugin.requestPermissions(level: CalendarAccessLevel.full);
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
    return _resolving ??=
        _doResolveTargetCalendarId().whenComplete(() => _resolving = null);
  }

  Future<String?>? _resolving;

  Future<String?> _doResolveTargetCalendarId() async {
    final existing = await _findOwnCalendar();
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
      final writable = await writableCalendars();
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
  Future<String?> pushEvent(EventRow event) async {
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
  }

  @override
  Future<void> deleteEvent(EventRow event) async {
    final osId = event.osEventId;
    if (osId == null) return;
    try {
      await _plugin.deleteEvent(eventId: osId);
    } on DeviceCalendarException catch (e) {
      if (e.errorCode != DeviceCalendarError.notFound) rethrow;
      // Already gone from the OS calendar — deleting it is already the
      // desired end state, so this isn't actually a failure.
    }
  }

  /// Reads a single OS event back (used by the reconciler to detect edits or
  /// deletions made in the calendar app). Returns null if it no longer exists.
  Future<Event?> fetchEvent(String osEventId) => _plugin.getEvent(osEventId);
}
