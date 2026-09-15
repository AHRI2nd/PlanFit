import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/backup/ics_parser.dart';

void main() {
  const parser = IcsParser();

  String wrap(String vevent) =>
      'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n$vevent\r\nEND:VCALENDAR';

  test('uses the VEVENT\'s own UID when it has one', () {
    final result = parser.parse(
      wrap(
        'BEGIN:VEVENT\r\n'
        'UID:abc-123@example.com\r\n'
        'SUMMARY:Standup\r\n'
        'DTSTART:20260310T090000Z\r\n'
        'DTEND:20260310T093000Z\r\n'
        'END:VEVENT',
      ),
    );

    expect(result.skipped, 0);
    expect(result.vevents.single.uid, 'abc-123@example.com');
  });

  test('synthesizes a stable id from title+start when there is no UID', () {
    final withoutUid =
        'BEGIN:VEVENT\r\n'
        'SUMMARY:Standup\r\n'
        'DTSTART:20260310T090000Z\r\n'
        'DTEND:20260310T093000Z\r\n'
        'END:VEVENT';

    final first = parser.parse(wrap(withoutUid));
    final second = parser.parse(wrap(withoutUid));

    expect(first.vevents.single.uid, isNotEmpty);
    // Same input, same synthesized id — this is what lets a re-sync
    // recognize "the same event" across two parses of an unchanged feed
    // even when the source never set a UID.
    expect(first.vevents.single.uid, second.vevents.single.uid);
  });

  test('two different VEVENTs without a UID synthesize different ids', () {
    final result = parser.parse(
      wrap(
        'BEGIN:VEVENT\r\n'
        'SUMMARY:Standup\r\n'
        'DTSTART:20260310T090000Z\r\n'
        'END:VEVENT\r\n'
        'BEGIN:VEVENT\r\n'
        'SUMMARY:Lunch\r\n'
        'DTSTART:20260310T120000Z\r\n'
        'END:VEVENT',
      ),
    );

    expect(result.vevents, hasLength(2));
    expect(result.vevents[0].uid, isNot(result.vevents[1].uid));
  });

  test('resolves an IANA TZID before converting to the device local zone', () {
    final result = parser.parse(
      wrap(
        'BEGIN:VEVENT\r\n'
        'SUMMARY:New York meeting\r\n'
        'DTSTART;TZID=America/New_York:20260925T090000\r\n'
        'END:VEVENT',
      ),
    );

    expect(result.vevents.single.start.toUtc(), DateTime.utc(2026, 9, 25, 13));
  });

  test('falls back to local time for an unknown TZID', () {
    final result = parser.parse(
      wrap(
        'BEGIN:VEVENT\r\n'
        'SUMMARY:Legacy meeting\r\n'
        'DTSTART;TZID=Customized Time Zone:20260925T090000\r\n'
        'END:VEVENT',
      ),
    );

    expect(result.vevents.single.start, DateTime(2026, 9, 25, 9));
  });

  test('skips a VEVENT missing SUMMARY or DTSTART, counts it separately', () {
    final result = parser.parse(
      wrap(
        'BEGIN:VEVENT\r\n'
        'DTSTART:20260310T090000Z\r\n' // no SUMMARY
        'END:VEVENT\r\n'
        'BEGIN:VEVENT\r\n'
        'SUMMARY:Standup\r\n'
        'DTSTART:20260310T090000Z\r\n'
        'END:VEVENT',
      ),
    );

    expect(result.vevents, hasLength(1));
    expect(result.skipped, 1);
  });
}
