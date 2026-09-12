import 'package:app_badge_plus/app_badge_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/app_badge/app_badge_sync.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A fake in place of the plugin's real, platform-channel-backed
/// implementation — `MockPlatformInterfaceMixin` is exactly what the
/// federated-plugin pattern documents for this (see
/// `AppBadgePlusPlatform.instance`'s own setter), so `push` can be tested
/// as a plain unit rather than needing a running platform channel.
class _FakeAppBadgePlusPlatform extends AppBadgePlusPlatform
    with MockPlatformInterfaceMixin {
  bool supported = true;
  int? lastUpdatedCount;
  var updateCallCount = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> updateBadge(int count) async {
    updateCallCount++;
    lastUpdatedCount = count;
  }
}

void main() {
  late _FakeAppBadgePlusPlatform platform;

  setUp(() {
    platform = _FakeAppBadgePlusPlatform();
    AppBadgePlusPlatform.instance = platform;
  });

  test('pushes the given count straight through when the platform supports '
      'a badge', () async {
    await AppBadgeSync.push(3);

    expect(platform.updateCallCount, 1);
    expect(platform.lastUpdatedCount, 3);
  });

  test('a count of 0 still reaches updateBadge — that\'s how a badge is '
      'cleared, not treated as "nothing to push"', () async {
    await AppBadgeSync.push(0);

    expect(platform.updateCallCount, 1);
    expect(platform.lastUpdatedCount, 0);
  });

  test('never calls updateBadge on a platform/launcher that can\'t show a '
      'badge at all', () async {
    platform.supported = false;

    await AppBadgeSync.push(5);

    expect(platform.updateCallCount, 0);
  });
}
