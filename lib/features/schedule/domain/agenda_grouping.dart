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
