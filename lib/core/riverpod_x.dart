import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a day/week/month/year/agenda/tag data provider stays subscribed
/// after its last listener drops — see [KeepAliveForX.keepAliveFor]. Long
/// enough to cover a quick swipe-forward-then-back; short enough that a long
/// session paging through many days doesn't leave them all open forever the
/// way a plain (non-`autoDispose`) `.family` provider would.
const kDataProviderCacheGrace = Duration(minutes: 5);

/// Keeps an `autoDispose` provider's subscription alive for [duration] after
/// its last listener drops, instead of tearing down (and, on the next watch,
/// reconnecting and re-querying from scratch) the instant it does.
///
/// Meant for the date/id-keyed `.family` providers behind the day/week/
/// month/year/agenda views: paging away from a day and straight back to it
/// a moment later should find its data still warm, not flash back to
/// "loading" — but a plain non-`autoDispose` `.family` provider never lets
/// go of anything it's ever built, so a long session paging through many
/// distinct days/weeks/months leaves every one of them subscribed to its own
/// live Drift `.watch()` stream forever. `keepAliveFor` bounds that: idle
/// past [duration] with nobody watching, and the subscription actually
/// closes.
///
/// The standard Riverpod "automatically dispose after a delay" recipe —
/// [Ref.keepAlive] pins the provider open past its normal auto-dispose
/// point, and the returned [KeepAliveLink] is only closed once [duration]
/// elapses with no listener re-attaching in the meantime.
extension KeepAliveForX on Ref {
  void keepAliveFor(Duration duration) {
    final link = keepAlive();
    Timer? timer;
    onDispose(() => timer?.cancel());
    onCancel(() => timer = Timer(duration, link.close));
    onResume(() => timer?.cancel());
  }
}
