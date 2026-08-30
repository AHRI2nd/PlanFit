import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/calendar_sync/holiday_calendar_service.dart';
import 'package:planfit/core/db/app_database.dart';

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

    await service.sync('ko');

    final rows = await db.eventDao.all();
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.importSourceCalendarId == 'holiday:ko'), isTrue);
    expect(rows.every((r) => r.notify == false), isTrue);
  });

  test(
    're-syncing the same feed updates rows in place, no duplicates',
    () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithTwo));
      await service.sync('ko');

      await service.sync('ko');

      final rows = await db.eventDao.all();
      expect(rows, hasLength(2));
    },
  );

  test(
    'an item that disappears from the feed is removed on the next sync',
    () async {
      when(client.get(any)).thenAnswer((_) async => ok(_feedWithTwo));
      await service.sync('ko');

      when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));
      await service.sync('ko');

      final rows = await db.eventDao.all();
      expect(rows, hasLength(1));
      expect(rows.single.title, 'New Year');
    },
  );

  test('unsubscribe removes every mirrored row for that locale', () async {
    when(client.get(any)).thenAnswer((_) async => ok(_feedWithTwo));
    await service.sync('ko');

    await service.unsubscribe('ko');

    expect(await db.eventDao.all(), isEmpty);
  });

  test('ko and en resolve to different feed URLs', () async {
    when(client.get(any)).thenAnswer((_) async => ok(_feedWithOne));

    await service.sync('ko');
    final koUrl = verify(client.get(captureAny)).captured.single as Uri;
    await service.sync('en');
    final enUrl = verify(client.get(captureAny)).captured.single as Uri;

    expect(koUrl, isNot(enUrl));
    expect(koUrl.toString(), contains('south_korea'));
    expect(enUrl.toString(), contains('usa'));
  });
}
