import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../design/tokens/app_colors.dart';
import '../../design/tokens/event_color_tag.dart';
import '../backup/ics_parser.dart';
import '../db/app_database.dart';
import '../db/daos/event_dao.dart';
import '../db/sync_status.dart';

/// Prefix for [Events.importSourceCalendarId] on a holiday-imported row —
/// distinguishes it from a device-calendar mirror (see
/// [CalendarImportService], which tags rows with the OS calendar's own id
/// instead) while still tripping the exact same "read-only, can't be
/// edited/deleted" check `showEventEditor` already runs on any non-null
/// `importSourceCalendarId` — no new UI-layer code needed for that part.
String holidayImportSourceId(String localeCode) => 'holiday:$localeCode';

/// Keeps a locale-appropriate national holiday calendar mirrored into
/// PlanFit automatically — the user never provides a URL or picks a
/// calendar; the app decides which public feed to trust and keeps it in
/// sync on its own, the same way [CalendarImportService] mirrors a
/// subscribed device calendar. Deliberately reuses that service's own
/// pattern (bypass [EventRepository.save], write rows straight through
/// [EventDao] as already-[SyncStatus.synced] with no `osEventId`, matched
/// on `(importSourceCalendarId, importSourceEventId)` across re-syncs
/// rather than a derived id) for the same reason: a holiday row must never
/// be editable, and must never get pushed back out to the device calendar.
///
/// The source itself is a public `.ics` feed Google publishes and
/// maintains for national holidays — plain `https://` GET, no API key, no
/// billing account, no rate limit that matters at this scale (see the
/// session's own cost research before this was scoped this way rather than
/// as a full Places/Maps-style integration).
class HolidayCalendarService {
  HolidayCalendarService({required this.eventDao, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final EventDao eventDao;
  final http.Client _http;

  static const _uuid = Uuid();

  /// Google's own calendar id for each locale's official public holidays —
  /// add an entry here to support a new locale; anything else falls back
  /// to the `en` feed. (Not user-configurable — see this class's own doc.)
  static const Map<String, String> _calendarIds = {
    'ko': 'en.south_korea.official#holiday@group.v.calendar.google.com',
    'en': 'en.usa.official#holiday@group.v.calendar.google.com',
  };

  static final String _holidayColorHex = EventColorTag.toHex(
    AppColors.holidayRed,
  );

  Uri _feedUrl(String localeCode) {
    final calendarId = _calendarIds[localeCode] ?? _calendarIds['en']!;
    return Uri.https(
      'calendar.google.com',
      '/calendar/ical/${Uri.encodeComponent(calendarId)}/public/basic.ics',
    );
  }

  /// Fetches [localeCode]'s holiday feed and upserts every VEVENT as a
  /// read-only mirror row, removing any previously-mirrored holiday that's
  /// no longer in the feed (a corrected/removed observance). Matched by
  /// [IcsVevent.uid] — see that class's doc on why a UID-less VEVENT still
  /// gets a stable synthesized one, which is what makes a plain re-fetch of
  /// an unchanged feed update rows in place instead of duplicating them.
  Future<void> sync(String localeCode) async {
    final sourceId = holidayImportSourceId(localeCode);
    final response = await _http.get(_feedUrl(localeCode));
    if (response.statusCode != 200) {
      return; // best-effort; try again next resume
    }

    final result = const IcsParser().parse(response.body);
    final existing = await eventDao.mirroredFrom(
      sourceId,
      DateTime(2000),
      DateTime(2100),
    );
    final existingByUid = {
      for (final row in existing)
        if (row.importSourceEventId != null) row.importSourceEventId!: row,
    };
    final currentUids = result.vevents.map((v) => v.uid).toSet();
    final now = DateTime.now();

    await eventDao.transaction(() async {
      for (final v in result.vevents) {
        final row = existingByUid[v.uid];
        await eventDao.upsert(
          EventsCompanion(
            id: Value(row?.id ?? _uuid.v4()),
            title: Value(v.title),
            memo: Value(v.memo),
            location: Value(v.location),
            startAt: Value(v.start),
            endAt: Value(v.end),
            isAllDay: Value(v.isAllDay),
            notify: const Value(false),
            colorTag: Value(_holidayColorHex),
            syncStatus: const Value(SyncStatus.synced),
            importSourceCalendarId: Value(sourceId),
            importSourceEventId: Value(v.uid),
            createdAt: row == null ? Value(now) : Value(row.createdAt),
            updatedAt: Value(now),
          ),
        );
      }
      for (final row in existing) {
        if (!currentUids.contains(row.importSourceEventId)) {
          await eventDao.deleteById(row.id);
        }
      }
    });
  }

  /// Removes every mirrored row for [localeCode] — used when the user turns
  /// "공휴일 표시"/"Show holidays" off in Settings.
  Future<void> unsubscribe(String localeCode) async {
    final sourceId = holidayImportSourceId(localeCode);
    final rows = await eventDao.mirroredFrom(
      sourceId,
      DateTime(2000),
      DateTime(2100),
    );
    await eventDao.transaction(() async {
      for (final row in rows) {
        await eventDao.deleteById(row.id);
      }
    });
  }
}
