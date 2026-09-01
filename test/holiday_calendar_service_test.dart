import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/calendar_sync/holiday_calendar_service.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';

import 'holiday_calendar_service_test.mocks.dart';

const _feedWithTwo =
    'BEGIN:VCALENDAR\r\n'
    'VERSION:2.0\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:new-year@holiday\r\n'
    'SUMMARY:New Year\r\n'
    'DTSTART;VALUE=DATE:20260101\r\n'
    'DTEND;VALUE=DATE:20260102\r\n'
    'END:VEVENT\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:lunar-new-year@holiday\r\n'
    'SUMMARY:Lunar New Year\r\n'
    'DTSTART;VALUE=DATE:20260217\r\n'
    'DTEND;VALUE=DATE:20260218\r\n'
    'END:VEVENT\r\n'
    'END:VCALENDAR';

const _feedWithOne =
    'BEGIN:VCALENDAR\r\n'
    'VERSION:2.0\r\n'
    'BEGIN:VEVENT\r\n'
    'UID:new-year@holiday\r\n'
    'SUMMARY:New Year\r\n'
    'DTSTART;VALUE=DATE:20260101\r\n'
    'DTEND;VALUE=DATE:20260102\r\n'
    'END:VEVENT\r\n'
    'END:VCALENDAR';

const _feedWithNone = 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR';

@GenerateMocks([http.Client])
void main() {
  late AppDatabase db;
  late MockClient client;
  late HolidayCalendarService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    client = MockClient();
    service = HolidayCalendarService(eventDao: db.eventDao, httpClient: client);
  });

  tearDown(() => db.close());

  http.Response ok(String body) => http.Response(body, 200);

  test('a first sync creates every VEVENT as a read-only mirror row', () async {
    when(client.get(any)).thenAnswer((_) async => ok(_feedWithTwo));

    await service.syncCountry('KR');

    final rows = await db.eventDao.all();
    expect(rows, hasLength(2));
    expect(
      rows.every((r) => r.importSourceCalendarId == 'holiday:country:KR'),
      isTrue,
    );
    expect(rows.every((r) => r.notify == false), isTrue);
  });

  test(
    'a mirrored event gets the default color when no colorHex is given',
    () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));

      await service.syncCountry('KR');

      final rows = await db.eventDao.all();
      expect(rows.single.colorTag, HolidayCalendarService.defaultColorHex);
    },
  );

  test(
    'a mirrored event gets colorHex when one is given, not the default',
    () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));

      await service.syncCountry('KR', colorHex: '#3388CC');

      final rows = await db.eventDao.all();
      expect(rows.single.colorTag, '#3388CC');
    },
  );

  test('re-syncing with a different colorHex updates already-mirrored rows, '
      'not just newly-added ones', () async {
    when(client.get(any)).thenAnswer((_) async => ok(_feedWithTwo));
    await service.syncCountry('KR', colorHex: '#3388CC');

    await service.syncCountry('KR', colorHex: '#AA2200');

    final rows = await db.eventDao.all();
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.colorTag == '#AA2200'), isTrue);
  });

  test('syncCustomUrl also respects colorHex, same as syncCountry', () async {
    when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));

    await service.syncCustomUrl(
      'https://example.com/cal.ics',
      colorHex: '#00AA55',
    );

    final rows = await db.eventDao.all();
    expect(rows.single.colorTag, '#00AA55');
  });

  test(
    're-syncing the same feed updates rows in place, no duplicates',
    () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithTwo));
      await service.syncCountry('KR');

      await service.syncCountry('KR');

      final rows = await db.eventDao.all();
      expect(rows, hasLength(2));
    },
  );

  test(
    'an item that disappears from the feed is removed on the next sync',
    () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithTwo));
      await service.syncCountry('KR');

      when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));
      await service.syncCountry('KR');

      final rows = await db.eventDao.all();
      expect(rows, hasLength(1));
      expect(rows.single.title, 'New Year');
    },
  );

  test(
    'unsubscribeCountry removes every mirrored row for that country',
    () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithTwo));
      await service.syncCountry('KR');

      await service.unsubscribeCountry('KR');

      expect(await db.eventDao.all(), isEmpty);
    },
  );

  test('an unrecognized country code throws', () async {
    expect(
      () => service.syncCountry('ZZ'),
      throwsA(isA<HolidayCalendarSyncException>()),
    );
    verifyNever(client.get(any));
  });

  test('KR and US resolve to different feed URLs', () async {
    when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));

    await service.syncCountry('KR');
    final krUrl = verify(client.get(captureAny)).captured.single as Uri;
    await service.syncCountry('US');
    final usUrl = verify(client.get(captureAny)).captured.single as Uri;

    expect(krUrl, isNot(usUrl));
    expect(krUrl.toString(), contains('south_korea'));
    expect(usUrl.toString(), contains('usa'));
  });

  test(
    'the feed URL percent-encodes the calendar id exactly once, not twice',
    () async {
      // Regression test: the calendar id contains `#` and `@`, which Uri.https
      // already percent-encodes for its `unencodedPath` argument — wrapping
      // the id in Uri.encodeComponent first (as an earlier version of this
      // service did) double-encodes it into `%2523`/`%2540`, a URL Google's
      // server 500s on, which a mocked http.Client can't catch since it
      // never actually resolves the request the way a real server would.
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));

      await service.syncCountry('KR');
      final url = verify(client.get(captureAny)).captured.single as Uri;

      // `#` is the one character in the calendar id that actually needs
      // escaping in a URL path segment; `@` doesn't and Uri.https leaves it
      // as-is, matching what a real server (verified via a direct curl of
      // this exact feed) accepts.
      expect(url.toString(), contains('official%23holiday@group'));
      expect(url.toString(), isNot(contains('%2523')));
      expect(url.toString(), isNot(contains('%2540')));
    },
  );

  group('syncCustomUrl', () {
    test('creates mirror rows tagged with the custom source id', () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));

      await service.syncCustomUrl('https://example.com/calendar.ics');

      final rows = await db.eventDao.all();
      expect(rows, hasLength(1));
      expect(
        rows.single.importSourceCalendarId,
        'holiday:custom:https://example.com/calendar.ics',
      );
    });

    test('a non-http(s) URL throws without ever making a request', () async {
      expect(
        () => service.syncCustomUrl('not a url'),
        throwsA(isA<HolidayCalendarSyncException>()),
      );
      expect(
        () => service.syncCustomUrl('ftp://example.com/x.ics'),
        throwsA(isA<HolidayCalendarSyncException>()),
      );
      verifyNever(client.get(any));
    });

    test('a non-200 response throws', () async {
      when(
        client.get(any),
      ).thenAnswer((_) async => http.Response('not found', 404));

      expect(
        () => service.syncCustomUrl('https://example.com/calendar.ics'),
        throwsA(isA<HolidayCalendarSyncException>()),
      );
    });

    test('a 200 response that parses to zero events throws on the first sync '
        '— a strong signal the URL isn\'t actually an ICS feed — and leaves '
        'nothing mirrored', () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithNone));

      await expectLater(
        () => service.syncCustomUrl('https://example.com/calendar.ics'),
        throwsA(isA<HolidayCalendarSyncException>()),
      );

      expect(await db.eventDao.all(), isEmpty);
    });

    test('a feed that later becomes empty does NOT throw on a re-sync — only '
        'the first sync of a URL treats zero events as suspicious', () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));
      await service.syncCustomUrl('https://example.com/calendar.ics');

      when(client.get(any)).thenAnswer((_) async => ok(_feedWithNone));
      await service.syncCustomUrl('https://example.com/calendar.ics');

      expect(await db.eventDao.all(), isEmpty);
    });

    test('unsubscribeCustom removes the mirrored custom rows', () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));
      await service.syncCustomUrl('https://example.com/calendar.ics');

      await service.unsubscribeCustom('https://example.com/calendar.ics');

      expect(await db.eventDao.all(), isEmpty);
    });

    test('two different custom URLs are mirrored independently, under '
        'distinct source ids', () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));
      await service.syncCustomUrl('https://example.com/a.ics');
      await service.syncCustomUrl('https://example.com/b.ics');

      final rows = await db.eventDao.all();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.importSourceCalendarId).toSet(), {
        'holiday:custom:https://example.com/a.ics',
        'holiday:custom:https://example.com/b.ics',
      });

      await service.unsubscribeCustom('https://example.com/a.ics');
      final remaining = await db.eventDao.all();
      expect(remaining, hasLength(1));
      expect(
        remaining.single.importSourceCalendarId,
        'holiday:custom:https://example.com/b.ics',
      );
    });
  });

  group('migrateLegacySources', () {
    Future<void> seedLegacyRow(String sourceId) async {
      await db.eventDao.upsert(
        EventsCompanion.insert(
          id: 'legacy-$sourceId',
          title: const Value('Legacy holiday'),
          startAt: DateTime(2026, 1, 1),
          endAt: DateTime(2026, 1, 2),
          isAllDay: const Value(true),
          syncStatus: const Value(SyncStatus.synced),
          importSourceCalendarId: Value(sourceId),
          importSourceEventId: const Value('legacy-uid'),
        ),
      );
    }

    test('removes rows under both legacy locale-code source ids', () async {
      await seedLegacyRow('holiday:ko');
      await seedLegacyRow('holiday:en');

      await service.migrateLegacySources();

      expect(await db.eventDao.all(), isEmpty);
    });

    test('is a no-op when there is nothing legacy to clean up', () async {
      await expectLater(service.migrateLegacySources(), completes);
      expect(await db.eventDao.all(), isEmpty);
    });

    test('never touches rows from the new country/custom source ids', () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));
      await service.syncCountry('KR');

      await service.migrateLegacySources();

      expect(await db.eventDao.all(), hasLength(1));
    });
  });
}
