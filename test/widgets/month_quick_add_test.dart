import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';
import 'package:planfit/features/todo/presentation/quick_add_todo_sheet.dart';
import 'package:planfit/l10n/app_localizations.dart';

/// `MonthView` pins a [QuickAddTodoField] below its day panel and has to
/// reserve that field's height out of the month grid's own row-height
/// budget — the grid is sized from a number, not from what is left over, so
/// anything it doesn't know about simply overflows the Column. Adding the
/// pinned field without teaching `maxMonthRowHeight` about it did exactly
/// that (7px on a 800x600 surface).
///
/// The reserved figure is a measurement of a real widget rather than a
/// guess, so these pin the measurement itself. If the field grows — another
/// control in its row, a larger default font — the constant has to move with
/// it, and this is what says so rather than a phone-shaped overflow stripe.
void main() {
  Future<double> fieldHeight(
    WidgetTester tester, {
    required bool expanded,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ko'),
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                QuickAddTodoField(
                  day: DateTime(2026, 3, 10),
                  forceOptionsExpanded: expanded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byType(QuickAddTodoField)).height;
  }

  testWidgets('the reserved height matches the collapsed field', (
    tester,
  ) async {
    expect(
      await fieldHeight(tester, expanded: false),
      monthPinnedQuickAddHeight,
    );
  });

  testWidgets('opening the field\'s details panel grows it by less than the '
      "day panel's own floor, so the month Column cannot overflow even at "
      'the calendar\'s tallest allowed row height', (tester) async {
    final collapsed = await fieldHeight(tester, expanded: false);
    final expanded = await fieldHeight(tester, expanded: true);

    expect(
      expanded - collapsed,
      lessThan(monthMinDayViewHeight),
      reason:
          'only the collapsed height is reserved; the panel opening borrows '
          'the difference from the day view below it',
    );
  });

  test('the row-height budget shrinks by whatever is pinned below it', () {
    // 600 puts both results inside MonthCalendarRowHeight's [44, 96] clamp
    // (76 and 56), which the arithmetic below needs: too tall and both pin
    // to max, too short and both pin to min — either way the reservation
    // stops being observable and the test would pass on a no-op.
    const rows = 6;
    final without = maxMonthRowHeight(availableHeight: 600, rowCount: rows);
    final with_ = maxMonthRowHeight(
      availableHeight: 600,
      rowCount: rows,
      reservedBelow: 120,
    );
    expect(with_, lessThan(without));
    expect(without - with_, closeTo(120 / rows, 0.001));
  });
}
