import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Initializes the timezone database and pins the local zone to the device's
/// IANA zone. Exact-time notification scheduling needs timezone-aware
/// [tz.TZDateTime]; naive [DateTime] would drift across DST / travel.
class TimezoneSetup {
  const TimezoneSetup._();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // Fall back to UTC if the platform can't report a zone.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  /// Converts a stored instant to a zoned time in the device's local zone.
  static tz.TZDateTime toLocal(DateTime instant) =>
      tz.TZDateTime.from(instant, tz.local);
}
