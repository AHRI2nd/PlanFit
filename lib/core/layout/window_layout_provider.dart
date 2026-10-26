import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'window_layout_snapshot.dart';

const _windowLayoutChannel = EventChannel('com.arisair.planfit/window_layout');

final windowLayoutProvider = StreamProvider<WindowLayoutSnapshot?>((ref) {
  if (defaultTargetPlatform != TargetPlatform.iOS) return Stream.value(null);
  return _windowLayoutChannel.receiveBroadcastStream().map((event) {
    if (event is! Map<Object?, Object?> || event['version'] != 1) return null;
    return WindowLayoutSnapshot.fromMap(event);
  });
});
