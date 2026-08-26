import '../../../core/db/app_database.dart';

/// Ports the [EventRepository] drives when an event changes. Concrete
/// implementations live in core/ (notifications, calendar_sync), so the
/// repository stays the single write choke point without depending on plugin
/// details directly.

/// Schedules / cancels the local notification tied to an event or a to-do.
abstract class NotificationPort {
  Future<void> scheduleForEvent(EventRow event);
  Future<void> cancelForEvent(String eventId);

  /// Bulk counterpart to [scheduleForEvent] for a foreground-resume refill
  /// pass over many events at once — see `NotificationService.refillEvents`
  /// for why this exists as its own method instead of a loop of
  /// [scheduleForEvent] calls.
  Future<void> refillEvents(List<EventRow> events);

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

/// Writes to-dos through to the OS reminders list (iOS EventKit only — see
/// `RemindersService`). Same shape as [CalendarPort]; a separate interface
/// because a to-do's OS counterpart is a reminder, not a calendar event, and
/// because this is off by default and independently toggled from calendar
/// sync in settings.
abstract class RemindersPort {
  bool get isEnabled;

  /// Returns the OS reminder id for the written to-do, or null if not
  /// written.
  Future<String?> pushTodo(TodoRow todo);

  Future<void> deleteTodo(TodoRow todo);
}

/// A no-op reminders port used when to-do/reminders sync is disabled or
/// unavailable (Android has no OS reminders concept at all). Keeps
/// [TodoController] logic uniform (it always calls the port).
class DisabledRemindersPort implements RemindersPort {
  const DisabledRemindersPort();

  @override
  bool get isEnabled => false;

  @override
  Future<String?> pushTodo(TodoRow todo) async => null;

  @override
  Future<void> deleteTodo(TodoRow todo) async {}
}
