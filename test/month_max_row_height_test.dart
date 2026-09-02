import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';

void main() {
  test('a generous viewport allows rows up to the static ceiling, not just '
      'whatever a naive division would give', () {
    final maxHeight = maxMonthRowHeight(availableHeight: 2000, rowCount: 5);
    expect(maxHeight, MonthCalendarRowHeight.max);
  });

  test('a tight viewport caps rows well below the static ceiling, leaving '
      'room for the dow row, the handle, and the day view below', () {
    final maxHeight = maxMonthRowHeight(availableHeight: 500, rowCount: 6);
    expect(maxHeight, lessThan(MonthCalendarRowHeight.max));
    expect(maxHeight, greaterThanOrEqualTo(MonthCalendarRowHeight.min));
  });

  test('an impossibly short viewport never returns less than the static '
      'floor, rather than a negative or zero row height', () {
    final maxHeight = maxMonthRowHeight(availableHeight: 50, rowCount: 6);
    expect(maxHeight, MonthCalendarRowHeight.min);
  });

  test('rowCount <= 0 falls back to the floor instead of dividing by zero', () {
    final maxHeight = maxMonthRowHeight(availableHeight: 2000, rowCount: 0);
    expect(maxHeight, MonthCalendarRowHeight.min);
  });
}
