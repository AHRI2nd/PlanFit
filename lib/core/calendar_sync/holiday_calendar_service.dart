import 'dart:ui' show PlatformDispatcher;

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../design/tokens/app_colors.dart';
import '../../design/tokens/event_color_tag.dart';
import '../backup/ics_parser.dart';
import '../db/app_database.dart';
import '../db/daos/event_dao.dart';
import '../db/sync_status.dart';

/// Source-id prefix for a country-based holiday mirror — see
/// [holidayCustomSourceId] for the other kind. Both start with `'holiday:'`,
/// which is the only part `MirroredEventDetailScreen._isHoliday` actually
/// checks, so either shape is recognized as a read-only holiday row there.
String holidayCountrySourceId(String countryCode) =>
    'holiday:country:$countryCode';

/// Source-id for one user-supplied custom ICS feed — any number can be
/// active at once (see [AppSettings.customHolidayCalendarUrls]), so unlike
/// the single fixed id an earlier version of this used, each URL gets its
/// own, the same way each country gets its own via [holidayCountrySourceId].
/// The raw URL embedded directly, matching how `CalendarImportService`
/// tags a subscribed device calendar with its own raw id rather than a
/// hash — a TEXT column with one long string per row is unremarkable.
String holidayCustomSourceId(String url) => 'holiday:custom:$url';

/// Source ids this service used before country/custom selection existed —
/// every mirrored row before that point was tagged with the app's *locale*
/// code (`'holiday:ko'`/`'holiday:en'`), not a country code. Never written
/// again; only [HolidayCalendarService.migrateLegacySources] reads this, to
/// clean up rows an upgraded install would otherwise orphan forever (a
/// locale code and a country code aren't the same string space once more
/// than two countries exist, so these can't just be reinterpreted in place).
const List<String> legacyHolidayLocaleSourceIds = ['holiday:ko', 'holiday:en'];

/// `'ko'` -> `'KR'`, everything else -> `'US'` — the exact default the old
/// locale-keyed sync used (`_calendarIds[localeCode] ?? _calendarIds['en']`),
/// reimplemented off `dart:ui`'s [PlatformDispatcher] (no `BuildContext`
/// needed) so `SettingsController`'s one-time seed of
/// `AppSettings.holidayCountryCodes` and the background resume-sync in
/// app.dart can both resolve "auto" without needing a
/// widget-tree `Localizations.localeOf(context)` call (which the resume-sync
/// path historically got wrong — see app.dart's own history on this).
String defaultHolidayCountryCode() =>
    PlatformDispatcher.instance.locale.languageCode == 'ko' ? 'KR' : 'US';

/// Thrown by [HolidayCalendarService.syncCountry]/[syncCustomUrl] when the
/// interactive picker's sync attempt fails — a network error, a non-200
/// response, an unrecognized country code, an unparseable custom URL, or (on
/// a custom URL's very first sync) a 200 response that parsed to zero
/// events, a strong signal the link isn't actually an ICS feed. The
/// background resume-sync in app.dart still swallows this (best-effort,
/// unchanged), but the settings screen needs it to actually reach the user.
class HolidayCalendarSyncException implements Exception {
  HolidayCalendarSyncException(this.message);
  final String message;
  @override
  String toString() => 'HolidayCalendarSyncException: $message';
}

/// Keeps every chosen national-holiday calendar and custom ICS feed
/// mirrored into PlanFit simultaneously — see
/// [AppSettings.holidayCountryCodes] and
/// [AppSettings.customHolidayCalendarUrls] for how the user picks any
/// number of them.
/// Deliberately reuses [CalendarImportService]'s own pattern (bypass
/// [EventRepository.save], write rows straight through [EventDao] as
/// already-[SyncStatus.synced] with no `osEventId`, matched on
/// `(importSourceCalendarId, importSourceEventId)` across re-syncs rather
/// than a derived id) for the same reason: a holiday row must never be
/// editable, and must never get pushed back out to the device calendar.
///
/// The built-in country feeds are all public `.ics` feeds Google publishes
/// and maintains for national holidays — plain `https://` GET, no API key,
/// no billing account, no rate limit that matters at this scale (see the
/// session's own cost research before this was scoped this way rather than
/// as a full Places/Maps-style integration). A custom URL is just whatever
/// `.ics` feed the user points at.
class HolidayCalendarService {
  HolidayCalendarService({required this.eventDao, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final EventDao eventDao;
  final http.Client _http;

  static const _uuid = Uuid();

  /// Google's own calendar id for each supported country's official public
  /// holidays — add an entry here to support a new country (the picker
  /// screen lists whatever's in this map). Re-verify a new entry actually
  /// returns 200 before shipping — Google occasionally renames/retires
  /// these ids.
  static const Map<String, String> holidayCountryCalendarIds = {
    'KR': 'en.south_korea.official#holiday@group.v.calendar.google.com',
    'US': 'en.usa.official#holiday@group.v.calendar.google.com',
    'JP': 'en.japanese#holiday@group.v.calendar.google.com',
    'GB': 'en.uk.official#holiday@group.v.calendar.google.com',
    'DE': 'en.german#holiday@group.v.calendar.google.com',
    'FR': 'en.french#holiday@group.v.calendar.google.com',
    'CA': 'en.canadian#holiday@group.v.calendar.google.com',
    'AU': 'en.australian#holiday@group.v.calendar.google.com',
  };

  static final String _holidayColorHex = EventColorTag.toHex(
    AppColors.holidayRed,
  );

  Uri _googleFeedUrl(String calendarId) {
    // Uri.https's own `unencodedPath` already percent-encodes each path
    // segment it's given — wrapping calendarId in Uri.encodeComponent
    // first double-encodes it (`#` becomes `%23`, then `%` in that becomes
    // `%25`, landing the server a literal `%2523` it can't resolve to any
    // real calendar, which is why this 500'd on every real request instead
    // of ever actually fetching a feed).
    return Uri.https(
      'calendar.google.com',
      '/calendar/ical/$calendarId/public/basic.ics',
    );
  }

  /// Syncs the built-in feed for [countryCode] (a key of
  /// [holidayCountryCalendarIds]) — throws [HolidayCalendarSyncException] if
  /// the code isn't recognized or the fetch/parse fails.
  Future<void> syncCountry(String countryCode) async {
    final calendarId = holidayCountryCalendarIds[countryCode];
    if (calendarId == null) {
      throw HolidayCalendarSyncException(
        'Unrecognized holiday country code: $countryCode',
      );
    }
    await _syncFrom(
      sourceId: holidayCountrySourceId(countryCode),
      feedUrl: _googleFeedUrl(calendarId),
    );
  }

  /// Removes every mirrored row for [countryCode] — used when the user
  /// switches away from it (a different country, a custom URL, or turning
  /// "공휴일 표시"/"Show holidays" off entirely).
  Future<void> unsubscribeCountry(String countryCode) =>
      _unsubscribe(holidayCountrySourceId(countryCode));

  /// Syncs a user-supplied custom ICS feed at [url]. Throws
  /// [HolidayCalendarSyncException] for an invalid/non-http(s) URL, a
  /// network error, a non-200 response, or — only on this URL's very first
  /// sync, when there's nothing mirrored from it yet — a 200 response that
  /// parsed to zero events, since a legitimately holiday-free stretch is
  /// implausible for a brand-new feed and this is much more likely a wrong
  /// or non-ICS URL the user should be told about immediately rather than
  /// silently "succeeding" with nothing to show for it.
  Future<void> syncCustomUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('HTTP') || uri.isScheme('HTTPS'))) {
      throw HolidayCalendarSyncException('Invalid calendar URL: $url');
    }
    final sourceId = holidayCustomSourceId(url);
    final isFirstSync = (await eventDao.mirroredFrom(
      sourceId,
      DateTime(2000),
      DateTime(2100),
    )).isEmpty;
    final count = await _syncFrom(sourceId: sourceId, feedUrl: uri);
    if (isFirstSync && count == 0) {
      // Leave nothing mirrored from an apparently-bogus feed rather than a
      // silent zero-event "success."
      await _unsubscribe(sourceId);
      throw HolidayCalendarSyncException(
        'No events found at $url — check the link',
      );
    }
  }

  /// Removes the mirrored calendar for custom URL [url].
  Future<void> unsubscribeCustom(String url) =>
      _unsubscribe(holidayCustomSourceId(url));

  /// One-time cleanup for an install upgraded from before country/custom
  /// selection existed — see [legacyHolidayLocaleSourceIds]'s own doc. Safe
  /// to call repeatedly (a no-op once the legacy rows are gone); the actual
  /// call site (app.dart) still gates it behind a persisted flag so a
  /// resume that finds nothing to clean up doesn't re-scan the table every
  /// single time forever.
  Future<void> migrateLegacySources() async {
    for (final sourceId in legacyHolidayLocaleSourceIds) {
      await _unsubscribe(sourceId);
    }
  }

  /// Fetches [feedUrl] and upserts every VEVENT as a read-only mirror row
  /// tagged [sourceId], removing any previously-mirrored row under the same
  /// [sourceId] that's no longer in the feed (a corrected/removed
  /// observance). Matched by [IcsVevent.uid] — see that class's doc on why a
  /// UID-less VEVENT still gets a stable synthesized one, which is what
  /// makes a plain re-fetch of an unchanged feed update rows in place
  /// instead of duplicating them. Returns the number of events the feed
  /// currently contains (used by [syncCustomUrl] to detect an
  /// apparently-empty/bogus feed on first sync). Throws
  /// [HolidayCalendarSyncException] on a network error or non-200 response
  /// — callers that want best-effort, silent-failure semantics (the
  /// background resume-sync in app.dart) catch it themselves; this method
  /// never swallows it, so an interactive caller (the settings picker) can
  /// always show the user what went wrong.
  Future<int> _syncFrom({
    required String sourceId,
    required Uri feedUrl,
  }) async {
    final http.Response response;
    try {
      response = await _http.get(feedUrl);
    } catch (e) {
      throw HolidayCalendarSyncException('Could not reach $feedUrl: $e');
    }
    if (response.statusCode != 200) {
      throw HolidayCalendarSyncException(
        '$feedUrl returned ${response.statusCode}',
      );
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

    return result.vevents.length;
  }

  Future<void> _unsubscribe(String sourceId) async {
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
