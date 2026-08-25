import '../../../core/date_math.dart';
import '../../../core/db/app_database.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Every calendar day within `[rangeStart, rangeEnd)` that [event]'s own
/// `[startAt, endAt)` interval overlaps — used to render a multi-day event
/// (typically an all-day one) as a continuous bar across every day it
/// touches, instead of a marker on just its start date. Shared by the week
/// and month grids so both use the same "which days does this touch" rule.
///
/// [endAt] is treated as exclusive, matching `EventDao`'s own half-open
/// overlap convention (see event_dao.dart's `_overlaps`) and how all-day
/// events are normalized at save time (event_editor_sheet.dart) — an event
/// ending exactly at a day's midnight doesn't spill into that day.
List<DateTime> eventDaysInRange(
  EventRow event,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final eventStart = _dateOnly(event.startAt);
  final firstDay = eventStart.isBefore(rangeStart) ? rangeStart : eventStart;

  final lastTouchedDay = _dateOnly(
    event.endAt.subtract(const Duration(microseconds: 1)),
  );
  final exclusiveEnd = addCalendarDays(lastTouchedDay, 1);
  final end = exclusiveEnd.isAfter(rangeEnd) ? rangeEnd : exclusiveEnd;

  final days = <DateTime>[];
  var d = firstDay;
  while (d.isBefore(end)) {
    days.add(d);
    d = addCalendarDays(d, 1);
  }
  return days;
}
