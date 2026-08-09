import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../db/app_database.dart';
import '../db/event_row_x.dart';
import '../db/todo_row_x.dart';
import '../time/timezone_setup.dart';
import '../../features/schedule/domain/ports.dart';
import 'notification_window.dart';

/// Wraps `flutter_local_notifications` and implements the [NotificationPort]
/// the event repository drives. An event (or a to-do — see
/// `TodoAlertX.reminderOffsets`) can have more than one reminder; each
/// offset gets its own notification, keyed by a stable hash of (id, offset),
/// so scheduling is naturally idempotent (re-scheduling replaces the
/// previous alert for that same offset) and any offset the user removes
/// gets its own notification canceled without disturbing the others.
class NotificationService implements NotificationPort {
  NotificationService({this.soundEnabled = true});

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Whether notifications play a sound. Flipped from settings.
  bool soundEnabled;
  bool _initialized = false;

  static const String _channelId = 'planfit_events';
  static const String _channelName = '일정 알림';
  static const String _channelDescription = '일정이 시작될 때 알려드려요';

  /// Action/category ids shared with the top-level background handler below
  /// — a "5 minutes from now" snooze that re-fires the same notification
  /// without opening the app (`showsUserInterface`/foreground default to
  /// false on both platforms).
  static const String snoozeActionId = 'snooze';
  static const String _categoryId = 'planfit_event';
  static const String snoozeLabel = '5분 뒤 다시 알림';
  static const Duration snoozeDuration = Duration(minutes: 5);

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      // We request explicitly later so the prompt lands at a sensible moment.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _categoryId,
          actions: [
            DarwinNotificationAction.plain(snoozeActionId, snoozeLabel),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) =>
          handleNotificationAction(response, _plugin),
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Requests the OS notification permission (Android 13+, iOS). Returns whether
  /// it was granted.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      return await _ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Whether the app can post exact-time alarms (Android 12+). iOS has no
  /// equivalent gate, so it's always true there.
  Future<bool> canScheduleExact() async {
    if (!kIsWeb && Platform.isAndroid) {
      return await _android?.canScheduleExactNotifications() ?? false;
    }
    return true;
  }

  /// Sends the user to system settings to grant the exact-alarm permission.
  Future<bool> requestExactAlarmPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      return await _android?.requestExactAlarmsPermission() ?? false;
    }
    return true;
  }

  NotificationDetails _details() {
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: soundEnabled,
      actions: const [
        AndroidNotificationAction(
          snoozeActionId,
          snoozeLabel,
          showsUserInterface: false,
        ),
      ],
    );
    final darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundEnabled,
      categoryIdentifier: _categoryId,
    );
    return NotificationDetails(android: android, iOS: darwin);
  }

  /// Same as [_details] minus the snooze action — a to-do notification
  /// carries no payload (nothing to re-arm from a background isolate with no
  /// DB access), so showing that button would be dead UI.
  NotificationDetails _todoDetails() {
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: soundEnabled,
    );
    final darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundEnabled,
    );
    return NotificationDetails(android: android, iOS: darwin);
  }

  /// Every reminder lead time the editor offers — for both events and
  /// to-dos, the fixed, small menu users pick offsets from (never free-form
  /// input), which is exactly what makes per-offset notification ids safe to
  /// manage without tracking history: on every schedule/cancel call, every
  /// id in this whole list is visited, so an offset the user just removed
  /// still gets its stale notification canceled even though it's no longer
  /// in the row's own `reminderOffsets`.
  static const List<int> reminderOffsetOptions = [0, 5, 10, 30, 60, 1440];

  /// Stable positive 31-bit id derived from the event's uuid and which
  /// reminder offset this is — so one event's several reminders each get
  /// their own independent notification.
  static int notificationId(String eventId, int offsetMinutes) =>
      '$eventId#$offsetMinutes'.hashCode & 0x7fffffff;

  @override
  Future<void> scheduleForEvent(EventRow event) async {
    await init();
    // Fall back to inexact scheduling when the exact-alarm permission is not
    // held — never block the alert entirely on that permission.
    final exact = await canScheduleExact();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = DateTime.now();
    final selected = event.reminderOffsets.toSet();
    final title = event.title.isEmpty ? '일정' : event.title;

    for (final offset in reminderOffsetOptions) {
      final id = notificationId(event.id, offset);
      final alertAt = event.startAt.subtract(Duration(minutes: offset));
      // Each offset is judged on its own: in the fixed menu but not
      // selected for this event, already past, or beyond the near-term
      // scheduling window (see notificationSchedulingWindow's doc —
      // CalendarReconciler's refill picks it up once it rolls closer) all
      // mean "make sure this one specific id isn't lingering scheduled".
      if (!selected.contains(offset) ||
          !alertAt.isAfter(now) ||
          !alertAt.isBefore(now.add(notificationSchedulingWindow))) {
        await _plugin.cancel(id: id);
        continue;
      }
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: event.memo,
        scheduledDate: TimezoneSetup.toLocal(alertAt),
        notificationDetails: _details(),
        androidScheduleMode: mode,
        // Structured (not just the bare event id) so the snooze handler
        // below — which, on a background isolate, has no DB access — can
        // re-post the same notification without needing to read anything
        // back out. Carries this exact id (not just the event id) so a
        // snooze always re-arms the same offset's slot, never a different
        // reminder's.
        payload: jsonEncode({
          'eventId': event.id,
          'notificationId': id,
          'title': title,
          'body': event.memo,
        }),
      );
    }
  }

  @override
  Future<void> cancelForEvent(String eventId) async {
    await init();
    for (final offset in reminderOffsetOptions) {
      await _plugin.cancel(id: notificationId(eventId, offset));
    }
  }

  /// Stable positive 31-bit id derived from the to-do's uuid and which
  /// reminder offset this is — namespaced (`todo#...` vs `notificationId`'s
  /// `eventId#offset`) so a to-do and an event can never collide on the
  /// same notification id even by coincidence, and so one to-do's several
  /// reminders each get their own independent notification (mirrors
  /// [notificationId]).
  static int todoNotificationId(String todoId, int offsetMinutes) =>
      'todo#$todoId#$offsetMinutes'.hashCode & 0x7fffffff;

  @override
  Future<void> scheduleForTodo(TodoRow todo) async {
    await init();
    final exact = await canScheduleExact();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = DateTime.now();
    final selected = todo.reminderOffsets.toSet();
    final title = todo.title.isEmpty ? '할 일' : todo.title;

    for (final offset in reminderOffsetOptions) {
      final id = todoNotificationId(todo.id, offset);
      final alertAt = todo.slotStart.subtract(Duration(minutes: offset));
      // Same "in the fixed menu but is it actually selected/due/in-window"
      // judgment as scheduleForEvent, per offset.
      if (!todo.notify ||
          !todo.hasTime ||
          !selected.contains(offset) ||
          !alertAt.isAfter(now) ||
          !alertAt.isBefore(now.add(notificationSchedulingWindow))) {
        await _plugin.cancel(id: id);
        continue;
      }
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: null,
        scheduledDate: TimezoneSetup.toLocal(alertAt),
        notificationDetails: _todoDetails(),
        androidScheduleMode: mode,
      );
    }
  }

  @override
  Future<void> cancelForTodo(String todoId) async {
    await init();
    for (final offset in reminderOffsetOptions) {
      await _plugin.cancel(id: todoNotificationId(todoId, offset));
    }
  }
}

/// Runs on a background isolate (app backgrounded or fully terminated) when
/// the user taps the snooze action without launching the app — must be a
/// top-level function annotated `@pragma('vm:entry-point')` so the compiler
/// doesn't strip it, and can't capture any [NotificationService] instance
/// state, so it stands up its own fresh plugin + timezone database before
/// rescheduling.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  handleNotificationAction(response, FlutterLocalNotificationsPlugin());
}

/// Shared by both the foreground and background callbacks — re-posts the
/// same notification [snoozeDuration] from now, keyed by the same stable id
/// so it replaces rather than duplicates. Anything other than the snooze
/// action (a plain tap, or an unrecognized action) is left for the OS's
/// default "open the app" handling and ignored here.
@visibleForTesting
Future<void> handleNotificationAction(
  NotificationResponse response,
  FlutterLocalNotificationsPlugin plugin,
) async {
  if (response.actionId != NotificationService.snoozeActionId) return;
  final payload = response.payload;
  if (payload == null) return;

  final Map<String, dynamic> data;
  try {
    data = jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return;
  }
  final eventId = data['eventId'] as String?;
  if (eventId == null) return;
  // Falls back to the offset-0 id for a payload scheduled before this field
  // existed (an app update landing between scheduling and the snooze tap) —
  // matches the single-notification-per-event behavior that predates
  // multiple reminders.
  final notificationId =
      data['notificationId'] as int? ??
      NotificationService.notificationId(eventId, 0);

  await TimezoneSetup.init();
  final android = AndroidNotificationDetails(
    NotificationService._channelId,
    NotificationService._channelName,
    channelDescription: NotificationService._channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    actions: const [
      AndroidNotificationAction(
        NotificationService.snoozeActionId,
        NotificationService.snoozeLabel,
        showsUserInterface: false,
      ),
    ],
  );
  const darwin = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    categoryIdentifier: NotificationService._categoryId,
  );

  // Same exact-vs-inexact fallback as NotificationService.scheduleForEvent,
  // just resolved directly against the passed-in plugin instance since a
  // background isolate has no NotificationService of its own to ask.
  var exact = true;
  if (!kIsWeb && Platform.isAndroid) {
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    exact = await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  await plugin.zonedSchedule(
    id: notificationId,
    title: data['title'] as String? ?? '일정',
    body: data['body'] as String?,
    scheduledDate: TimezoneSetup.toLocal(
      DateTime.now().add(NotificationService.snoozeDuration),
    ),
    notificationDetails: NotificationDetails(android: android, iOS: darwin),
    androidScheduleMode: exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
    payload: payload,
  );
}
