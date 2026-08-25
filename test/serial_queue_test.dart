import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/serial_queue.dart';

void main() {
  test(
    'a slower first task fully finishes before a faster second task starts '
    '— proves tasks never interleave',
    () async {
      final queue = SerialQueue();
      final log = <String>[];

      // Deliberately not awaited between the two calls — this is the shape
      // SettingsController._persist relies on: two callers firing in quick
      // succession, the second racing ahead of the first's real I/O.
      final first = queue.run(() async {
        log.add('first-start');
        // A real delay (not just a microtask hop) — without SerialQueue,
        // 'second-start'/'second-end' would land here, before 'first-end',
        // since nothing would stop the second task's synchronous body from
        // running while the first is still awaiting.
        await Future.delayed(const Duration(milliseconds: 30));
        log.add('first-end');
      });
      final second = queue.run(() async {
        log.add('second-start');
        log.add('second-end');
      });

      await first;
      await second;

      expect(log, ['first-start', 'first-end', 'second-start', 'second-end']);
    },
  );

  test('a task queued after the previous one finished runs immediately', () async {
    final queue = SerialQueue();
    final log = <String>[];

    await queue.run(() async => log.add('a'));
    await queue.run(() async => log.add('b'));

    expect(log, ['a', 'b']);
  });

  test('run returns the task\'s own result', () async {
    final queue = SerialQueue();
    final result = await queue.run(() async => 42);
    expect(result, 42);
  });

  test(
    'a failed task does not block tasks queued after it, and its failure '
    'surfaces only to its own caller',
    () async {
      final queue = SerialQueue();
      final log = <String>[];

      final failing = queue.run(() async {
        log.add('failing-ran');
        throw StateError('boom');
      });
      final after = queue.run(() async => log.add('after-ran'));

      await expectLater(failing, throwsA(isA<StateError>()));
      await after;

      expect(log, ['failing-ran', 'after-ran']);
    },
  );
}
