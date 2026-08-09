import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current time every 30 seconds so time-driven UI (the home clock,
/// the gradient, the "now" line) stays live without a manual refresh.
final nowTickerProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now(),
  );
});
