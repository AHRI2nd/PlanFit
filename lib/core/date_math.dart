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

/// Adds [months] calendar months to [dt], preserving time-of-day and
/// clamping the day-of-month if the target month is shorter (e.g. Jan 31
/// + 1 month lands on Feb 28, not rolling into March). Negative [months]
/// moves into the past. Dart's `~/` truncates toward zero (not floor), so
/// a naive `(dt.month - 1 + months) % 12` mishandles negative totals across
/// a year boundary — this instead derives the year/month split from `%`'s
/// Euclidean remainder (always non-negative for a positive divisor).
DateTime addCalendarMonths(DateTime dt, int months) {
  final total = dt.month - 1 + months;
  final monthIndex = total % 12; // Euclidean mod: always in [0, 11].
  final yearOffset = (total - monthIndex) ~/ 12; // exact multiple of 12.
  final year = dt.year + yearOffset;
  final month = monthIndex + 1;
  // Day 0 of the *next* month is the last day of the target month; the
  // DateTime constructor already normalizes month 13 into January of
  // year+1, so December targets need no special-casing here.
  final daysInTargetMonth = DateTime(year, month + 1, 0).day;
  final day = dt.day > daysInTargetMonth ? daysInTargetMonth : dt.day;
  return DateTime(
    year,
    month,
    day,
    dt.hour,
    dt.minute,
    dt.second,
    dt.millisecond,
    dt.microsecond,
  );
}

/// Adds [years] calendar years to [dt], preserving time-of-day and
/// clamping Feb 29 to Feb 28 in a non-leap target year — delegates to
/// [addCalendarMonths] so both share one day-clamping rule.
DateTime addCalendarYears(DateTime dt, int years) =>
    addCalendarMonths(dt, years * 12);

/// [end]'s wall-clock offset from [start] — same calendar-days-plus-
/// time-of-day shape [shiftTimeOfDay] takes, computed the DST-safe way
/// instead of via [DateTime.difference] (which measures **elapsed real
/// time** between the two instants, not the wall-clock span between them).
///
/// This matters wherever one event's own start/end span is captured once,
/// then *replayed* onto a different date — recurrence expansion's own
/// duration, most notably: a daily "21:00–05:00 (8h)" overnight event whose
/// span happens to be computed from a pair that straddles a DST transition
/// would otherwise carry that transition's hour of drift into every future
/// occurrence, even ones nowhere near a transition themselves. Pass the
/// result to [shiftTimeOfDay] (not [DateTime.add]) to apply it — that's what
/// actually reconstructs the target wall-clock time DST-safely; this only
/// computes the shift, mirroring [addCalendarDays]/[shiftTimeOfDay]'s own
/// split between "how far" and "apply it."
///
/// The calendar-day count itself is computed via [DateTime.utc] on each
/// side's date-only fields — sidestepping local-time DST distortion in the
/// subtraction entirely, since a UTC-to-UTC day boundary is always exactly
/// 24 real hours regardless of what the *local* clock does that day.
Duration calendarDuration(DateTime start, DateTime end) {
  final days = DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  return Duration(
    days: days,
    hours: end.hour - start.hour,
    minutes: end.minute - start.minute,
    seconds: end.second - start.second,
    milliseconds: end.millisecond - start.millisecond,
    microseconds: end.microsecond - start.microsecond,
  );
}
