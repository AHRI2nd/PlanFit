import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/design/widgets/multi_chip_row.dart';

/// Regression test: [MultiChipRow]'s `for (final value in options)` loop had
/// no `key`, so a caller whose `options` list changes membership at a fixed
/// length/order (e.g. the event editor's additional-reminders picker, which
/// excludes whichever value is currently the primary reminder) reused each
/// slot's `ChoiceChip`/`RawChip` Element across the rebuild instead of
/// treating a changed value as a genuinely different chip — leaving
/// `RawChip`'s own selection-fade `AnimationController` to keep animating
/// from the *previous* slot occupant's selected state.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<int> options,
    required Set<int> selected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MultiChipRow<int>(
            label: 'Reminders',
            options: options,
            selected: selected,
            labelFor: (v) => '$v',
            accent: Colors.blue,
            onChanged: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    "a chip's RawChip Element isn't reused for a different value at the "
    'same slot, so its selection animation never starts from the wrong '
    'state',
    (tester) async {
      await pump(tester, options: const [0, 5, 30, 60, 1440], selected: {30});
      await tester.pumpAndSettle();
      final before = tester.state(find.byType(RawChip).at(2));

      // Slot 2 held "30" (selected); now it holds "10" (not selected) — the
      // same shape as the event editor swapping which value the primary
      // reminder excludes.
      await pump(tester, options: const [0, 5, 10, 60, 1440], selected: {});
      await tester.pump();
      final after = tester.state(find.byType(RawChip).at(2));

      expect(
        identical(before, after),
        isFalse,
        reason:
            'slot 2 now represents a different logical chip ("10" instead '
            'of "30") — reusing the same Element/State lets its old '
            'selection animation bleed into the new value',
      );
    },
  );
}
