import '../../l10n/app_localizations.dart';
import 'lunar_date.dart';

/// Formats a [LunarDate] into the short label shown next to a solar date —
/// "음력 7월 22일" / "Lunar 7/22" / "旧暦 7月22日", or the leap-month variant
/// when [LunarDate.isLeapMonth] is set. Unlike `Fmt` (which takes a raw
/// locale string and hand-rolls its own ko/en branches), this takes the
/// generated [AppL10n] directly — every call site already has a
/// `BuildContext` to get one from (this is display-only UI text, not the
/// background-isolate-reachable strings `notification_service.dart` needs
/// `lookupAppL10n` for), so there's no reason to re-derive locale-branching
/// logic this app's own l10n keys already carry.
class LunarFmt {
  const LunarFmt._();

  static String short(AppL10n l10n, LunarDate date) => date.isLeapMonth
      ? l10n.lunarDateLabelLeap(date.month, date.day)
      : l10n.lunarDateLabel(date.month, date.day);

  /// A much shorter form for repeated per-cell use (a week header's 7
  /// columns, a month grid's ~35-42 cells) — [short]'s spelled-out "음력
  /// 7월 22일"/"Lunar 7/22"/"旧暦 7月22日" reads well once per screen (the
  /// schedule title) but would be overwhelming repeated that many times, so
  /// this drops the "음력"/"Lunar"/"旧暦" word entirely (the screen already
  /// has exactly one of those, in the title or the settings toggle that
  /// turns this on) and keeps only digits plus, for a leap month, a single
  /// short marker character ahead of them ("윤7.22"/"L7/22"/"閏7.22").
  static String compact(AppL10n l10n, LunarDate date) {
    final digits = l10n.lunarDateCompact(date.month, date.day);
    return date.isLeapMonth ? '${l10n.lunarLeapMarker}$digits' : digits;
  }

  /// [compact], but the month number only appears on the 1st of the lunar
  /// month ("8.1", leap "윤8.1") — every other day shows just its own day
  /// number ("24", "2"), still carrying the leap marker alone when [date]
  /// falls in a leap month ("윤15") so it doesn't read identically to the
  /// same day number in the regular month that follows. For month_view.dart's
  /// grid, where [compact] repeated on every single cell (~35-42 per
  /// screen) read as far more cluttered than a solar month grid needs —
  /// which month a run of days belongs to is already clear from whichever
  /// cell nearest above it last spelled it out.
  static String cell(AppL10n l10n, LunarDate date) {
    if (date.day == 1) return compact(l10n, date);
    return date.isLeapMonth ? '${l10n.lunarLeapMarker}${date.day}' : '${date.day}';
  }
}
