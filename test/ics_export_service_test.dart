import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/backup/ics_export_service.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/features/schedule/domain/event_input.dart';
import 'package:planfit/features/schedule/domain/event_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'ics_export_service_test.mocks.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

@GenerateMocks([EventRepository])
void main() {
  late MockEventRepository repo;
  late IcsExportService service;

  setUpAll(() {
    PathProviderPlatform.instance = _FakePathProvider(
      Directory.systemTemp.createTempSync('planfit_ics_test').path,
    );
  });

  setUp(() {
    repo = MockEventRepository();
    service = IcsExportService(eventRepository: repo);
  });

  EventRow row({
    required String id,
    required String title,
    String? memo,
    String? location,
    required DateTime startAt,
    required DateTime endAt,
    bool isAllDay = false,
  }) {
    return EventRow(
      id: id,
      title: title,
      memo: memo,
      location: location,
      startAt: startAt,
      endAt: endAt,
      isAllDay: isAllDay,
      notify: true,
      reminderMinutesBefore: 0,
      colorTag: null,
      recurrenceRule: null,
      recurrenceGroupId: null,
      osCalendarId: null,
      osEventId: null,
      osLastKnownModified: null,
      syncStatus: SyncStatus.pendingPush,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
  }

  Future<String> exported() async {
    final file = await service.exportToFile();
    return file.readAsString();
  }

  test(
    'exportEventToFile writes just that one event, ignoring allEvents()',
    () async {
      final start = DateTime.utc(2026, 6, 1, 9);
      when(repo.allEvents()).thenAnswer(
        (_) async => [
          row(
            id: 'other',
            title: 'Should not appear',
            startAt: start,
            endAt: start,
          ),
        ],
      );

      final file = await service.exportEventToFile(
        row(
          id: 'e1',
          title: 'Coffee chat',
          startAt: start,
          endAt: start.add(const Duration(hours: 1)),
        ),
      );
      final ics = await file.readAsString();

      expect(ics, contains('SUMMARY:Coffee chat'));
      expect(ics, isNot(contains('Should not appear')));
      expect('BEGIN:VEVENT'.allMatches(ics).length, 1);
    },
  );

  test('wraps events in a VCALENDAR with the required headers', () async {
    when(repo.allEvents()).thenAnswer((_) async => []);

    final ics = await exported();

    expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(ics, contains('VERSION:2.0\r\n'));
    expect(ics, contains('PRODID:'));
    expect(ics, endsWith('END:VCALENDAR'));
  });

  test('writes a timed event\'s start/end as UTC Z-suffixed stamps', () async {
    final start = DateTime.utc(2026, 6, 1, 9, 30);
    final end = DateTime.utc(2026, 6, 1, 10, 30);
    when(repo.allEvents()).thenAnswer(
      (_) async => [
        row(id: 'e1', title: 'Standup', startAt: start, endAt: end),
      ],
    );

    final ics = await exported();

    expect(ics, contains('DTSTART:20260601T093000Z'));
    expect(ics, contains('DTEND:20260601T103000Z'));
    expect(ics, contains('SUMMARY:Standup'));
  });

  test(
    'writes an all-day event as a bare DATE value, not a timestamp',
    () async {
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 6, 2);
      when(repo.allEvents()).thenAnswer(
        (_) async => [
          row(
            id: 'e2',
            title: 'Holiday',
            startAt: start,
            endAt: end,
            isAllDay: true,
          ),
        ],
      );

      final ics = await exported();

      expect(ics, contains('DTSTART;VALUE=DATE:20260601'));
      expect(ics, contains('DTEND;VALUE=DATE:20260602'));
    },
  );

  test(
    'escapes commas, semicolons, backslashes, and newlines in text fields',
    () async {
      final start = DateTime.utc(2026, 6, 1, 9);
      when(repo.allEvents()).thenAnswer(
        (_) async => [
          row(
            id: 'e3',
            title: 'A, B; C\\D',
            memo: 'line one\nline two',
            startAt: start,
            endAt: start.add(const Duration(hours: 1)),
          ),
        ],
      );

      final ics = await exported();

      expect(ics, contains(r'SUMMARY:A\, B\; C\\D'));
      expect(ics, contains(r'DESCRIPTION:line one\nline two'));
    },
  );

  test(
    'writes a LOCATION line when the event has one, omits it otherwise',
    () async {
      final start = DateTime.utc(2026, 6, 1, 9);
      when(repo.allEvents()).thenAnswer(
        (_) async => [
          row(
            id: 'e5',
            title: 'Coffee',
            location: 'Blue Bottle',
            startAt: start,
            endAt: start.add(const Duration(hours: 1)),
          ),
          row(
            id: 'e6',
            title: 'No location',
            startAt: start,
            endAt: start.add(const Duration(hours: 1)),
          ),
        ],
      );

      final ics = await exported();

      expect(ics, contains('LOCATION:Blue Bottle'));
      expect('LOCATION'.allMatches(ics).length, 1);
    },
  );

  test(
    'folds a content line longer than 75 characters with CRLF + space',
    () async {
      final start = DateTime.utc(2026, 6, 1, 9);
      final longTitle = 'A' * 120;
      when(repo.allEvents()).thenAnswer(
        (_) async => [
          row(
            id: 'e4',
            title: longTitle,
            startAt: start,
            endAt: start.add(const Duration(hours: 1)),
          ),
        ],
      );

      final ics = await exported();

      expect(ics, contains('\r\n '));
      // No single unfolded line should exceed 75 characters.
      for (final line in ics.split('\r\n')) {
        expect(line.length, lessThanOrEqualTo(75));
      }
    },
  );

  group('importFromFile', () {
    late Directory tempDir;

    setUpAll(() {
      tempDir = Directory.systemTemp.createTempSync('planfit_ics_import_test');
    });

    tearDownAll(() {
      tempDir.deleteSync(recursive: true);
    });

    Future<String> writeIcs(String content) async {
      final file = File(
        '${tempDir.path}/${DateTime.now().microsecondsSinceEpoch}.ics',
      );
      await file.writeAsString(content);
      return file.path;
    }

    setUp(() {
      when(repo.save(any)).thenAnswer((invocation) async {
        final input = invocation.positionalArguments[0] as EventInput;
        return row(
          id: input.id,
          title: input.title,
          memo: input.memo,
          location: input.location,
          startAt: input.startAt,
          endAt: input.endAt,
          isAllDay: input.isAllDay,
        );
      });
    });

    test('imports a UTC-timestamped VEVENT, notify off', () async {
      final path = await writeIcs(
        'BEGIN:VCALENDAR\r\n'
        'VERSION:2.0\r\n'
        'BEGIN:VEVENT\r\n'
        'UID:abc@example.com\r\n'
        'DTSTART:20260601T093000Z\r\n'
        'DTEND:20260601T103000Z\r\n'
        'SUMMARY:Standup\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR',
      );

      final summary = await service.importFromFile(path);

      expect(summary.eventCount, 1);
      expect(summary.skippedCount, 0);
      final input = verify(repo.save(captureAny)).captured.single as EventInput;
      expect(input.title, 'Standup');
      expect(input.startAt, DateTime.utc(2026, 6, 1, 9, 30).toLocal());
      expect(input.notify, isFalse);
    });

    test('imports an all-day VEVENT as a bare-date, all-day event', () async {
      final path = await writeIcs(
        'BEGIN:VCALENDAR\r\n'
        'BEGIN:VEVENT\r\n'
        'DTSTART;VALUE=DATE:20260601\r\n'
        'DTEND;VALUE=DATE:20260602\r\n'
        'SUMMARY:Holiday\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR',
      );

      await service.importFromFile(path);

      final input = verify(repo.save(captureAny)).captured.single as EventInput;
      expect(input.isAllDay, isTrue);
      expect(input.startAt, DateTime(2026, 6, 1));
      expect(input.endAt, DateTime(2026, 6, 2));
    });

    test('unescapes commas, semicolons, backslashes, and newlines', () async {
      final path = await writeIcs(
        'BEGIN:VCALENDAR\r\n'
        'BEGIN:VEVENT\r\n'
        'DTSTART:20260601T090000Z\r\n'
        r'SUMMARY:A\, B\; C\\D'
        '\r\n'
        r'DESCRIPTION:line one\nline two'
        '\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR',
      );

      await service.importFromFile(path);

      final input = verify(repo.save(captureAny)).captured.single as EventInput;
      expect(input.title, r'A, B; C\D');
      expect(input.memo, 'line one\nline two');
    });

    test('un-folds a continued line before parsing it', () async {
      final longTitle = 'A' * 120;
      final path = await writeIcs(
        'BEGIN:VCALENDAR\r\n'
        'BEGIN:VEVENT\r\n'
        'DTSTART:20260601T090000Z\r\n'
        'SUMMARY:${longTitle.substring(0, 75)}\r\n'
        ' ${longTitle.substring(75)}\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR',
      );

      await service.importFromFile(path);

      final input = verify(repo.save(captureAny)).captured.single as EventInput;
      expect(input.title, longTitle);
    });

    test(
      'skips a VEVENT missing SUMMARY or DTSTART, counts it separately',
      () async {
        final path = await writeIcs(
          'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'DTSTART:20260601T090000Z\r\n'
          'END:VEVENT\r\n'
          'BEGIN:VEVENT\r\n'
          'SUMMARY:Good one\r\n'
          'DTSTART:20260602T090000Z\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR',
        );

        final summary = await service.importFromFile(path);

        expect(summary.eventCount, 1);
        expect(summary.skippedCount, 1);
      },
    );

    test('a VEVENT with an RRULE still imports as its own single '
        'occurrence, RRULE ignored', () async {
      final path = await writeIcs(
        'BEGIN:VCALENDAR\r\n'
        'BEGIN:VEVENT\r\n'
        'SUMMARY:Weekly sync\r\n'
        'DTSTART:20260601T090000Z\r\n'
        'RRULE:FREQ=WEEKLY;COUNT=10\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR',
      );

      final summary = await service.importFromFile(path);

      expect(summary.eventCount, 1);
      final input = verify(repo.save(captureAny)).captured.single as EventInput;
      expect(input.title, 'Weekly sync');
      expect(input.recurrenceFrequency.name, 'none');
    });

    test(
      'a DTSTART with no zone/TZID qualifier is taken as local time',
      () async {
        final path = await writeIcs(
          'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'SUMMARY:Local meeting\r\n'
          'DTSTART;TZID=Asia/Seoul:20260601T090000\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR',
        );

        await service.importFromFile(path);

        final input =
            verify(repo.save(captureAny)).captured.single as EventInput;
        expect(input.startAt, DateTime(2026, 6, 1, 9));
        // No DTEND — falls back to a 1-hour default duration.
        expect(input.endAt, DateTime(2026, 6, 1, 10));
      },
    );
  });
}
