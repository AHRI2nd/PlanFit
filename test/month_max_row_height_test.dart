import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';

void main() {
  Future<double> maxRowHeightIn(
    WidgetTester tester, {
    required double availableHeight,
    required int rowCount,
  }) async {
    late double result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        result = maxMonthRowHeight(
          availableHeight: availableHeight,
          rowCount: rowCount,
          context: context,
        );
        return const SizedBox();
      }),
    ));
    return result;
  }

  testWidgets(
      'a generous viewport allows rows up to the static ceiling, not just '
      'whatever a naive division would give', (tester) async {
    final maxHeight =
        await maxRowHeightIn(tester, availableHeight: 2000, rowCount: 5);
    expect(maxHeight, MonthCalendarRowHeight.max);
  });

  testWidgets(
      'a tight viewport caps rows well below the static ceiling, leaving '
      'room for the header/dow row, the handle, and the day view below',
      (tester) async {
    final maxHeight =
        await maxRowHeightIn(tester, availableHeight: 500, rowCount: 6);
    expect(maxHeight, lessThan(MonthCalendarRowHeight.max));
    expect(maxHeight, greaterThanOrEqualTo(MonthCalendarRowHeight.min));
  });

  testWidgets(
      'an impossibly short viewport never returns less than the static '
      'floor, rather than a negative or zero row height', (tester) async {
    final maxHeight =
        await maxRowHeightIn(tester, availableHeight: 50, rowCount: 6);
    expect(maxHeight, MonthCalendarRowHeight.min);
  });

  testWidgets('rowCount <= 0 falls back to the floor instead of dividing '
      'by zero', (tester) async {
    final maxHeight =
        await maxRowHeightIn(tester, availableHeight: 2000, rowCount: 0);
    expect(maxHeight, MonthCalendarRowHeight.min);
  });
}
