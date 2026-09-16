import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:device_calendar_plus_platform_interface/device_calendar_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/calendar_sync/calendar_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'calendar_service_permission_test.mocks.dart';

/// Same platform-faking shape as `calendar_service_push_test.dart` — see the
/// long doc comment there for why the mock has to mix in
/// [MockPlatformInterfaceMixin] to be assignable.
class _FakeDeviceCalendarPlatform extends MockDeviceCalendarPlusPlatform
    with MockPlatformInterfaceMixin {}

/// Guards the one failure the settings toggle actually hits on a first-time
/// setup: the user grants calendar access, and the very next read is refused
/// anyway.
///
/// The platform plugin keeps one event store built at app launch and gates
/// every read on re-reading the OS authorization status, which on iOS has not
/// caught up at the moment the grant's own completion handler reports
/// success. Reproduced on an iOS 27 simulator: full access granted (the
/// simulator's TCC row reads "allowed"), and `listCalendars` still threw
/// `permissionDenied` — twice in a row, so not a one-frame race.
///
/// What made it user-visible was not the refusal but where it went.
/// `resolveTargetCalendarId` let it escape, past the settings toggle's own
/// "no target, leave the switch off" branch and out of the button handler,
/// so it landed as an unhandled exception with the switch still off and
/// nothing said. These tests pin that it now resolves to null instead.
@GenerateMocks([DeviceCalendarPlusPlatform])
void main() {
  late _FakeDeviceCalendarPlatform fakePlatform;
  late CalendarService service;

  setUp(() {
    fakePlatform = _FakeDeviceCalendarPlatform();
    DeviceCalendarPlusPlatform.instance = fakePlatform;
    service = CalendarService();
  });

  const permissionDenied = DeviceCalendarException(
    errorCode: DeviceCalendarError.permissionDenied,
    message: 'Calendar permission denied. Call requestPermissions() first.',
  );

  /// The platform layer hands back raw maps; `DeviceCalendar` is what turns
  /// them into [Calendar]s. Faking the platform therefore means returning
  /// the map shape `Calendar.fromMap` expects, not a built object.
  Map<String, dynamic> calendarMap({
    required String id,
    required String name,
    bool readOnly = false,
    bool isPrimary = false,
  }) => <String, dynamic>{
    'id': id,
    'name': name,
    'readOnly': readOnly,
    'isPrimary': isPrimary,
  };

  test(
    'a refused calendar list resolves to no target rather than throwing — '
    'the toggle can only leave the switch off if it gets an answer back',
    () async {
      when(fakePlatform.listCalendars()).thenThrow(permissionDenied);

      await expectLater(service.resolveTargetCalendarId(), completion(isNull));
      expect(
        service.targetCalendarId,
        isNull,
        reason: 'nothing was resolved, so nothing should be remembered',
      );
    },
  );

  test(
    'a transient stale-permission refusal is retried once and then resolves',
    () async {
      var listCalls = 0;
      when(fakePlatform.listCalendars()).thenAnswer((_) async {
        listCalls++;
        if (listCalls == 1) throw permissionDenied;
        return [calendarMap(id: 'cal-1', name: 'PlanFit')];
      });

      await expectLater(service.resolveTargetCalendarId(), completion('cal-1'));
      expect(listCalls, 2);
      expect(service.targetCalendarId, 'cal-1');
    },
  );

  test('it never tries to create a calendar off the back of a refused read — '
      'that would ask the same blocked plugin to write', () async {
    when(fakePlatform.listCalendars()).thenThrow(permissionDenied);

    await service.resolveTargetCalendarId();

    verifyNever(fakePlatform.createCalendar(any, any, any));
  });

  test('a refusal on the fallback read is caught too — creation failing '
      'because of the same stale permission would otherwise throw from '
      'inside the catch block that was handling it', () async {
    // Nothing named PlanFit exists, so it moves on to create one...
    var listCalls = 0;
    when(fakePlatform.listCalendars()).thenAnswer((_) async {
      listCalls++;
      if (listCalls == 1) return <Map<String, dynamic>>[];
      throw permissionDenied;
    });
    // ...creation fails, and the fallback read is then refused.
    when(
      fakePlatform.createCalendar(any, any, any),
    ).thenThrow(permissionDenied);

    await expectLater(service.resolveTargetCalendarId(), completion(isNull));
    expect(listCalls, 2, reason: 'the fallback read was reached');
  });

  test('a working permission still resolves normally — the guard must not '
      'swallow the ordinary path', () async {
    when(
      fakePlatform.listCalendars(),
    ).thenAnswer((_) async => [calendarMap(id: 'cal-1', name: 'PlanFit')]);

    await expectLater(service.resolveTargetCalendarId(), completion('cal-1'));
    expect(service.targetCalendarId, 'cal-1');
  });

  test(
    'an unrelated failure is still reported, not quietly turned into null — '
    'only the permission case has a known-good story for continuing',
    () async {
      when(fakePlatform.listCalendars()).thenThrow(StateError('boom'));

      await expectLater(
        service.resolveTargetCalendarId(),
        throwsA(isA<StateError>()),
      );
    },
  );
}
