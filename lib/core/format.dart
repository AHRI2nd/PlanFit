import 'package:intl/intl.dart';

/// Locale-aware formatting helpers. Pass the active locale tag (e.g. 'ko').
class Fmt {
  const Fmt._();

  static String time(DateTime dt, String locale) =>
      DateFormat.jm(locale).format(dt);

  static String hour(int hour24, String locale) {
    final dt = DateTime(2000, 1, 1, hour24);
    return DateFormat.j(locale).format(dt);
  }

  static String weekdayShort(DateTime dt, String locale) =>
      DateFormat.E(locale).format(dt);

  static String monthDay(DateTime dt, String locale) =>
      DateFormat.MMMMd(locale).format(dt);

  static String monthName(DateTime dt, String locale) =>
      DateFormat.MMMM(locale).format(dt);

  static String yearMonth(DateTime dt, String locale) =>
      DateFormat.yMMMM(locale).format(dt);

  static String fullDate(DateTime dt, String locale) =>
      DateFormat.yMMMMEEEEd(locale).format(dt);

  /// A compact relative label like "3시간 뒤" / "in 3h" for upcoming events.
  static String relative(DateTime target, DateTime now, String locale) {
    final diff = target.difference(now);
    final ko = locale.startsWith('ko');
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
