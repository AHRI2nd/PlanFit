/// [DateTime.add]/[DateTime.subtract] with a `Duration(days: n)` operate on
/// **elapsed real time** (exactly `n * 24` hours), not calendar days. On a
/// local (non-UTC) [DateTime], that's wrong whenever the range crosses a DST
/// transition: adding 3 real days to `2026-03-05 09:00` (US Eastern, before
/// the Mar 8 spring-forward) lands on `2026-03-08 10:00`, not `09:00` — every
/// occurrence from that point on stays shifted an hour, since each further
/// `.add` compounds from the drifted value.
///
/// [addCalendarDays] instead reconstructs the result from calendar fields
/// (year/month/day + the *same* time-of-day), which is what every call site
/// in this app actually means by "N days later" — a calendar app's whole
/// data model is calendar days, never elapsed real time. Dart's [DateTime]
/// constructor already normalizes an out-of-range `day` (rolling into the
/// next month/year as needed), so this is a safe drop-in replacement for
/// `dt.add(Duration(days: n))` — pass a negative [days] for subtraction.
DateTime addCalendarDays(DateTime dt, int days) {
  return DateTime(
    dt.year,
    dt.month,
    dt.day + days,
    dt.hour,
    dt.minute,
    dt.second,
    dt.millisecond,
    dt.microsecond,
  );
}

const int _minutesPerDay = 24 * 60;

/// [dt]'s date with its time-of-day shifted by [delta] — same DST-safety as
/// [addCalendarDays], for the same reason: `dt.add(delta)` would add real
/// elapsed time and drift the wall-clock time across a DST transition,
/// whereas this only ever reconstructs a wall-clock reading from calendar
/// fields. [delta] rolling past midnight (either direction) correctly moves
/// the date, e.g. 23:00 shifted by +2h lands on the *next* day at 01:00.
DateTime shiftTimeOfDay(DateTime dt, Duration delta) {
  final totalMinutes = dt.hour * 60 + dt.minute + delta.inMinutes;
  // Dart's `%` on a positive divisor always returns a non-negative result,
  // so this is already the correct minute-of-day regardless of totalMinutes'
  // sign.
  final minuteOfDay = totalMinutes % _minutesPerDay;
  final dayShift = (totalMinutes - minuteOfDay) ~/ _minutesPerDay;
  return DateTime(
    dt.year,
    dt.month,
    dt.day + dayShift,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
    dt.second,
    dt.millisecond,
    dt.microsecond,
  );
}
