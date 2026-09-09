import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current time exactly when the wall clock crosses into a new
/// minute — not a fixed interval measured from whenever this provider
/// happened to start — so every minute-resolution, time-driven UI (the home
/// clock, the time-of-day gradient, a day/week timeline's "now" line) stays
/// aligned with the system clock exactly, rather than lagging by up to
/// however long a fixed interval would.
///
/// Anything that `ref.watch`s this rebuilds itself directly through
/// Riverpod's own dependency tracking, independent of whether its widget
/// happens to be the active tab or a backgrounded `IndexedStack` branch
/// (see `todayProvider`'s own doc in schedule_providers.dart for the same
/// reasoning) — so switching away from and back to a tab that watches this
/// always shows the true current time instead of whatever moment that tab's
/// widget last happened to rebuild at for some unrelated reason.
///
/// Built on an explicit [StreamController] + [Timer] (rather than
/// `Stream.periodic`, or an `async*` generator awaiting `Future.delayed`)
/// specifically so cancellation actually stops the pending wait: a plain
/// `Timer` created inside `Future.delayed` has no handle exposed for anyone
/// to cancel, so a stream built that way keeps its underlying `Timer` alive
/// — and flagged as "still pending" by `flutter_test`'s fake-async zone —
/// even after every listener (and the whole widget tree) is gone.
/// `Stream.periodic` doesn't have this problem (cancelling its subscription
/// cancels its `Timer.periodic` directly), but can't align to a wall-clock
/// boundary the way a self-rescheduling `Timer` can.
final nowTickerProvider = StreamProvider<DateTime>((ref) {
  Timer? timer;
  late final StreamController<DateTime> controller;

  void scheduleNext() {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    // A little slack so `DateTime.now()` at the next tick has unambiguously
    // rolled over by the time this fires.
    timer = Timer(nextMinute.difference(now) + const Duration(milliseconds: 50), () {
      controller.add(DateTime.now());
      scheduleNext();
    });
  }

  controller = StreamController<DateTime>(
    onListen: () {
      controller.add(DateTime.now());
      scheduleNext();
    },
    onCancel: () => timer?.cancel(),
  );
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});
