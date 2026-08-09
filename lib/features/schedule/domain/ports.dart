import '../../../core/db/app_database.dart';

/// Ports the [EventRepository] drives when an event changes. Concrete
/// implementations live in core/ (notifications, calendar_sync), so the
/// repository stays the single write choke point without depending on plugin
/// details directly.

/// Schedules / cancels the local notification tied to an event or a to-do.
abstract class NotificationPort {
  Future<void> scheduleForEvent(EventRow event);
  Future<void> cancelForEvent(String eventId);

  /// A to-do's due-time alert — see `TodoItems.notify`'s doc for why this is
  /// simpler than [scheduleForEvent] (no lead-time, no multiple offsets).
  Future<void> scheduleForTodo(TodoRow todo);
  Future<void> cancelForTodo(String todoId);
}

/// Writes events through to the device calendar. Returns the OS event id on
/// success, or null when sync is off / unavailable — in which case the event
/// simply stays local.
abstract class CalendarPort {
  bool get isEnabled;

  /// Returns the OS event id for the written event, or null if not written.
  Future<String?> pushEvent(EventRow event);

  Future<void> deleteEvent(EventRow event);
}

/// A no-op calendar port used when device-calendar sync is disabled. Keeps the
/// repository logic uniform (it always calls the port).
class DisabledCalendarPort implements CalendarPort {
  const DisabledCalendarPort();

  @override
  bool get isEnabled => false;

  @override
  Future<String?> pushEvent(EventRow event) async => null;

  @override
  Future<void> deleteEvent(EventRow event) async {}
}
