import 'package:intl/intl.dart';

/// Locale-aware formatting helpers. Pass the active locale tag (e.g. 'ko').
class Fmt {
  const Fmt._();

  /// [use24Hour] `true` forces 24-hour (`DateFormat.Hm`, guaranteed 24h
  /// regardless of locale — see intl's own doc on `Hm`). `false` or `null`
  /// uses the locale's own preferred hour convention (`DateFormat.jm`) — for
  /// this app's supported locales (ko/en) that's already always 12-hour, so
  /// there's no separate "forced 12h" skeleton to reach for.
  static String time(DateTime dt, String locale, {bool? use24Hour}) =>
      (use24Hour == true ? DateFormat.Hm(locale) : DateFormat.jm(locale))
          .format(dt);

  /// Same `use24Hour` contract as [time], for an hour-only label (the
  /// day/week timeline's axis).
  static String hour(int hour24, String locale, {bool? use24Hour}) {
    final dt = DateTime(2000, 1, 1, hour24);
    return (use24Hour == true ? DateFormat.H(locale) : DateFormat.j(locale))
        .format(dt);
  }

  static String weekdayShort(DateTime dt, String locale) =>
      DateFormat.E(locale).format(dt);

  static String monthDay(DateTime dt, String locale) =>
      DateFormat.MMMMd(locale).format(dt);

  static String monthName(DateTime dt, String locale) =>
      DateFormat.MMMM(locale).format(dt);

  static String yearMonth(DateTime dt, String locale) =>
      DateFormat.yMMMM(locale).format(dt);

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
    final ko = locale.startsWith('ko');
    if (diff.isNegative) return ko ? '진행 중' : 'in progress';
    if (diff.inMinutes < 1) return ko ? '곧' : 'now';
    if (diff.inMinutes < 60) {
      return ko ? '${diff.inMinutes}분 뒤' : 'in ${diff.inMinutes}m';
    }
    if (diff.inHours < 24) {
      return ko ? '${diff.inHours}시간 뒤' : 'in ${diff.inHours}h';
    }
    return ko ? '${diff.inDays}일 뒤' : 'in ${diff.inDays}d';
  }
}
