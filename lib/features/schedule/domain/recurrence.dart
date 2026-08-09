/// How often a newly-created event repeats. `none` means a one-off event —
/// the pre-existing, default behavior.
enum RecurrenceFrequency { none, daily, weekly, monthly, yearly }

/// Expands a recurrence into concrete occurrences and renders its RRULE
/// string. Recurrence is deliberately **materialized**: each occurrence
/// becomes its own [Events] row (sharing a `recurrenceGroupId`) rather than
/// being expanded from an RRULE at query time. That keeps every existing
/// date-range query, the OS calendar push, and per-occurrence edit/delete
/// unchanged — and sidesteps recurring-event support in the calendar plugin
/// ecosystem, flagged as the flakiest part of that integration.
class RecurrenceExpansion {
  const RecurrenceExpansion._();

  /// Hard ceiling on generated rows, regardless of how far out [until] is or
  /// how large [count] is — a defensive bound against a mis-picked end date
  /// (or count) generating thousands of rows.
  static const int maxOccurrences = 200;

  /// Start/end pairs for every occurrence, preserving the [start]-to-[end]
  /// duration and capped at [maxOccurrences]. Ends either on a date
  /// ([until], inclusive) or after a fixed number of occurrences ([count]) —
  /// exactly one of the two must be provided whenever [frequency] isn't
  /// [RecurrenceFrequency.none] (mirrors RFC 5545's own `UNTIL`/`COUNT`
  /// mutual exclusivity).
  ///
  /// [until] is compared by **date only**, not exact instant: an occurrence
  /// landing anywhere on [until]'s calendar day is included, matching the
  /// date-only "ends on" picker in the editor UI regardless of what
  /// time-of-day [start] happens to be. The first occurrence (`start`,
  /// `end`) is always included, even if [until] is before [start]'s date —
  /// this never returns an empty list.
  ///
  /// [byWeekdays] only changes anything for [RecurrenceFrequency.weekly]: a
  /// non-empty set repeats on *every* selected weekday each week (Dart's
  /// `DateTime.weekday` numbering, 1=Monday..7=Sunday) instead of just
  /// [start]'s own weekday. Null/empty preserves the original "same weekday
  /// as start" behavior exactly, so existing callers are unaffected.
  static List<(DateTime start, DateTime end)> occurrences({
    required DateTime start,
    required DateTime end,
    required RecurrenceFrequency frequency,
    DateTime? until,
    int? count,
    Set<int>? byWeekdays,
  }) {
    if (frequency == RecurrenceFrequency.none) return [(start, end)];
    assert(
      (until == null) != (count == null),
      'exactly one of until or count is required when frequency is not none',
    );

    final duration = end.difference(start);
    // A count-mode cap has no date boundary at all; a date-mode cap is
    // simply the usual maxOccurrences (occurrences() below still stops the
    // moment it passes `until`, whichever comes first).
    final cap = count == null ? maxOccurrences : count.clamp(1, maxOccurrences);

    if (frequency == RecurrenceFrequency.weekly &&
        byWeekdays != null &&
        byWeekdays.isNotEmpty) {
      final dates = _weeklyByWeekdaysDates(
        start: start,
        until: until,
        weekdays: {...byWeekdays, start.weekday},
        limit: cap,
      );
      if (dates.isEmpty) return [(start, end)];
      return [
        for (final d in dates)
          (
            DateTime(d.year, d.month, d.day, start.hour, start.minute),
            DateTime(
              d.year,
              d.month,
              d.day,
              start.hour,
              start.minute,
            ).add(duration),
          ),
      ];
    }

    final untilDate = until == null ? null : _dateOnly(until);
    final result = <(DateTime, DateTime)>[(start, end)];
    var step = 1;
    while (result.length < cap) {
      final occurrenceStart = _advance(start, frequency, step);
      if (untilDate != null && _dateOnly(occurrenceStart).isAfter(untilDate)) {
        break;
      }
      result.add((occurrenceStart, occurrenceStart.add(duration)));
      step++;
    }
    return result;
  }

  /// Whether [occurrences] for these inputs would be cut off by
  /// [maxOccurrences] before actually reaching [until]/[count] — i.e. the
  /// series the user asked for is longer than the cap allows, so the DB rows
  /// stop short of their chosen end. Used to warn on save rather than
  /// silently truncating. Exactly one of [until]/[count] is required, same
  /// as [occurrences].
  static bool isTruncated({
    required DateTime start,
    required RecurrenceFrequency frequency,
    DateTime? until,
    int? count,
    Set<int>? byWeekdays,
  }) {
    if (frequency == RecurrenceFrequency.none) return false;
    assert(
      (until == null) != (count == null),
      'exactly one of until or count is required when frequency is not none',
    );

    // Count-mode has no date boundary to walk toward — truncation is just
    // "did the user ask for more than the cap allows".
    if (count != null) return count > maxOccurrences;

    if (frequency == RecurrenceFrequency.weekly &&
        byWeekdays != null &&
        byWeekdays.isNotEmpty) {
      final dates = _weeklyByWeekdaysDates(
        start: start,
        until: until,
        weekdays: {...byWeekdays, start.weekday},
        limit: maxOccurrences + 1,
      );
      return dates.length > maxOccurrences;
    }
    final untilDate = _dateOnly(until!);
    final nextStart = _advance(start, frequency, maxOccurrences);
    return !_dateOnly(nextStart).isAfter(untilDate);
  }

  /// Every date from [start]'s own date onward whose weekday is in
  /// [weekdays], up to [until] (inclusive, or unbounded when null) or
  /// [limit] dates, whichever comes first. Shared by [occurrences] and
  /// [isTruncated] — callers pass `maxOccurrences` and `maxOccurrences + 1`
  /// respectively so the latter can tell "exactly at the cap" apart from
  /// "one more exists beyond it". Always makes progress every 7 days at most
  /// (a weekly-by-weekday pattern repeats with period 7), so this is bounded
  /// even for a distant or absent [until].
  static List<DateTime> _weeklyByWeekdaysDates({
    required DateTime start,
    DateTime? until,
    required Set<int> weekdays,
    required int limit,
  }) {
    final untilDate = until == null ? null : _dateOnly(until);
    final result = <DateTime>[];
    var day = _dateOnly(start);
    while (result.length < limit &&
        (untilDate == null || !day.isAfter(untilDate))) {
      if (weekdays.contains(day.weekday)) result.add(day);
      day = day.add(const Duration(days: 1));
    }
    return result;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _advance(
    DateTime start,
    RecurrenceFrequency frequency,
    int step,
  ) {
    return switch (frequency) {
      RecurrenceFrequency.none => start,
      RecurrenceFrequency.daily => start.add(Duration(days: step)),
      RecurrenceFrequency.weekly => start.add(Duration(days: step * 7)),
      RecurrenceFrequency.monthly => _sameDayOfMonth(
        start,
        start.year,
        start.month + step,
      ),
      RecurrenceFrequency.yearly => _sameDayOfMonth(
        start,
        start.year + step,
        start.month,
      ),
    };
  }

  /// [start]'s day-of-month carried into [year]/[month], clamped to that
  /// month's last day when it doesn't have one (e.g. day 31 in a
  /// 30-day month). Plain `DateTime(year, month, start.day)` doesn't clamp —
  /// it *overflows* into the following month instead (Dart's DateTime
  /// normalizes out-of-range fields rather than rejecting them), so "monthly
  /// on the 31st" would silently drift to different days each month (Jan 31
  /// → "Feb 31" → Mar 3) instead of landing on Feb's actual last day.
  static DateTime _sameDayOfMonth(DateTime start, int year, int month) {
    // Rolls month 13 into next year, month 0 into previous, etc., the same
    // way the call sites' `start.month + step` can already go out of 1..12.
    final normalizedYear = year + (month - 1) ~/ 12;
    final normalizedMonth = (month - 1) % 12 + 1;
    final daysInMonth = DateTime(normalizedYear, normalizedMonth + 1, 0).day;
    final day = start.day > daysInMonth ? daysInMonth : start.day;
    return DateTime(
      normalizedYear,
      normalizedMonth,
      day,
      start.hour,
      start.minute,
    );
  }

  /// Renders `UNTIL=` or `COUNT=` depending on which of [until]/[count] is
  /// given — exactly one is required whenever [frequency] isn't
  /// [RecurrenceFrequency.none], mirroring [occurrences]. [byWeekdays] only
  /// affects the output for [RecurrenceFrequency.weekly] — a non-empty set
  /// adds a `BYDAY=` part (informational only, like the rest of this
  /// string; see the class doc comment).
  static String toRruleString(
    RecurrenceFrequency frequency, {
    DateTime? until,
    int? count,
    Set<int>? byWeekdays,
  }) {
    assert(
      frequency == RecurrenceFrequency.none ||
          (until == null) != (count == null),
      'exactly one of until or count is required when frequency is not none',
    );
    final freq = switch (frequency) {
      RecurrenceFrequency.daily => 'DAILY',
      RecurrenceFrequency.weekly => 'WEEKLY',
      RecurrenceFrequency.monthly => 'MONTHLY',
      RecurrenceFrequency.yearly => 'YEARLY',
      RecurrenceFrequency.none => 'NONE',
    };
    final endPart = count != null
        ? ';COUNT=$count'
        : ';UNTIL=${_utcStamp(until!)}';
    final byDay =
        frequency == RecurrenceFrequency.weekly &&
            byWeekdays != null &&
            byWeekdays.isNotEmpty
        ? ';BYDAY=${_byDayCodes(byWeekdays)}'
        : '';
    return 'FREQ=$freq$endPart$byDay';
  }

  static String _utcStamp(DateTime dt) {
    final utc = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  static const _byDayNames = {
    1: 'MO',
    2: 'TU',
    3: 'WE',
    4: 'TH',
    5: 'FR',
    6: 'SA',
    7: 'SU',
  };

  static String _byDayCodes(Set<int> weekdays) {
    final sorted = weekdays.toList()..sort();
    return sorted.map((d) => _byDayNames[d]).join(',');
  }
}
