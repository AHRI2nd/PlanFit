import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/clock.dart';

void main() {
  test('emits the current time immediately on first listen', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var emitCount = 0;
      container.listen(nowTickerProvider, (_, next) {
        if (next.hasValue) emitCount++;
      }, fireImmediately: true);
      async.flushMicrotasks();

      expect(emitCount, 1);
    });
  });

  test(
    "disposing the provider container cancels the pending timer instead of "
    'leaving it dangling forever — regression test: an earlier version of '
    'this provider scheduled its next tick via a bare Future.delayed '
    "inside an async* generator, which exposes no handle for anyone to "
    "cancel. Cancelling that stream's subscription stopped the generator "
    'from producing more values, but never stopped the Timer already '
    "ticking down inside that already-created delayed Future — leaving "
    "flutter_test's fake-async zone (and, in the real app, the OS) holding "
    'a live timer with nothing left listening to it, which is exactly what '
    'made every widget test touching this provider fail with "A Timer is '
    'still pending even after the widget tree was disposed" the moment a '
    'second consumer was wired to it',
    () {
      fakeAsync((async) {
        final container = ProviderContainer();
        container.listen(nowTickerProvider, (_, _) {}, fireImmediately: true);
        async.flushMicrotasks();

        expect(
          async.pendingTimers,
          isNotEmpty,
          reason: 'the provider should have scheduled its next tick',
        );

        container.dispose();
        async.flushMicrotasks();

        expect(
          async.pendingTimers,
          isEmpty,
          reason:
              'disposing the container must cancel that pending timer, not '
              'just stop listening to it',
        );
      });
    },
  );
}
