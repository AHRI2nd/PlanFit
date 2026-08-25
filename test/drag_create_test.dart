import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/domain/drag_create.dart';

void main() {
  final dayStart = DateTime(2026, 3, 10);
  const hourHeight = 64.0;

  group('snappedCreateRange', () {
    test('snaps both ends to the nearest 15 minutes', () {
      // 9:07 -> 9:00, 10:53 -> 11:00 (9h*64 = 576px, 10h53m*64/60 ≈ 695.5px).
      final (start, end) = snappedCreateRange(
        dayStart,
        9 * hourHeight + 7 / 60 * hourHeight,
        10 * hourHeight + 53 / 60 * hourHeight,
        hourHeight: hourHeight,
      );
      expect(start, dayStart.add(const Duration(hours: 9)));
      expect(end, dayStart.add(const Duration(hours: 11)));
    });

    test('does not care which end is the anchor — lower Y always wins as '
        'start', () {
      final (start, end) = snappedCreateRange(
        dayStart,
        14 * hourHeight,
        10 * hourHeight,
        hourHeight: hourHeight,
      );
      expect(start, dayStart.add(const Duration(hours: 10)));
      expect(end, dayStart.add(const Duration(hours: 14)));
    });

    test('widens a tap-without-drag up to the minimum duration', () {
      final (start, end) = snappedCreateRange(
        dayStart,
        9 * hourHeight,
        9 * hourHeight,
        hourHeight: hourHeight,
      );
      expect(start, dayStart.add(const Duration(hours: 9)));
      expect(end, dayStart.add(const Duration(hours: 9, minutes: 30)));
    });

    test('widens a too-short drag up to the minimum duration', () {
      final (start, end) = snappedCreateRange(
        dayStart,
        9 * hourHeight,
        9 * hourHeight + 15 / 60 * hourHeight,
        hourHeight: hourHeight,
      );
      expect(start, dayStart.add(const Duration(hours: 9)));
      expect(end, dayStart.add(const Duration(hours: 9, minutes: 30)));
    });

    test('a tap right at the bottom of the day pulls the start back instead '
        'of pushing the end past midnight', () {
      final (start, end) = snappedCreateRange(
        dayStart,
        24 * hourHeight,
        24 * hourHeight,
        hourHeight: hourHeight,
      );
      expect(start, dayStart.add(const Duration(hours: 23, minutes: 30)));
      expect(end, dayStart.add(const Duration(hours: 24)));
    });

    test('clamps negative Y (dragged above the top of the timeline) to '
        'midnight', () {
      final (start, end) = snappedCreateRange(
        dayStart,
        -50,
        2 * hourHeight,
        hourHeight: hourHeight,
      );
      expect(start, dayStart);
      expect(end, dayStart.add(const Duration(hours: 2)));
    });
  });
}
