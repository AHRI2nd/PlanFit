import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../db/event_row_x.dart';
import '../db/todo_row_x.dart';
import '../time/timezone_setup.dart';
import '../../features/schedule/domain/ports.dart';
import '../../l10n/app_localizations.dart';
import 'notification_window.dart';

/// The exact `SharedPreferences` key `SettingsController` persists
/// `AppSettings.languageOverride` under — duplicated here (rather than
/// imported) since `settings_controller.dart` sits in the settings
/// feature's own layer, and this file has to stay reachable from a
/// background isolate that never touches Riverpod/that layer at all (see
/// [_l10n]'s own doc). A plain string constant, not a real dependency,
/// so this is the lowest-friction way to stay in sync with it.
const String _kLanguageOverridePrefsKey = 'settings.languageOverride';

/// `PlatformDispatcher.instance.locale`, not `Localizations.localeOf` — this
/// file's own strings (the notification channel name shown in system
/// settings, the snooze action label, a title-less event/to-do's fallback
/// title) reach both `NotificationService`'s own methods and a background
/// isolate's top-level `handleNotificationAction`/
/// `_onBackgroundNotificationResponse` (a real notification action tap with
/// the app fully terminated), neither of which has a `BuildContext` to read
/// `AppLocalizations.of(context)` from. `lookupAppL10n` is the generated
/// l10n package's own context-free locale lookup (falls back to its
/// `AppL10n` default — currently `ko`, the template arb — for a locale we
/// don't ship a translation for), so this resolves every supported locale's
/// real translated string instead of a hand-rolled binary ko/other ternary
/// that silently stopped being correct the moment a third locale (`ja`) was
/// added. Same underlying reasoning `holiday_calendar_service.dart`'s
/// `defaultHolidayCountryCode` documents for the same context-free
/// constraint.
///
/// [languageOverride] — [AppSettings.languageOverride] — takes priority over
/// the device's own OS locale when given, so this file's strings agree with
/// whatever the user actually sees on screen (via `MaterialApp.locale` in
/// app.dart) rather than the device's locale, the moment those two diverge.
/// Every call site inside [NotificationService] itself passes its own
/// [NotificationService.languageOverride] instance field (kept in sync by
/// `SettingsController._apply`, the same way [NotificationService
/// .soundEnabled] already is); [handleNotificationAction] has no
/// [NotificationService] instance to read that field from (a background
/// isolate's snooze re-fire builds its own bare plugin — see that
/// function's own doc), so it resolves the override itself, straight out of
/// `SharedPreferences`, before calling in here.
///
/// [lookupAppL10n] itself does **not** fall back for a language we don't
/// ship a translation for — it throws. `languageOverride` is always one of
/// [AppL10n.supportedLocales] (the settings screen only offers those), but
/// `PlatformDispatcher.instance.locale` is the device's raw OS locale,
/// unfiltered by Flutter's own `supportedLocales` resolution the way
/// `Localizations.localeOf(context)` would be — so a device set to French,
/// German, Chinese, or anything else outside {en, ja, ko} reached
/// `lookupAppL10n` directly and crashed the very first notification-related
/// call (`init`, which builds the Darwin snooze-action label synchronously).
/// Resolving down to a supported locale first, the same way MaterialApp's
/// own resolution effectively would, is what actually delivers the "falls
/// back" behavior this doc used to just assert.
AppL10n _l10n({String? languageOverride}) =>
    lookupAppL10n(_resolveSupportedLocale(languageOverride));

Locale _resolveSupportedLocale(String? languageOverride) {
  final locale = languageOverride != null
      ? Locale(languageOverride)
      : PlatformDispatcher.instance.locale;
  for (final supported in AppL10n.supportedLocales) {
    if (supported.languageCode == locale.languageCode) return supported;
  }
  return const Locale('en');
}

/// Wraps `flutter_local_notifications` and implements the [NotificationPort]
/// the event repository drives. An event (or a to-do — see
/// `TodoAlertX.reminderOffsets`) can have more than one reminder; each
/// offset gets its own notification, keyed by a stable hash of (id, offset),
/// so scheduling is naturally idempotent (re-scheduling replaces the
/// previous alert for that same offset) and any offset the user removes
/// gets its own notification canceled without disturbing the others.
class NotificationService implements NotificationPort {
  NotificationService({this.soundEnabled = true, this.languageOverride});

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Whether notifications play a sound. Flipped from settings.
  bool soundEnabled;

  /// [AppSettings.languageOverride] — kept in sync by
  /// `SettingsController._apply`, the same way [soundEnabled] already is.
  /// Threaded into every [_l10n] call this instance makes so a scheduled
  /// notification's channel name/snooze label/fallback title agree with
  /// whatever language the user actually sees on screen, not the device's
  /// own OS locale, the moment the two diverge — see [_l10n]'s own doc.
  String? languageOverride;
  bool _initialized = false;

  /// Fired on every response `init()`'s `onDidReceiveNotificationResponse`
  /// receives — a plain tap included, unlike [handleNotificationAction]
  /// (below), which only ever acts on the snooze action and is deliberately
  /// left alone (it's also invoked from a background isolate with no
  /// BuildContext/Riverpod access, so navigation can't live there). Wired by
  /// `_PlanFitAppState` to resolve the payload and open the right
  /// event/to-do — see its `_handleNotificationTap`.
  void Function(NotificationResponse response)? onTap;

  static const String _channelId = 'planfit_events';
  static String _channelName({String? languageOverride}) =>
      _l10n(languageOverride: languageOverride).notificationChannelName;
  static String _channelDescription({String? languageOverride}) => _l10n(
    languageOverride: languageOverride,
  ).notificationChannelDescription;

  /// Action/category ids shared with the top-level background handler below
  /// — a "5 minutes from now" snooze that re-fires the same notification
  /// without opening the app (`showsUserInterface`/foreground default to
  /// false on both platforms).
  static const String snoozeActionId = 'snooze';
  static const String _categoryId = 'planfit_event';
  static String snoozeLabel({String? languageOverride}) =>
      _l10n(languageOverride: languageOverride).notificationSnoozeLabel;
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
            DarwinNotificationAction.plain(
              snoozeActionId,
              snoozeLabel(languageOverride: languageOverride),
            ),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) {
        handleNotificationAction(response, _plugin);
        onTap?.call(response);
      },
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

  /// Whether the app was launched (cold start) by tapping a notification,
  /// and if so, the response that launch carried — `init()` must have run
  /// first (the plugin has to be initialized to answer this). Used by
  /// `_PlanFitAppState`'s own cold-start check, since a tap while the app
  /// was fully terminated arrives here instead of through `onTap`.
  Future<NotificationAppLaunchDetails?> launchDetails() =>
      _plugin.getNotificationAppLaunchDetails();

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
      _channelName(languageOverride: languageOverride),
      channelDescription: _channelDescription(
        languageOverride: languageOverride,
      ),
      importance: Importance.high,
      priority: Priority.high,
      playSound: soundEnabled,
      actions: [
        AndroidNotificationAction(
          snoozeActionId,
          snoozeLabel(languageOverride: languageOverride),
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

  /// Same as [_details] minus the snooze action — a to-do notification does
  /// carry a payload now (see [scheduleForTodo], for tap-to-open), but
  /// there's still nothing for a background isolate to re-arm *from* without
  /// DB access the way an event's snooze does, so that button stays event-only.
  NotificationDetails _todoDetails() {
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName(languageOverride: languageOverride),
      channelDescription: _channelDescription(
        languageOverride: languageOverride,
      ),
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

  /// What should happen for one (event, offset) pair — schedule at
  /// [alertAt], or cancel if [alertAt] is null — without touching the
  /// plugin. Shared by [scheduleForEvent] and [refillEvents] so the "is this
  /// offset selected, in the future, inside the window" judgment lives in
  /// exactly one place.
  ({int id, DateTime? alertAt}) _decideEvent(
    EventRow event,
    int offset,
    DateTime now,
  ) {
    final id = notificationId(event.id, offset);
    final alertAt = event.startAt.subtract(Duration(minutes: offset));
    // In the fixed menu but not selected for this event, already past, or
    // beyond the near-term scheduling window (see
    // notificationSchedulingWindow's doc — CalendarReconciler's refill picks
    // it up once it rolls closer) all mean "make sure this one specific id
    // isn't lingering scheduled".
    final shouldSchedule =
        event.reminderOffsets.contains(offset) &&
        alertAt.isAfter(now) &&
        alertAt.isBefore(now.add(notificationSchedulingWindow));
    return (id: id, alertAt: shouldSchedule ? alertAt : null);
  }

  Future<void> _applyEvent({
    required int id,
    required DateTime? alertAt,
    required EventRow event,
    required AndroidScheduleMode mode,
  }) {
    if (alertAt == null) return _plugin.cancel(id: id);
    final title = event.title.isEmpty
        ? _l10n(
            languageOverride: languageOverride,
          ).notificationEventFallbackTitle
        : event.title;
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: event.memo,
      scheduledDate: TimezoneSetup.toLocal(alertAt),
      notificationDetails: _details(),
      androidScheduleMode: mode,
      // Structured (not just the bare event id) so the snooze handler below
      // — which, on a background isolate, has no DB access — can re-post
      // the same notification without needing to read anything back out.
      // Carries this exact id (not just the event id) so a snooze always
      // re-arms the same offset's slot, never a different reminder's.
      // alertAtMillis lets refillEvents tell "already correctly scheduled"
      // apart from "needs updating" without re-issuing this call to find
      // out — see that method's doc.
      payload: jsonEncode({
        'eventId': event.id,
        'notificationId': id,
        'title': title,
        'body': event.memo,
        'alertAtMillis': alertAt.millisecondsSinceEpoch,
      }),
    );
  }

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

    for (final offset in reminderOffsetOptions) {
      final (:id, :alertAt) = _decideEvent(event, offset, now);
      await _applyEvent(id: id, alertAt: alertAt, event: event, mode: mode);
    }
  }

  /// Bulk counterpart to [scheduleForEvent], for `CalendarReconciler`'s
  /// foreground-resume refill — every event whose reminders might need
  /// (re)arming in the current window, not just one that was just edited.
  ///
  /// A plain loop of [scheduleForEvent] calls here would, for a user with
  /// ~30 events carrying reminders in the 60-day window, issue
  /// `canScheduleExact()` once per event (the answer can't change between
  /// them within one pass) and a `zonedSchedule`/`cancel` platform call for
  /// every one of their offsets regardless of whether that offset's alert
  /// time actually changed since the last refill — on the order of 200+
  /// platform-channel round trips on every single app resume, almost all of
  /// them re-doing unchanged work. This instead reads what's actually
  /// pending once, diffs each offset's *computed* alert time against its
  /// *pending* one (carried in the payload — see [_applyEvent]'s `payload`),
  /// and only calls the plugin for an id whose target state actually
  /// changed.
  ///
  /// A pending id with a payload that fails to decode, or that's missing
  /// `alertAtMillis` (e.g. scheduled by an older app version before this
  /// field existed), is treated as "unknown" rather than "unchanged" —
  /// falls through to being rescheduled, same as if nothing were pending.
  /// Never wrong, just occasionally not the optimization, and only for one
  /// release's worth of already-scheduled notifications.
  @override
  Future<void> refillEvents(List<EventRow> events) async {
    await init();
    final exact = await canScheduleExact();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = DateTime.now();

    final pending = await _plugin.pendingNotificationRequests();
    final pendingAlertById = <int, DateTime>{};
    for (final p in pending) {
      final payload = p.payload;
      if (payload == null) continue;
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final millis = data['alertAtMillis'] as int?;
        if (millis != null) {
          pendingAlertById[p.id] = DateTime.fromMillisecondsSinceEpoch(millis);
        }
      } catch (_) {
        // Not one of ours, or an old payload shape — leave unmapped so the
        // id below falls through to "unknown, reschedule to be sure".
      }
    }

    for (final event in events) {
      for (final offset in reminderOffsetOptions) {
        final (:id, :alertAt) = _decideEvent(event, offset, now);
        final alreadyCorrect = alertAt == null
            ? !pendingAlertById.containsKey(id)
            : pendingAlertById[id] == alertAt;
        if (alreadyCorrect) continue;
        await _applyEvent(id: id, alertAt: alertAt, event: event, mode: mode);
      }
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
    final title = todo.title.isEmpty
        ? _l10n(
            languageOverride: languageOverride,
          ).notificationTodoFallbackTitle
        : todo.title;

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
        // Same shape as _applyEvent's payload (minus body, which to-do
        // notifications never set) — lets a plain tap on this notification
        // resolve back to the to-do it's for and open it, the same way an
        // event notification's payload already does.
        payload: jsonEncode({
          'todoId': todo.id,
          'notificationId': id,
          'title': title,
          'alertAtMillis': alertAt.millisecondsSinceEpoch,
        }),
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
  // No NotificationService instance exists on this background isolate to
  // read AppSettings.languageOverride's already-synced value off of (see
  // NotificationService.languageOverride's own doc) — read the persisted
  // setting straight out of SharedPreferences instead, the same way
  // TimezoneSetup.init() above stands up its own state from scratch rather
  // than relying on anything the foreground app already initialized.
  final prefs = await SharedPreferences.getInstance();
  final languageOverride = prefs.getString(_kLanguageOverridePrefsKey);
  final android = AndroidNotificationDetails(
    NotificationService._channelId,
    NotificationService._channelName(languageOverride: languageOverride),
    channelDescription: NotificationService._channelDescription(
      languageOverride: languageOverride,
    ),
    importance: Importance.high,
    priority: Priority.high,
    actions: [
      AndroidNotificationAction(
        NotificationService.snoozeActionId,
        NotificationService.snoozeLabel(languageOverride: languageOverride),
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
    title:
        data['title'] as String? ??
        _l10n(languageOverride: languageOverride).notificationEventFallbackTitle,
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
