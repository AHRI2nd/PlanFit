import 'package:device_calendar_plus_platform_interface/device_calendar_plus_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/calendar_sync/calendar_service.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'calendar_service_push_test.mocks.dart';

/// [CalendarService] talks to the fixed `DeviceCalendar.instance` singleton,
/// which in turn always delegates to the swappable
/// `DeviceCalendarPlusPlatform.instance` — so faking the OS calendar for a
/// test means replacing that, not `DeviceCalendar` itself.
///
/// The generated [MockDeviceCalendarPlusPlatform] alone can't be assigned
/// to `DeviceCalendarPlusPlatform.instance`: that setter calls
/// `PlatformInterface.verify`, which rejects anything that isn't either the
/// real subclass (constructed with the platform's private token) or marked
/// with [MockPlatformInterfaceMixin] — the documented escape hatch for
/// exactly this situation. Mixing it in here is the standard
/// mockito-over-a-platform-interface pattern (see that mixin's own doc
/// comment for the same shape).
class _FakeDeviceCalendarPlatform extends MockDeviceCalendarPlusPlatform
    with MockPlatformInterfaceMixin {}

/// Covers the one part of "editing a device-calendar-sourced event and
/// pushing it back" that couldn't be exercised at the `EventRepositoryImpl`
/// level (see event_repository_test.dart's "editing an event auto-imported
/// from the device calendar..." test, which only proves the repository
/// hands `osEventId` through unchanged): whether `CalendarService.pushEvent`
/// itself actually turns that into a platform *update* call rather than
/// creating a duplicate event.
@GenerateMocks([DeviceCalendarPlusPlatform])
void main() {
  late _FakeDeviceCalendarPlatform fakePlatform;
  late CalendarService service;

  setUp(() {
    // DeviceCalendarPlusPlatform.instance is process-global state (the
    // plugin's own registration mechanism): outside a real app/device there
    // is no platform-specific implementation to have self-registered, so
    // there's nothing to save and restore — just point it at a fresh fake
    // before every test.
    fakePlatform = _FakeDeviceCalendarPlatform();
    DeviceCalendarPlusPlatform.instance = fakePlatform;
    // Set directly rather than left null: resolveTargetCalendarId() only
    // hits the platform (listCalendars/createCalendar) to *resolve* an
    // unknown target — pre-seeding it keeps this test focused on the
    // create-vs-update branch alone.
    service = CalendarService()..targetCalendarId = 'target-cal';
  });

  EventRow row({required String id, String? osEventId}) {
    final start = DateTime(2026, 3, 10, 9);
    return EventRow(
      id: id,
      title: 'Team sync',
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
      isAllDay: false,
      notify: false,
      reminderMinutesBefore: 0,
      osEventId: osEventId,
      syncStatus: SyncStatus.pendingPush,
      createdAt: start,
      updatedAt: start,
    );
  }

  // DeviceCalendar.updateEvent always forwards every one of these named
  // parameters to the platform layer, whether or not the caller supplied a
  // value — so the stub/verification below must match on all of them, not
  // just the ones CalendarService happens to pass non-null.
  Future<void> Function(Invocation) noopUpdate() => (_) async {};

  test(
    'an event that already has an osEventId is pushed as an update against '
    'that id — not a duplicate create — and the same id is returned',
    () async {
      when(
        fakePlatform.updateEvent(
          any,
          timestamp: anyNamed('timestamp'),
          title: anyNamed('title'),
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
          description: anyNamed('description'),
          location: anyNamed('location'),
          url: anyNamed('url'),
          isAllDay: anyNamed('isAllDay'),
          timeZone: anyNamed('timeZone'),
          availability: anyNamed('availability'),
          reminders: anyNamed('reminders'),
        ),
      ).thenAnswer(noopUpdate());

      final result = await service.pushEvent(
        row(id: 'e1', osEventId: 'os-999'),
      );

      expect(result, 'os-999');
      final captured = verify(
        fakePlatform.updateEvent(
          captureAny,
          timestamp: anyNamed('timestamp'),
          title: anyNamed('title'),
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
          description: anyNamed('description'),
          location: anyNamed('location'),
          url: anyNamed('url'),
          isAllDay: anyNamed('isAllDay'),
          timeZone: anyNamed('timeZone'),
          availability: anyNamed('availability'),
          reminders: anyNamed('reminders'),
        ),
      ).captured;
      expect(captured.single, 'os-999');
      verifyNever(
        fakePlatform.createEvent(
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
        ),
      );
    },
  );

  test(
    'a brand-new event (no osEventId yet) is pushed as a create, into the '
    'resolved target calendar',
    () async {
      when(
        fakePlatform.createEvent(
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
        ),
      ).thenAnswer((_) async => 'os-new-1');

      final result = await service.pushEvent(row(id: 'e2'));

      expect(result, 'os-new-1');
      final calendarIdArg =
          verify(
                fakePlatform.createEvent(
                  captureAny,
                  any,
                  any,
                  any,
                  any,
                  any,
                  any,
                  any,
                  any,
                  any,
                  any,
                  any,
                ),
              ).captured.single
              as String?;
      expect(calendarIdArg, 'target-cal');
      verifyNever(
        fakePlatform.updateEvent(
          any,
          timestamp: anyNamed('timestamp'),
          title: anyNamed('title'),
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
          description: anyNamed('description'),
          location: anyNamed('location'),
          url: anyNamed('url'),
          isAllDay: anyNamed('isAllDay'),
          timeZone: anyNamed('timeZone'),
          availability: anyNamed('availability'),
          reminders: anyNamed('reminders'),
        ),
      );
    },
  );

  test(
    "when the linked OS event is gone (deleted in the calendar app), the "
    "update falls back to creating a fresh one instead of leaving the row "
    "stuck retrying a dead id forever",
    () async {
      when(
        fakePlatform.updateEvent(
          any,
          timestamp: anyNamed('timestamp'),
          title: anyNamed('title'),
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
          description: anyNamed('description'),
          location: anyNamed('location'),
          url: anyNamed('url'),
          isAllDay: anyNamed('isAllDay'),
          timeZone: anyNamed('timeZone'),
          availability: anyNamed('availability'),
          reminders: anyNamed('reminders'),
        ),
      ).thenThrow(PlatformException(code: 'NOT_FOUND'));
      when(
        fakePlatform.createEvent(
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
          any,
        ),
      ).thenAnswer((_) async => 'os-replacement');

      final result = await service.pushEvent(
        row(id: 'e3', osEventId: 'os-gone'),
      );

      expect(result, 'os-replacement');
    },
  );
}
