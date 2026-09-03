import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart';

import 'notification_service_test.mocks.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFlutterLocalNotificationsPlugin plugin;

  setUp(() {
    // handleNotificationAction now reads AppSettings.languageOverride
    // straight out of SharedPreferences (see its own doc — no
    // NotificationService instance exists on the background isolate it
    // simulates) — nothing persisted here means it resolves the same as
    // before this existed (falls through to the device locale).
    SharedPreferences.setMockInitialValues({});
    plugin = MockFlutterLocalNotificationsPlugin();
    when(
      plugin.zonedSchedule(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: anyNamed('payload'),
      ),
    ).thenAnswer((_) async {});
  });

  NotificationResponse response({String? actionId, String? payload}) {
    return NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      actionId: actionId,
      payload: payload,
    );
  }

  test('does nothing for a plain tap (no action id) — left for the default '
      'open-the-app handling', () async {
    await handleNotificationAction(
      response(
        payload: jsonEncode({'eventId': 'e1', 'title': 'x', 'body': null}),
      ),
      plugin,
    );

    verifyNever(
      plugin.zonedSchedule(
        id: anyNamed('id'),
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
      ),
    );
  });

  test('does nothing for an unrelated action id', () async {
    await handleNotificationAction(
      response(
        actionId: 'something_else',
        payload: jsonEncode({'eventId': 'e1'}),
      ),
      plugin,
    );

    verifyNever(
      plugin.zonedSchedule(
        id: anyNamed('id'),
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
      ),
    );
  });

  test('does nothing when the payload is missing or malformed', () async {
    await handleNotificationAction(
      response(actionId: NotificationService.snoozeActionId, payload: null),
      plugin,
    );
    await handleNotificationAction(
      response(
        actionId: NotificationService.snoozeActionId,
        payload: 'not json',
      ),
      plugin,
    );

    verifyNever(
      plugin.zonedSchedule(
        id: anyNamed('id'),
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
      ),
    );
  });

  test(
    're-schedules the same notification id ~5 minutes out on snooze',
    () async {
      final before = DateTime.now();
      await handleNotificationAction(
        response(
          actionId: NotificationService.snoozeActionId,
          payload: jsonEncode({
            'eventId': 'e42',
            'title': 'Standup',
            'body': 'Daily sync',
          }),
        ),
        plugin,
      );

      final captured = verify(
        plugin.zonedSchedule(
          id: captureAnyNamed('id'),
          title: captureAnyNamed('title'),
          body: captureAnyNamed('body'),
          scheduledDate: captureAnyNamed('scheduledDate'),
          notificationDetails: anyNamed('notificationDetails'),
          androidScheduleMode: anyNamed('androidScheduleMode'),
          payload: anyNamed('payload'),
        ),
      ).captured;

      final id = captured[0] as int;
      final title = captured[1] as String?;
      final body = captured[2] as String?;
      final scheduledDate = captured[3] as TZDateTime;

      expect(id, NotificationService.notificationId('e42', 0));
      expect(title, 'Standup');
      expect(body, 'Daily sync');
      final deltaFromNow =
          scheduledDate.difference(before) - NotificationService.snoozeDuration;
      expect(deltaFromNow.inSeconds.abs(), lessThan(5));
    },
  );

  test(
    "re-firing a snooze honors AppSettings.languageOverride's persisted "
    "value, not just the device's own OS locale — regression test: this "
    "used to always read PlatformDispatcher.instance.locale, so a user "
    "whose in-app language differs from their phone's language would get "
    "a channel/snooze label back in the wrong one the moment a snooze "
    "re-fired in the background",
    () async {
      SharedPreferences.setMockInitialValues({
        'settings.languageOverride': 'ja',
      });
      await handleNotificationAction(
        response(
          actionId: NotificationService.snoozeActionId,
          payload: jsonEncode({'eventId': 'e43', 'title': 'Standup'}),
        ),
        plugin,
      );

      final details =
          verify(
                plugin.zonedSchedule(
                  id: anyNamed('id'),
                  title: anyNamed('title'),
                  body: anyNamed('body'),
                  scheduledDate: anyNamed('scheduledDate'),
                  notificationDetails: captureAnyNamed('notificationDetails'),
                  androidScheduleMode: anyNamed('androidScheduleMode'),
                  payload: anyNamed('payload'),
                ),
              ).captured.single
              as NotificationDetails;

      final action = details.android!.actions!.single;
      // Asserted against the literal Japanese string (not just "differs
      // from whatever the no-override default resolves to") so this can't
      // pass by accident depending on the test environment's own default
      // locale.
      expect(action.title, '5分後に再通知');
    },
  );
}
