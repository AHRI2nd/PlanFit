import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// What a tapped notification should navigate to — the pure, synchronous
/// half of `_PlanFitAppState._handleNotificationTap`'s work, pulled out so
/// it's unit-testable without pumping the whole app widget tree (which
/// would drag in every other `initState` side effect: home widget sync,
/// app badge, calendar/reminder reconcilers, auto-backup, holiday sync).
sealed class NotificationTapTarget {
  const NotificationTapTarget();
}

class EventTapTarget extends NotificationTapTarget {
  const EventTapTarget(this.eventId);
  final String eventId;
}

class TodoTapTarget extends NotificationTapTarget {
  const TodoTapTarget(this.todoId);
  final String todoId;
}

/// Parses [response] into what it should navigate to, or `null` if there's
/// nothing to do — a snooze action-button tap (`selectedNotificationAction`,
/// already fully handled by `NotificationService.handleNotificationAction`
/// and must not also navigate), a missing/malformed payload, or a payload
/// with neither `eventId` nor `todoId` (see `NotificationService._applyEvent`
/// / `scheduleForTodo` for the payload shapes this expects). Never throws —
/// every failure mode here is a plain "nothing to navigate to", matching
/// the caller's own best-effort posture.
NotificationTapTarget? parseNotificationTapPayload(
  NotificationResponse response,
) {
  if (response.notificationResponseType !=
      NotificationResponseType.selectedNotification) {
    return null;
  }
  final payload = response.payload;
  if (payload == null) return null;

  Map<String, dynamic> data;
  try {
    data = jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final eventId = data['eventId'] as String?;
  final todoId = data['todoId'] as String?;
  if (eventId != null) return EventTapTarget(eventId);
  if (todoId != null) return TodoTapTarget(todoId);
  return null;
}
