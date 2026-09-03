import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/lunar/lunar_date.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/widgets/adaptive_bottom_sheet.dart';
import '../../../../l10n/app_localizations.dart';

/// The lunar-year range this picker offers — narrower than klc's own
/// 1391-2050 table (see [LunarDate]'s doc) since a personal calendar app's
/// only realistic uses for a lunar-date *input* are birthdays/anniversaries
/// within a lifetime and near-future planning, not historical dates. Wide
/// enough to cover any living person's birth year with room to spare.
const int _minLunarYear = 1920;
const int _maxLunarYear = 2050;

/// Opens a wheel picker for a lunar-calendar date and resolves it to the
/// matching solar [DateTime] — mirrors [showDatePicker]'s own
/// `Future<DateTime?>` contract (null on cancel) so call sites can swap
/// between the two with no other change needed. [initialDate] seeds the
/// wheels from whatever lunar date it converts to (today's, if it's outside
/// [LunarDate]'s supported range).
Future<DateTime?> showLunarDatePicker({
  required BuildContext context,
  required DateTime initialDate,
}) {
  final initialLunar =
      LunarDate.fromSolar(initialDate) ?? LunarDate.fromSolar(DateTime.now())!;
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

  late final _yearController = FixedExtentScrollController(
    initialItem: _year - _minLunarYear,
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
    }) {
      return Expanded(
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: 36,
          onSelectedItemChanged: onChanged,
          children: [
            for (var i = 0; i < itemCount; i++)
              Center(child: Text(labelFor(i))),
          ],
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
                  itemCount: _maxLunarYear - _minLunarYear + 1,
                  labelFor: (i) => '${_minLunarYear + i}',
                  onChanged: (i) => setState(() {
                    _year = _minLunarYear + i;
                    _clampDay();
                  }),
                ),
                wheel(
                  controller: _monthController,
                  itemCount: 12,
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
                ),
                wheel(
                  controller: _dayController,
                  itemCount: _dayCount,
                  labelFor: (i) => '${i + 1}',
                  onChanged: (i) => setState(() => _day = i + 1),
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
