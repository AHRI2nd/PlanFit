import '../../../core/db/app_database.dart';

/// Groups [events] by the calendar day their `startAt` falls on, sorted by
/// day then by `startAt` within each day.
///
/// A multi-day event appears once, under its start day only — the agenda
/// view's flat chronological list is a different convention from the
/// month/week views' continuous spanning bars (see `eventDaysInRange`),
/// matching how most calendar apps' agenda/list views work.
List<(DateTime day, List<EventRow> events)> groupEventsByDay(
  List<EventRow> events,
) {
  final byDay = <DateTime, List<EventRow>>{};
  for (final e in events) {
    final day = DateTime(e.startAt.year, e.startAt.month, e.startAt.day);
    (byDay[day] ??= []).add(e);
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days)
      (day, byDay[day]!..sort((a, b) => a.startAt.compareTo(b.startAt))),
  ];
}

/// One row in the agenda view's merged, time-sorted list — either an event
/// or a to-do, distinguished by [sortKey] alone so [groupAgendaEntriesByDay]
/// can sort a day's events and to-dos into one chronological sequence
/// without a runtime type check at the call site (the agenda view itself
/// still pattern-matches on the concrete subclass to pick which tile to
/// render).
sealed class AgendaEntry {
  const AgendaEntry();
  DateTime get sortKey;
}

class AgendaEventEntry extends AgendaEntry {
  const AgendaEventEntry(this.event);
  final EventRow event;
  @override
  DateTime get sortKey => event.startAt;
}

class AgendaTodoEntry extends AgendaEntry {
  const AgendaTodoEntry(this.todo);
  final TodoRow todo;
  @override
  DateTime get sortKey => todo.slotStart;
}

/// Groups [events] and [todos] together by calendar day, each day's entries
/// sorted chronologically by [AgendaEntry.sortKey] — the agenda view's
/// to-do-merge counterpart to [groupEventsByDay]. A no-time to-do keeps
/// `slotStart` pinned to midnight (see `TodoController.add`), so it
/// naturally sorts first within its day, same convention the home screen's
/// own event+to-do feed merge already relies on.
///
/// A multi-day event still appears once, under its start day only — same
/// convention [groupEventsByDay] already documents, unaffected by merging
/// to-dos in.
List<(DateTime day, List<AgendaEntry> entries)> groupAgendaEntriesByDay(
  List<EventRow> events,
  List<TodoRow> todos,
) {
  final byDay = <DateTime, List<AgendaEntry>>{};
  for (final e in events) {
    final day = DateTime(e.startAt.year, e.startAt.month, e.startAt.day);
    (byDay[day] ??= []).add(AgendaEventEntry(e));
  }
  for (final t in todos) {
    final day = DateTime(t.slotStart.year, t.slotStart.month, t.slotStart.day);
    (byDay[day] ??= []).add(AgendaTodoEntry(t));
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days)
      (day, byDay[day]!..sort((a, b) => a.sortKey.compareTo(b.sortKey))),
  ];
}
