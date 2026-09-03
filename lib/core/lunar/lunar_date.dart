import 'package:klc/klc.dart' as klc;

/// A day in the traditional Korean lunar calendar (음력) — also
/// current-day-accurate as Japan's own lunar calendar (旧暦, "kyūreki"),
/// since both countries' calendar calculations use UTC+9 (135°E) as their
/// reference meridian in the modern era, unlike China's UTC+8, which
/// occasionally shifts a new-moon date or a leap-month's position by a day.
/// A handful of times each century that difference actually shows up in the
/// news; Korea and Japan themselves stay in step. (Historically Korea used
/// other reference meridians before 1961 — irrelevant here, since this app
/// only ever deals with recent/future dates.)
///
/// Wraps `package:klc` — a pure-Dart implementation of the Korea Astronomy
/// and Space Science Institute (KARI)'s official conversion tables, chosen
/// over more generic "lunar calendar" packages specifically because those
/// default to the Chinese calculation and would occasionally disagree with
/// what a Korean or Japanese calendar actually shows for the same day. klc's
/// own public API (`setSolarDate`/`getLunarYear`/...) is a set of top-level
/// functions that mutate shared global state rather than return a value —
/// fine to call synchronously from a single isolate (this app never touches
/// it from more than one, and every call here reads its result back out
/// before any other code gets a chance to run) but wrong to expose directly
/// to call sites that expect an ordinary, side-effect-free value type. This
/// class is that value type — every call site outside this file only ever
/// sees [LunarDate] itself, never klc's own functions.
class LunarDate {
  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    required this.isLeapMonth,
  });

  final int year;
  final int month;
  final int day;

  /// Whether this date falls in a 윤달 (leap/intercalary lunar month) — the
  /// lunar calendar periodically repeats a month number to stay roughly
  /// aligned with the solar year, so a handful of years have two different
  /// months sharing the same number; this tells them apart.
  final bool isLeapMonth;

  /// Converts [solar] to its lunar-calendar equivalent, or `null` if
  /// [solar] falls outside klc's supported range — Gregorian
  /// 1391-02-05 to 2050-12-31 (klc's own `checkValidDate`, verified against
  /// its source since pub.dev's own docs don't state the failure mode).
  /// Every call site treats `null` as "just don't show a lunar date here"
  /// rather than a crash — this app's own date pickers already allow years
  /// beyond 2050 (up to 2100), so this is an expected, not exceptional,
  /// outcome.
  static LunarDate? fromSolar(DateTime solar) {
    final ok = klc.setSolarDate(solar.year, solar.month, solar.day);
    if (!ok) return null;
    final year = klc.getLunarYear();
    final month = klc.getLunarMonth();
    return LunarDate(
      year: year,
      month: month,
      day: klc.getLunarDay(),
      isLeapMonth: _isLeapMonth(solar, year, month),
    );
  }

  /// klc's own top-level `isIntercalation` variable — the obvious place to
  /// read this from — is never actually written by [klc.setSolarDate]:
  /// its `setLunarDateBySolarDate` declares a same-named *local* variable
  /// (`var isIntercalation = false;`) that shadows the package's global one
  /// instead of assigning it, so every read of `klc.isIntercalation` after
  /// a `setSolarDate` call silently returns whatever an earlier
  /// `setLunarDate` call (the *other* direction) last left there — verified
  /// directly against klc 0.1.0's own source, not just its docs, since this
  /// is exactly the kind of bug pub.dev's page gives no hint of. Worked
  /// around here by re-deriving intercalation status from klc's own
  /// lower-level (and correctly-behaving) helpers instead: [month] is only
  /// ever the resolved calendar's leap month if [year]'s lunar data marks
  /// it as one *and* [solar]'s absolute day count falls on/after that leap
  /// month's own start — the same two checks `setLunarDateBySolarDate`
  /// itself does internally, just read back out through its still-public
  /// building blocks rather than its broken top-level flag.
  static bool _isLeapMonth(DateTime solar, int year, int month) {
    final intercalationMonth = klc.getLunarIntercalationMonth(
      klc.getLunarData(year),
    );
    if (intercalationMonth != month) return false;
    final absDays = klc.getSolarAbsDays(solar.year, solar.month, solar.day);
    return absDays >= klc.getLunarAbsDays(year, month, 1, true);
  }

  /// Converts this lunar date to its solar-calendar equivalent, or `null`
  /// if it's out of klc's supported range, or [day] doesn't actually exist
  /// in [month] that year (a lunar month is 29 or 30 days — never 28 or
  /// 31 — and which one varies by year/month, so this isn't knowable from
  /// [day] alone without klc's own table).
  ///
  /// If [isLeapMonth] is `true` but [year]'s [month] was never actually a
  /// leap month, this does **not** return `null` — verified directly
  /// against klc's own source: `setLunarDate` silently normalizes the flag
  /// to `false` and resolves the plain month instead of rejecting the
  /// input. That's convenient rather than a foot-gun for this app's one
  /// caller that matters (a yearly-lunar-anchored recurrence stepping past
  /// a year that lacks the anchor's leap month) — see [RecurrenceExpansion]
  /// — but it does mean a caller that actually needs to *know* whether the
  /// leap month it asked for was honored must compare the *input*
  /// [isLeapMonth] against [fromSolar]'s own re-derived one on the result,
  /// rather than trusting this call to fail loudly.
  DateTime? toSolar() {
    final ok = klc.setLunarDate(year, month, day, isLeapMonth);
    if (!ok) return null;
    return DateTime(
      klc.getSolarYear(),
      klc.getSolarMonth(),
      klc.getSolarDay(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LunarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.isLeapMonth == isLeapMonth;

  @override
  int get hashCode => Object.hash(year, month, day, isLeapMonth);

  @override
  String toString() =>
      'LunarDate($year-$month-$day${isLeapMonth ? " (leap)" : ""})';
}
