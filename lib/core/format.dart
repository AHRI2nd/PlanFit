import 'package:intl/intl.dart';

/// Locale-aware formatting helpers. Pass the active locale tag (e.g. 'ko').
class Fmt {
  const Fmt._();

  /// [use24Hour] `true` forces 24-hour (`DateFormat.Hm`, guaranteed 24h
  /// regardless of locale — see intl's own doc on `Hm`). `null` uses the
  /// locale's own preferred hour convention (`DateFormat.jm`) as-is — for
  /// ko/en that's already 12-hour, but `ja`'s own convention is 24-hour
  /// (confirmed via intl's CLDR data), so `false` can't just fall through to
  /// the same `jm` call the way it used to before `ja` existed: that would
  /// silently ignore an explicit "12-hour" choice for a Japanese-locale
  /// user. `false` instead goes through [_force12h], which only actually
  /// does anything when the locale's own pattern isn't already 12-hour.
  static String time(DateTime dt, String locale, {bool? use24Hour}) {
    if (use24Hour == true) return DateFormat.Hm(locale).format(dt);
    final format = DateFormat.jm(locale);
    return (use24Hour == false ? _force12h(format, locale) : format).format(
      dt,
    );
  }

  /// Same `use24Hour` contract as [time], for an hour-only label (the
  /// day/week timeline's axis).
  static String hour(int hour24, String locale, {bool? use24Hour}) {
    final dt = DateTime(2000, 1, 1, hour24);
    if (use24Hour == true) return DateFormat.H(locale).format(dt);
    final format = DateFormat.j(locale);
    return (use24Hour == false ? _force12h(format, locale) : format).format(
      dt,
    );
  }

  /// Rewrites [source]'s pattern into 12-hour form for a locale (like `ja`)
  /// whose own natural `jm`/`j` pattern is 24-hour — a no-op for a locale
  /// (ko/en) whose pattern is already 12-hour, since a lowercase `h` is
  /// already present. `H`/`HH` become `h`/`hh` (hour-count preserved), and
  /// if the resulting pattern has no am/pm marker yet (a 24-hour pattern
  /// never has one), `'a '` is prepended — matching the ordering `ko`'s own
  /// native 12-hour pattern already uses (`'a h:mm'`), which intl's CLDR
  /// data confirms every locale checked here agrees with once forced to
  /// 12-hour (verified against `ja` specifically, since that's the one this
  /// exists for).
  static DateFormat _force12h(DateFormat source, String locale) {
    final pattern = source.pattern ?? '';
    // _hasUnquotedChar, not a plain `pattern.contains(...)` — an ICU
    // pattern can single-quote literal text that happens to contain the
    // same letter as a real field. French's own `j` skeleton, for one real
    // example, is `"HH 'h'"` — a genuine 24-hour `HH` field followed by the
    // *word* "heures" abbreviated `'h'`, not a second hour field. A plain
    // substring search there would wrongly conclude the pattern is already
    // 12-hour and leave it unmodified; ko/en/ja (this app's only shipped
    // locales today) happen not to trigger it, but nothing here should
    // depend on that staying true for every locale this might ever run
    // against.
    if (_hasUnquotedChar(pattern, 'h')) return source;
    var forced = pattern.replaceAllMapped(
      RegExp('H+'),
      (m) => 'h' * m[0]!.length,
    );
    if (!_hasUnquotedChar(forced, 'a')) forced = 'a $forced';
    return DateFormat(forced, locale);
  }

  /// Whether [pattern] contains [char] outside of any single-quoted ICU
  /// literal section — see [_force12h]'s own doc for why a plain substring
  /// search isn't safe here. Honors ICU's own escaping rule for a literal
  /// quote character (`''` inside a pattern, not a toggle).
  static bool _hasUnquotedChar(String pattern, String char) {
    var inQuote = false;
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern[i];
      if (c == "'") {
        if (i + 1 < pattern.length && pattern[i + 1] == "'") {
          i++; // an escaped literal quote — not a toggle.
          continue;
        }
        inQuote = !inQuote;
        continue;
      }
      if (!inQuote && c == char) return true;
    }
    return false;
  }

  static String weekdayShort(DateTime dt, String locale) =>
      DateFormat.E(locale).format(dt);

  static String monthDay(DateTime dt, String locale) =>
      DateFormat.MMMMd(locale).format(dt);

  /// [monthDay] with the abbreviated month (`MMM`, not `MMMM`) — for a
  /// context that concatenates two of these into a range, like the week
  /// view's own title. A single [monthDay] rarely runs out of room, but
  /// "August 31 – September 6" is nearly double the length of either half
  /// alone, and did overflow (ellipsized mid-word) in that header; ko/ja
  /// are effectively unaffected since neither has a long-vs-abbreviated
  /// month-name distinction the way en does.
  static String monthDayShort(DateTime dt, String locale) =>
      DateFormat.MMMd(locale).format(dt);

  static String monthName(DateTime dt, String locale) =>
      DateFormat.MMMM(locale).format(dt);

  /// [monthName] abbreviated (`MMM`) — for a context with real width
  /// pressure, like year_view.dart's own mini-month header (12 of these
  /// packed 3-per-row): "September" in en doesn't just look cramped there,
  /// it's tall enough wrapped that it can push the fixed-aspect-ratio grid
  /// cell below it into an actual bottom overflow, not just an ellipsis.
  static String monthNameShort(DateTime dt, String locale) =>
      DateFormat.MMM(locale).format(dt);

  /// schedule_screen.dart's own Month-view title (e.g. "Sep 2026") — uses
  /// the abbreviated month for the same reason [monthDayShort] does: this
  /// sits in that same cramped swipeable-title header the week view's range
  /// overflowed in, and en's full "September 2026" is long enough there to
  /// risk the same thing (this is that title's *only* call site, so the
  /// abbreviation lives directly in `yearMonth` rather than a parallel
  /// `yearMonthShort` nobody else would use).
  static String yearMonth(DateTime dt, String locale) =>
      DateFormat.yMMM(locale).format(dt);

  /// Uses the `yMMMEd` ICU skeleton rather than the fully-spelled-out
  /// `yMMMMEEEEd` — the abbreviated weekday keeps this to one line in the
  /// day header (e.g. ko "2026년 8월 28일 (금)", en "Fri, Aug 28, 2026"),
  /// where full weekday names like "금요일"/"Friday" used to wrap.
  static String fullDate(DateTime dt, String locale) =>
      DateFormat.yMMMEd(locale).format(dt);

  /// A compact relative label like "3시간 뒤" / "in 3h" for upcoming events —
  /// or, if [target] (the event's own start time) is already in the past,
  /// "진행 중" / "in progress". [watchUpcoming]'s query only filters by
  /// `startAt` at the moment it runs, so a card built from its stream keeps
  /// showing an event whose start has since ticked past `now` without the
  /// row itself changing — this is what actually turns "곧"/"now" into a
  /// stale, indefinitely-wrong label for it instead of just a brief flash.
  static String relative(DateTime target, DateTime now, String locale) {
    final diff = target.difference(now);
    if (locale.startsWith('ko')) {
      if (diff.isNegative) return '진행 중';
      if (diff.inMinutes < 1) return '곧';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 뒤';
      if (diff.inHours < 24) return '${diff.inHours}시간 뒤';
      return '${diff.inDays}일 뒤';
    }
    if (locale.startsWith('ja')) {
      if (diff.isNegative) return '進行中';
      if (diff.inMinutes < 1) return 'まもなく';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分後';
      if (diff.inHours < 24) return '${diff.inHours}時間後';
      return '${diff.inDays}日後';
    }
    if (diff.isNegative) return 'in progress';
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return 'in ${diff.inDays}d';
  }
}
