import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';

void main() {
  group('monthRowCount', () {
    test('matches table_calendar\'s own row count for a 6-row month '
        '(August 2026), regardless of week-start day', () {
      expect(monthRowCount(DateTime(2026, 8, 15), DateTime.monday), 6);
      expect(monthRowCount(DateTime(2026, 8, 15), DateTime.sunday), 6);
    });

    test('a Sunday-start week can need one fewer row than a Monday-start '
        'week for the same month (February 2026)', () {
      expect(monthRowCount(DateTime(2026, 2, 10), DateTime.monday), 5);
      expect(monthRowCount(DateTime(2026, 2, 10), DateTime.sunday), 4);
    });

    test('a plain 5-row month (January 2026, Monday-start)', () {
      expect(monthRowCount(DateTime(2026, 1, 10), DateTime.monday), 5);
    });
  });
}
