import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/calendar_sync/calendar_import_service.dart';
import 'package:planfit/core/calendar_sync/calendar_service.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';

import 'calendar_import_service_test.mocks.dart';

@GenerateMocks([CalendarService])
void main() {
  late AppDatabase db;
  late MockCalendarService service;
  late CalendarImportService importService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = MockCalendarService();
    importService = CalendarImportService(
      calendarService: service,
      eventDao: db.eventDao,
    );
  });

  tearDown(() => db.close());

  dc.Event osEvent({
    required String instanceId,
    required DateTime start,
    String title = 'Standup',
    String? description,
    bool isAllDay = false,
  }) {
    return dc.Event(
      eventId: 'series-$instanceId',
      instanceId: instanceId,
      calendarId: 'work-cal',
      title: title,
      description: description,
      startDate: start,
      endDate: start.add(const Duration(hours: 1)),
      isAllDay: isAllDay,
      availability: dc.EventAvailability.busy,
      status: dc.EventStatus.none,
      isRecurring: false,
    );
  }

  test('copies events in as local-only rows: no osEventId, notify off, '
      'already synced so the reconciler never tries to push them back out',
      () async {
    final start = DateTime(2026, 5, 1, 9);
    when(service.listEvents('work-cal',
            from: anyNamed('from'), to: anyNamed('to')))
        .thenAnswer((_) async => [osEvent(instanceId: 'occ-1', start: start)]);

    final count = await importService.importFrom(
      'work-cal',
      from: DateTime(2026, 1, 1),
      to: DateTime(2027, 1, 1),
    );

    expect(count, 1);
    final rows = await db.eventDao.all();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.title, 'Standup');
    expect(row.startAt, start);
    expect(row.osEventId, isNull);
    expect(row.notify, isFalse);
    expect(row.syncStatus, SyncStatus.synced);
  });

  test('re-importing the same calendar updates the existing row instead of '
      'duplicating it', () async {
    final firstStart = DateTime(2026, 5, 1, 9);
    when(service.listEvents('work-cal',
            from: anyNamed('from'), to: anyNamed('to')))
        .thenAnswer(
            (_) async => [osEvent(instanceId: 'occ-1', start: firstStart)]);
    await importService.importFrom('work-cal',
        from: DateTime(2026, 1, 1), to: DateTime(2027, 1, 1));

    final movedStart = DateTime(2026, 5, 1, 14);
    when(service.listEvents('work-cal',
            from: anyNamed('from'), to: anyNamed('to')))
        .thenAnswer((_) async =>
            [osEvent(instanceId: 'occ-1', start: movedStart, title: 'Moved')]);
    final count = await importService.importFrom('work-cal',
        from: DateTime(2026, 1, 1), to: DateTime(2027, 1, 1));

    expect(count, 1);
    final rows = await db.eventDao.all();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Moved');
    expect(rows.single.startAt, movedStart);
  });

  test('availableCalendars delegates to CalendarService.allCalendars', () async {
    when(service.allCalendars()).thenAnswer((_) async => []);

    await importService.availableCalendars();

    verify(service.allCalendars()).called(1);
  });

  group('syncMirroredCalendars', () {
    final from = DateTime(2026, 1, 1);
    final to = DateTime(2027, 1, 1);

    test('upserts current events and tags them with their source', () async {
      final start = DateTime(2026, 5, 1, 9);
      when(service.listEvents('work-cal', from: from, to: to)).thenAnswer(
          (_) async => [osEvent(instanceId: 'occ-1', start: start)]);

      await importService.syncMirroredCalendars({'work-cal'}, from: from, to: to);

      final row = (await db.eventDao.all()).single;
      expect(row.importSourceCalendarId, 'work-cal');
      expect(row.importSourceEventId, 'occ-1');
    });

    test('removes a previously-mirrored row once it disappears from the '
        'source', () async {
      when(service.listEvents('work-cal', from: from, to: to)).thenAnswer(
          (_) async => [
                osEvent(instanceId: 'occ-1', start: DateTime(2026, 5, 1, 9)),
                osEvent(instanceId: 'occ-2', start: DateTime(2026, 5, 2, 9)),
              ]);
      await importService.syncMirroredCalendars({'work-cal'}, from: from, to: to);
      expect(await db.eventDao.all(), hasLength(2));

      // occ-2 was deleted at the source; only occ-1 still comes back.
      when(service.listEvents('work-cal', from: from, to: to)).thenAnswer(
          (_) async =>
              [osEvent(instanceId: 'occ-1', start: DateTime(2026, 5, 1, 9))]);
      await importService.syncMirroredCalendars({'work-cal'}, from: from, to: to);

      final rows = await db.eventDao.all();
      expect(rows.map((r) => r.importSourceEventId), ['occ-1']);
    });

    test('keeps the same local id across syncs (updates, not duplicates)',
        () async {
      when(service.listEvents('work-cal', from: from, to: to)).thenAnswer(
          (_) async =>
              [osEvent(instanceId: 'occ-1', start: DateTime(2026, 5, 1, 9))]);
      await importService.syncMirroredCalendars({'work-cal'}, from: from, to: to);
      final firstId = (await db.eventDao.all()).single.id;

      when(service.listEvents('work-cal', from: from, to: to)).thenAnswer(
          (_) async => [
                osEvent(
                    instanceId: 'occ-1',
                    start: DateTime(2026, 5, 1, 15),
                    title: 'Moved'),
              ]);
      await importService.syncMirroredCalendars({'work-cal'}, from: from, to: to);

      final rows = await db.eventDao.all();
      expect(rows, hasLength(1));
      expect(rows.single.id, firstId);
      expect(rows.single.title, 'Moved');
    });
  });

  test('removeMirroredCalendar deletes every local mirror row for that '
      'calendar', () async {
    final from = DateTime(2026, 1, 1);
    final to = DateTime(2027, 1, 1);
    when(service.listEvents('work-cal', from: from, to: to)).thenAnswer(
        (_) async => [
              osEvent(instanceId: 'occ-1', start: DateTime(2026, 5, 1, 9)),
              osEvent(instanceId: 'occ-2', start: DateTime(2026, 5, 2, 9)),
            ]);
    await importService.syncMirroredCalendars({'work-cal'}, from: from, to: to);
    expect(await db.eventDao.all(), hasLength(2));

    await importService.removeMirroredCalendar('work-cal');

    expect(await db.eventDao.all(), isEmpty);
  });
}
