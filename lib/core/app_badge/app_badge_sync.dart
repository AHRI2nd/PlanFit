import 'package:app_badge_plus/app_badge_plus.dart';

/// Mirrors the schedule tab's in-app badge (see
/// `features/shell/app_shell.dart`) onto the HomeScreen app icon itself —
/// today's undone to-do count, or nothing when the launcher/platform can't
/// show one. `isSupported()` covers that gate; count `0` clears the badge.
class AppBadgeSync {
  const AppBadgeSync._();

  static Future<void> push(int count) async {
    if (!await AppBadgePlus.isSupported()) return;
    await AppBadgePlus.updateBadge(count);
  }
}
