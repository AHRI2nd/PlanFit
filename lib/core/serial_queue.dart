/// Runs async tasks one at a time, in call order — a task queued while a
/// previous one is still running waits for it to fully finish before its own
/// body even starts, instead of running concurrently and interleaving side
/// effects with it.
///
/// Exists for call sites where a task is many sequential `await`s long (e.g.
/// writing a dozen `SharedPreferences` keys) and two overlapping callers
/// would otherwise be able to interleave step-by-step: caller A's step 3
/// landing after caller B's step 3 for the same underlying key, even though
/// B started after A and should always win. Serializing removes any
/// possibility of that ordering — B's task literally doesn't begin until
/// A's has completed.
class SerialQueue {
  Future<void> _tail = Future<void>.value();

  /// Queues [task], returning a future that completes with its result once
  /// every task queued before it (if any) has finished. A failed task
  /// doesn't block tasks queued after it — only ordering is serialized, not
  /// success.
  Future<T> run<T>(Future<T> Function() task) {
    // `.catchError` on the *previous* link neutralizes an earlier task's
    // failure before chaining this one — a bare `.then` would otherwise
    // propagate that failure and skip every task queued after it, instead
    // of just this queue's ordering guarantee.
    final result = _tail.catchError((_) {}).then((_) => task());
    // Deliberately `.then(onValue, onError:)` rather than `.catchError` here:
    // `result`'s type is the caller's generic T, and `catchError`'s handler
    // must return a value assignable to that same T (impossible to satisfy
    // generically with a bare `{}`) — `.then` lets the discarded-value
    // continuation's own return type (`void`) drive inference instead,
    // independent of T.
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }
}
