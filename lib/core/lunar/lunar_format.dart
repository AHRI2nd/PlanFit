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
}
