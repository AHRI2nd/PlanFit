import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/lunar/lunar_date.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/widgets/adaptive_bottom_sheet.dart';
import '../../../../l10n/app_localizations.dart';

/// The lunar-year range this picker offers by default — narrower than
/// klc's own 1391-2050 table (see [LunarDate]'s doc) since a personal
/// calendar app's only realistic uses for a lunar-date *input* are
/// birthdays/anniversaries within a lifetime and near-future planning, not
/// historical dates. Wide enough to cover any living person's birth year
/// with room to spare. [_LunarDatePickerSheetState] widens this on its own,
/// per instance, if [showLunarDatePicker]'s own clamp ever hands it a year
/// outside this default window — see its `_effectiveMinYear`.
const int _minLunarYear = 1920;
const int _maxLunarYear = 2050;

/// klc's own supported solar range (see [LunarDate]'s doc) — the exact
/// bounds [showLunarDatePicker] clamps an out-of-range [initialDate] into,
/// rather than falling back to today's date (which could be wildly
/// unrelated to whatever the user was actually configuring) or, past 2050,
/// crashing outright once `DateTime.now()` itself stops converting.
final DateTime _klcSolarMin = DateTime(1391, 2, 5);
final DateTime _klcSolarMax = DateTime(2050, 12, 31);

/// Opens a wheel picker for a lunar-calendar date and resolves it to the
/// matching solar [DateTime] — mirrors [showDatePicker]'s own
/// `Future<DateTime?>` contract (null on cancel) so call sites can swap
/// between the two with no other change needed. [initialDate] seeds the
/// wheels from whatever lunar date it converts to; a date outside
/// [LunarDate]'s supported range is clamped to the nearest end of that
/// range first (this app's own native date picker allows solar dates up to
/// year 2100, well past klc's 2050 ceiling — reachable today, not just a
/// theoretical future concern, and the clamp is guaranteed to itself
/// convert since it sits exactly on klc's own documented bounds).
Future<DateTime?> showLunarDatePicker({
  required BuildContext context,
  required DateTime initialDate,
}) {
  // Date-only comparison — LunarDate.fromSolar only ever reads
  // initialDate's year/month/day (klc's own conversion has no notion of
  // time-of-day), so a nonzero time on the boundary day itself (e.g.
  // 2050-12-31 23:00) must not clamp down a whole day early.
  final date = DateTime(initialDate.year, initialDate.month, initialDate.day);
  final clamped = date.isBefore(_klcSolarMin)
      ? _klcSolarMin
      : (date.isAfter(_klcSolarMax) ? _klcSolarMax : date);
  final initialLunar = LunarDate.fromSolar(clamped)!;
  return showAdaptiveBottomSheet<DateTime>(
    context: context,
    builder: (_) => _LunarDatePickerSheet(initial: initialLunar),
  );
}

class _LunarDatePickerSheet extends StatefulWidget {
  const _LunarDatePickerSheet({required this.initial});

  final LunarDate initial;

  @override
  State<_LunarDatePickerSheet> createState() => _LunarDatePickerSheetState();
}

class _LunarDatePickerSheetState extends State<_LunarDatePickerSheet> {
  late int _year = widget.initial.year;
  late int _month = widget.initial.month;
  late int _day = widget.initial.day;
  late bool _isLeap = widget.initial.isLeapMonth;

  /// [_minLunarYear]/[_maxLunarYear] widened, if needed, to actually
  /// include [widget.initial]'s own year — that default window covers any
  /// living person's birthday, but `showLunarDatePicker`'s own clamp (for a
  /// solar [DateTime] so far outside klc's range that even *that* clamp's
  /// result still falls outside this picker's usual window — e.g. an event
  /// date picked via the native picker's own much wider year range) can
  /// still hand this a year the default window doesn't cover. Without this,
  /// [_yearController]'s `initialItem` could go negative (below
  /// [_minLunarYear]) or past the wheel's last item (above
  /// [_maxLunarYear]), silently landing on the wrong year — or throwing —
  /// rather than showing the actual (already-clamped-to-klc's-real-range)
  /// date the sheet was opened with.
  late final int _effectiveMinYear = _minLunarYear < widget.initial.year
      ? _minLunarYear
      : widget.initial.year;
  late final int _effectiveMaxYear = _maxLunarYear > widget.initial.year
      ? _maxLunarYear
      : widget.initial.year;

  late final _yearController = FixedExtentScrollController(
    initialItem: _year - _effectiveMinYear,
  );
  late final _monthController = FixedExtentScrollController(
    initialItem: _month - 1,
  );
  late final _dayController = FixedExtentScrollController(initialItem: _day - 1);

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  int? get _leapMonthThisYear => LunarDate.leapMonthOf(_year);

  int get _dayCount =>
      LunarDate.daysInMonth(_year, _month, _isLeap) ??
      // Only reachable for one frame between _isLeap/_month changing and
      // the day wheel's own jump below correcting _day back into range —
      // never actually shown to the user, just keeps the day wheel's
      // itemCount from going negative in that instant.
      29;

  /// Keeps [_day] (and the wheel showing it) inside whatever range the
  /// current (year, month, isLeap) actually has — called after any of those
  /// three change, since a day valid in a 30-day month may not exist once
  /// the selection moves to a 29-day one.
  void _clampDay() {
    final count = _dayCount;
    if (_day <= count) return;
    _day = count;
    _dayController.jumpToItem(_day - 1);
  }

  int get _monthCount => LunarDate.monthsInYear(_year);

  /// Same reasoning as [_clampDay], one level up: the year wheel can land
  /// on a year (currently only 2050, klc's upper boundary) that doesn't
  /// have a full 12 months — without this, a month selection from a prior,
  /// normal year could persist past the year wheel scrolling into that
  /// truncated year, leaving _month pointing at a month the year wheel no
  /// longer even offers.
  void _clampMonth() {
    final count = _monthCount;
    if (_month <= count) return;
    _month = count;
    _monthController.jumpToItem(_month - 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final leapMonth = _leapMonthThisYear;
    final leapAvailable = leapMonth == _month;

    Widget wheel({
      required FixedExtentScrollController controller,
      required int itemCount,
      required String Function(int index) labelFor,
      required ValueChanged<int> onChanged,
      required String semanticsLabel,
      required String semanticsValue,
      required VoidCallback? onIncrease,
      required VoidCallback? onDecrease,
      // Semantics requires these alongside onIncrease/onDecrease whenever
      // `value` is also set (see Semantics.increasedValue's own doc: "If a
      // value is set, increasedValue must also be provided and onIncrease
      // must ensure that value will be set to increasedValue") — null
      // exactly when the matching action itself is null, since the
      // assertion only fires while that action is actually registered.
      required String? increasedValue,
      required String? decreasedValue,
    }) {
      return Expanded(
        child: Semantics(
          label: semanticsLabel,
          value: semanticsValue,
          increasedValue: increasedValue,
          decreasedValue: decreasedValue,
          // Same reasoning as _MonthSplitHandle's own onIncrease/onDecrease:
          // CupertinoPicker's raw drag gesture isn't itself screen-reader-
          // operable, so these are what let a screen reader user reach and
          // operate this wheel at all.
          onIncrease: onIncrease,
          onDecrease: onDecrease,
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 36,
            onSelectedItemChanged: onChanged,
            children: [
              for (var i = 0; i < itemCount; i++)
                Center(child: Text(labelFor(i))),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        top: AppSpacing.sm,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            AppSpacing.lg +
            kFloatingNavBarClearance,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.lunarDatePickerTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                wheel(
                  controller: _yearController,
                  itemCount: _effectiveMaxYear - _effectiveMinYear + 1,
                  labelFor: (i) => '${_effectiveMinYear + i}',
                  onChanged: (i) => setState(() {
                    _year = _effectiveMinYear + i;
                    // Same reasoning as the month wheel's own reset below —
                    // a leap-month selection doesn't carry over to a
                    // different *year* that doesn't share the same leap
                    // month either, and this wheel can change that just as
                    // easily as the month one can.
                    if (_leapMonthThisYear != _month) _isLeap = false;
                    _clampMonth();
                    _clampDay();
                  }),
                  semanticsLabel: l10n.lunarDatePickerYear,
                  semanticsValue: '$_year',
                  increasedValue: _year >= _effectiveMaxYear
                      ? null
                      : '${_year + 1}',
                  decreasedValue: _year <= _effectiveMinYear
                      ? null
                      : '${_year - 1}',
                  onIncrease: _year >= _effectiveMaxYear
                      ? null
                      : () => setState(() {
                          _year++;
                          if (_leapMonthThisYear != _month) _isLeap = false;
                          _clampMonth();
                          _clampDay();
                          // onSelectedItemChanged only fires from the
                          // wheel's own scroll gesture, which this bypasses
                          // entirely — without an explicit jump the wheel
                          // would keep showing the old year even though
                          // _year (and everything derived from it) has
                          // already moved on. Same reasoning _clampDay/
                          // _clampMonth already rely on for their own jumps.
                          _yearController.jumpToItem(
                            _year - _effectiveMinYear,
                          );
                        }),
                  onDecrease: _year <= _effectiveMinYear
                      ? null
                      : () => setState(() {
                          _year--;
                          if (_leapMonthThisYear != _month) _isLeap = false;
                          _clampMonth();
                          _clampDay();
                          _yearController.jumpToItem(
                            _year - _effectiveMinYear,
                          );
                        }),
                ),
                wheel(
                  controller: _monthController,
                  itemCount: _monthCount,
                  labelFor: (i) => '${i + 1}',
                  onChanged: (i) => setState(() {
                    _month = i + 1;
                    // A leap-month selection doesn't carry over to a
                    // different month that isn't itself a leap month —
                    // silently keeping it on would mean the toggle below
                    // shows disabled-but-still-on, an inconsistent state.
                    if (_leapMonthThisYear != _month) _isLeap = false;
                    _clampDay();
                  }),
                  semanticsLabel: l10n.lunarDatePickerMonth,
                  semanticsValue: '$_month',
                  increasedValue: _month >= _monthCount
                      ? null
                      : '${_month + 1}',
                  decreasedValue: _month <= 1 ? null : '${_month - 1}',
                  onIncrease: _month >= _monthCount
                      ? null
                      : () => setState(() {
                          _month++;
                          if (_leapMonthThisYear != _month) _isLeap = false;
                          _clampDay();
                          _monthController.jumpToItem(_month - 1);
                        }),
                  onDecrease: _month <= 1
                      ? null
                      : () => setState(() {
                          _month--;
                          if (_leapMonthThisYear != _month) _isLeap = false;
                          _clampDay();
                          _monthController.jumpToItem(_month - 1);
                        }),
                ),
                wheel(
                  controller: _dayController,
                  itemCount: _dayCount,
                  labelFor: (i) => '${i + 1}',
                  onChanged: (i) => setState(() => _day = i + 1),
                  semanticsLabel: l10n.lunarDatePickerDay,
                  semanticsValue: '$_day',
                  increasedValue: _day >= _dayCount ? null : '${_day + 1}',
                  decreasedValue: _day <= 1 ? null : '${_day - 1}',
                  onIncrease: _day >= _dayCount
                      ? null
                      : () => setState(() {
                          _day++;
                          _dayController.jumpToItem(_day - 1);
                        }),
                  onDecrease: _day <= 1
                      ? null
                      : () => setState(() {
                          _day--;
                          _dayController.jumpToItem(_day - 1);
                        }),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Only enabled when the currently-selected month is actually that
          // year's leap month — see leapMonthOf's own doc. Disabled (not
          // hidden) so its presence itself hints that leap months exist at
          // all, rather than a control that silently vanishes and
          // reappears as the wheels move.
          FilterChip(
            label: Text(l10n.lunarLeapMonthToggle),
            selected: _isLeap,
            onSelected: leapAvailable
                ? (v) => setState(() => _isLeap = v)
                : null,
            selectedColor: palette.accent.withValues(alpha: 0.24),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final solar = LunarDate(
                  year: _year,
                  month: _month,
                  day: _day,
                  isLeapMonth: _isLeap,
                ).toSolar();
                // _dayCount/_clampDay already keep every wheel combination
                // valid, so toSolar() should never actually return null
                // here — falls back to just closing with nothing picked
                // rather than risk propagating a null DateTime the caller
                // isn't expecting from a "confirmed" tap.
                if (solar != null) Navigator.of(context).pop(solar);
              },
              child: Text(l10n.commonDone),
            ),
          ),
        ],
      ),
    );
  }
}
