import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/format.dart';

void main() {
  group('Fmt.relative', () {
    final now = DateTime(2026, 1, 1, 12);

    test('an already-started event (target before now) reads as in progress', () {
      expect(
        Fmt.relative(now.subtract(const Duration(minutes: 1)), now, 'ko'),
        '진행 중',
      );
      expect(
        Fmt.relative(now.subtract(const Duration(hours: 2)), now, 'en'),
        'in progress',
      );
    });

    test('starting within the next minute reads as soon/now', () {
      expect(Fmt.relative(now.add(const Duration(seconds: 30)), now, 'ko'), '곧');
      expect(Fmt.relative(now, now, 'en'), 'now');
    });

    test('starting later this hour counts minutes', () {
      expect(
        Fmt.relative(now.add(const Duration(minutes: 45)), now, 'ko'),
        '45분 뒤',
      );
      expect(
        Fmt.relative(now.add(const Duration(minutes: 45)), now, 'en'),
        'in 45m',
      );
    });

    test('starting later today counts hours', () {
      expect(
        Fmt.relative(now.add(const Duration(hours: 5)), now, 'ko'),
        '5시간 뒤',
      );
      expect(
        Fmt.relative(now.add(const Duration(hours: 5)), now, 'en'),
        'in 5h',
      );
    });

    test('starting on a later day counts days', () {
      expect(
        Fmt.relative(now.add(const Duration(days: 3)), now, 'ko'),
        '3일 뒤',
      );
      expect(
        Fmt.relative(now.add(const Duration(days: 3)), now, 'en'),
        'in 3d',
      );
    });
  });
}
