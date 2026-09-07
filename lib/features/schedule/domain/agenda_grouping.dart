import '../../../core/db/app_database.dart';

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
/// sorted chronologically by [AgendaEntry.sortKey]. A no-time to-do keeps
/// `slotStart` pinned to midnight (see `TodoController.add`), so it
/// naturally sorts first within its day, same convention the home screen's
/// own event+to-do feed merge already relies on.
///
/// A multi-day event still appears once, under its start day only — the
/// agenda view's flat chronological list is a different convention from the
/// month/week views' continuous spanning bars (see `eventDaysInRange`),
/// matching how most calendar apps' agenda/list views work.
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
  return [for (final day in days) (day, _sortStableByKey(byDay[day]!))];
}

/// Sorts [entries] by [AgendaEntry.sortKey], preserving each day's original
/// event-then-todo insertion order among entries that share the exact same
/// sort key (e.g. two no-time to-dos, both pinned to midnight — see this
/// file's own doc comment) — a plain `List.sort` doesn't guarantee that:
/// Dart's `List.sort` is only stable below a small size threshold, above
/// which it switches to an unstable dual-pivot quicksort, so a day with
/// enough same-key entries could have their relative order silently
/// shuffled on every rebuild even though nothing about the data changed.
/// Decorating each entry with its original index and folding that into the
/// comparator as a tiebreaker makes the result stable no matter which
/// underlying algorithm `List.sort` picks.
List<AgendaEntry> _sortStableByKey(List<AgendaEntry> entries) {
  final indexed = [for (var i = 0; i < entries.length; i++) (i, entries[i])];
  indexed.sort((a, b) {
    final byKey = a.$2.sortKey.compareTo(b.$2.sortKey);
    return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
  });
  return [for (final (_, entry) in indexed) entry];
}
