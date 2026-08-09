import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/home_widget/home_widget_sync.dart';

void main() {
  group('HomeWidgetSync.scheduleUri / parseScheduleDate', () {
    test('round-trips a date through the deep link uri', () {
      final day = DateTime(2026, 8, 1);
      final uri = HomeWidgetSync.scheduleUri(day);
      expect(HomeWidgetSync.parseScheduleDate(uri), day);
    });

    test('pads single-digit month and day', () {
      final uri = HomeWidgetSync.scheduleUri(DateTime(2026, 3, 5));
      expect(uri.toString(), 'planfit://schedule?date=2026-03-05');
    });

    test('parseScheduleDate rejects null, wrong scheme, and wrong host', () {
      expect(HomeWidgetSync.parseScheduleDate(null), isNull);
      expect(
        HomeWidgetSync.parseScheduleDate(Uri.parse('https://schedule?date=2026-08-01')),
        isNull,
      );
      expect(
        HomeWidgetSync.parseScheduleDate(Uri.parse('planfit://home')),
        isNull,
      );
    });
  });
}
