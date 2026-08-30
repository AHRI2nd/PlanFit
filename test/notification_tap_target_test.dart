import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/notifications/notification_tap_target.dart';

void main() {
  NotificationResponse response({
    NotificationResponseType type =
        NotificationResponseType.selectedNotification,
    String? payload,
  }) {
    return NotificationResponse(
      notificationResponseType: type,
      payload: payload,
    );
  }

  test('a snooze action-button tap is ignored even with a valid event payload '
      '— handleNotificationAction already owns that response type', () {
    final target = parseNotificationTapPayload(
      response(
        type: NotificationResponseType.selectedNotificationAction,
        payload: jsonEncode({'eventId': 'e1'}),
      ),
    );

    expect(target, isNull);
  });

  test('a null payload resolves to nothing', () {
    expect(parseNotificationTapPayload(response(payload: null)), isNull);
  });

  test('a malformed (non-JSON) payload resolves to nothing', () {
    expect(parseNotificationTapPayload(response(payload: 'not json')), isNull);
  });

  test('a payload with neither eventId nor todoId resolves to nothing', () {
    final target = parseNotificationTapPayload(
      response(payload: jsonEncode({'title': 'x'})),
    );

    expect(target, isNull);
  });

  test('a payload with eventId resolves to an EventTapTarget', () {
    final target = parseNotificationTapPayload(
      response(payload: jsonEncode({'eventId': 'e1', 'title': 'x'})),
    );

    expect(target, isA<EventTapTarget>());
    expect((target as EventTapTarget).eventId, 'e1');
  });

  test('a payload with todoId resolves to a TodoTapTarget', () {
    final target = parseNotificationTapPayload(
      response(payload: jsonEncode({'todoId': 't1', 'title': 'x'})),
    );

    expect(target, isA<TodoTapTarget>());
    expect((target as TodoTapTarget).todoId, 't1');
  });
}
