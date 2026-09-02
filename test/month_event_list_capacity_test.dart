import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';

const _typicalColumnWidth = 52.0;

void main() {
  test(
    'stays at the compact dot/bar summary (capacity 0) at the default row '
    'height, so dragging the split handle taller is what unlocks the list — '
    "it isn't there unasked-for from the start",
    () {
      final capacity = monthEventListCapacity(
        rowHeight: MonthCalendarRowHeight.defaultHeight,
        columnWidth: _typicalColumnWidth,
      );
      expect(capacity, 0);
    },
  );

  test('stays 0 at the shortest allowed row height — no room for a list at '
      'all there', () {
    final capacity = monthEventListCapacity(
      rowHeight: MonthCalendarRowHeight.min,
      columnWidth: _typicalColumnWidth,
    );
    expect(capacity, 0);
  });

  test(
    'unlocks a real list once the row is dragged past the default height '
    'by enough',
    () {
      final capacity = monthEventListCapacity(
        rowHeight: MonthCalendarRowHeight.max,
        columnWidth: _typicalColumnWidth,
      );
      expect(capacity, greaterThan(0));
    },
  );

  test('never returns a negative or unbounded row count', () {
    final capacity = monthEventListCapacity(
      rowHeight: MonthCalendarRowHeight.max,
      columnWidth: _typicalColumnWidth,
    );
    expect(capacity, greaterThanOrEqualTo(0));
    expect(capacity, lessThanOrEqualTo(5));
  });
}
