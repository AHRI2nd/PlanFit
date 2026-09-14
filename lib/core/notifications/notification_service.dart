import 'dart:async' show unawaited;
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
import 'notification_id_allocator.dart';
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
  // Not `this._languageOverride`: the named parameter has to stay
  // `languageOverride` — the public name every call site already uses.
  // [plugin] is injectable (real usage never passes it — see the default
  // below) purely so tests can drive this class's own scheduling logic
  // against a mock, the same way `HolidayCalendarService`/`CalendarService`
  // already accept an injectable `http.Client`/rely on their own singleton
  // for the same reason. [notificationIdAllocator] is nullable rather than
  // required so the handful of tests that only exercise
  // [languageOverride]'s own getter/setter bookkeeping (never any actual
  // scheduling) don't need one just to construct this — every real call
  // site (`di.dart`'s `notificationServiceProvider`) always supplies one;
  // see [_allocateEventId]'s own doc for what happens if a scheduling
  // method is somehow reached without it.
  NotificationService({
    this.soundEnabled = true,
    String? languageOverride,
    FlutterLocalNotificationsPlugin? plugin,
    this.notificationIdAllocator,
  })
    // ignore: prefer_initializing_formals
    : _languageOverride = languageOverride,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final NotificationIdAllocator? notificationIdAllocator;

  final FlutterLocalNotificationsPlugin _plugin;

  /// Whether notifications play a sound. Flipped from settings.
  bool soundEnabled;

  /// [AppSettings.languageOverride] — kept in sync by
  /// `SettingsController._apply`, the same way [soundEnabled] already is.
  /// Threaded into every [_l10n] call this instance makes so a scheduled
  /// notification's channel name/snooze label/fallback title agree with
  /// whatever language the user actually sees on screen, not the device's
  /// own OS locale, the moment the two diverge — see [_l10n]'s own doc.
  ///
  /// A plain field until the setter below: Android's snooze-action label is
  /// rebuilt fresh on every notification (see [_details]), but iOS bakes its
  /// snooze label into a [DarwinNotificationCategory] registered once, in
  /// [init]. Without re-registering that category on every actual change,
  /// the iOS snooze button stayed stuck in whichever language was active the
  /// very first time [init] happened to run for this process — permanently,
  /// even after an in-app language switch updated everything else.
  String? get languageOverride => _languageOverride;
  set languageOverride(String? value) {
    if (value == _languageOverride) return;
    _languageOverride = value;
    unawaited(_registerIosSnoozeCategory());
  }

  String? _languageOverride;
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
  static String _channelDescription({String? languageOverride}) =>
      _l10n(languageOverride: languageOverride).notificationChannelDescription;

  /// Action/category ids shared with the top-level background handler below
  /// — a "5 minutes from now" snooze that re-fires the same notification
  /// without opening the app (`showsUserInterface`/foreground default to
  /// false on both platforms).
  static const String snoozeActionId = 'snooze';
  static const String _categoryId = 'planfit_event';
  static String snoozeLabel({String? languageOverride}) =>
      _l10n(languageOverride: languageOverride).notificationSnoozeLabel;
  static const Duration snoozeDuration = Duration(minutes: 5);

  /// [DarwinInitializationSettings], including its notification categories —
  /// shared by [init] and [_registerIosSnoozeCategory] so both build the
  /// category from the exact same [languageOverride]-aware label.
  DarwinInitializationSettings _darwinSettings() {
    return DarwinInitializationSettings(
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
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    handleNotificationAction(response, _plugin);
    onTap?.call(response);
  }

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: InitializationSettings(
        android: android,
        iOS: _darwinSettings(),
      ),
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );
    _initialized = true;
  }

  /// Re-registers the iOS [DarwinNotificationCategory] with a freshly
  /// relabeled snooze action — called whenever [languageOverride] actually
  /// changes after [init] has already run (see that setter's own doc).
  /// [IOSFlutterLocalNotificationsPlugin] has no narrower "just update the
  /// categories" call; re-running `initialize` is the plugin's own
  /// documented way to change them, and since `requestAlertPermission`/
  /// `Badge`/`Sound` stay false here, it doesn't re-prompt for permission.
  /// Passing [_onDidReceiveNotificationResponse] again (rather than
  /// omitting it) matters: the plugin unconditionally overwrites its stored
  /// callback with whatever this call passes, so leaving it out would
  /// silently break notification-tap handling from this point on. Best
  /// effort, like every other platform-channel call in this file — a
  /// failure here just leaves the label stale for a bit longer, not
  /// something worth surfacing to the user.
  Future<void> _registerIosSnoozeCategory() async {
    if (!_initialized || kIsWeb || !Platform.isIOS) return;
    try {
      await _ios?.initialize(
        settings: _darwinSettings(),
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationResponse,
      );
    } on Exception {
      // See doc comment above.
    }
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

  /// How many event alerts [refillEvents] will hold pending at once.
  ///
  /// iOS caps an app at 64 pending local notifications and silently drops
  /// whatever doesn't fit, which [notificationSchedulingWindow] alone does
  /// *not* prevent: that window bounds how far ahead alerts are scheduled,
  /// not how many land inside it. Recurrence is materialized one row per
  /// occurrence, and every row schedules one alert per selected offset from
  /// [reminderOffsetOptions] — so a single daily event with two reminders
  /// is already 120 pending alerts across a 60-day window, before any
  /// to-dos.
  ///
  /// Left unbounded, the overflow doesn't just get dropped once. A dropped
  /// alert never comes back in `pendingNotificationRequests()`, so
  /// [refillEvents]'s "already correctly scheduled" check reads it as
  /// missing and re-issues it — on every single foreground resume, forever,
  /// for an alert the OS will drop again every time. Capping what we ask
  /// for both stops that churn and puts the app, rather than the OS, in
  /// charge of which alerts survive: soonest first, since a reminder for
  /// next week matters more than one for next month that a later refill
  /// will pick up anyway.
  ///
  /// Split with [TodoController.refillNotifications]'s own budget rather
  /// than shared, so neither surface can starve the other — the two refill
  /// independently, on separate passes, with no visibility into what the
  /// other just scheduled. The two together stay under 64 with headroom for
  /// the handful of non-refill alerts (a snooze re-post, a just-saved
  /// event) that can be scheduled between passes.
  static const int maxPendingEventAlerts = 40;

  /// A ~2.1 billion-value hash of the event's uuid and which reminder
  /// offset this is. Used to be the *only* id scheme (see git history) —
  /// with enough distinct ids in play (every event a long-lived install has
  /// ever held, since ids are never reused) the ordinary birthday bound
  /// made an actual collision a real risk, not just a theoretical one: two
  /// different events sharing a numeric id means whichever schedules
  /// second silently overwrites the other's pending alert, and
  /// cancelling/rescheduling one affects both. No hash-quality improvement
  /// fixes this — the birthday bound applies to any hash of a fixed bit
  /// width — so real scheduling now goes through [_allocateEventId]'s
  /// persistent, collision-free mapping instead (see
  /// [NotificationIdAllocator]'s own doc for the full reasoning).
  ///
  /// Kept only as [handleNotificationAction]'s last-resort fallback for a
  /// payload written before `alertAtMillis`'s `notificationId` field
  /// existed (an app update landing between scheduling and a snooze tap) —
  /// a background isolate has no [SharedPreferences] instance of its own
  /// standing by to resolve the real allocated id from (it reads settings
  /// straight out of a fresh one instead, see [handleNotificationAction]'s
  /// own doc — reusing that here would still need this to become async
  /// throughout, for a fallback already this degraded), and this one
  /// narrow, already-degraded case doesn't need to be collision-proof the
  /// way live scheduling does.
  static int notificationId(String eventId, int offsetMinutes) =>
      '$eventId#$offsetMinutes'.hashCode & 0x7fffffff;

  /// The real, collision-free id [eventId]/[offsetMinutes] resolves to —
  /// see [NotificationIdAllocator]'s doc. [notificationIdAllocator] is only
  /// ever null in tests that construct this service without exercising any
  /// scheduling method (see the constructor's own doc); every real path
  /// reaching here always has one.
  int _allocateEventId(String eventId, int offsetMinutes) {
    final allocator = notificationIdAllocator;
    if (allocator == null) {
      throw StateError(
        'NotificationService.scheduleForEvent/refillEvents/cancelForEvent '
        'called without a notificationIdAllocator',
      );
    }
    return allocator.allocate('$eventId#$offsetMinutes');
  }

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
    final id = _allocateEventId(event.id, offset);
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
  ///
  /// [events] is a single DB snapshot the caller (`CalendarReconciler
  /// ._refillNotifications`) already fetched before calling in here —
  /// [notificationIdAllocator] only ever resolves a stable *id* for an
  /// (event, offset) pair (see [_allocateEventId]), it has no way to
  /// re-verify a
  /// row's own live event data (title/notify/reminders) mid-pass the way
  /// `TodoController.refillNotifications` re-fetches from its own event/
  /// to-do DAO. A user editing/deleting/toggling notify off on one of these
  /// events while this call is still in flight for an *earlier* one used to
  /// be genuinely possible: with a plain sequential loop of `await
  /// _applyEvent(...)` calls (one real platform-channel round trip each),
  /// a user with ~30 events could see 200+ of them, spanning enough real
  /// wall-clock time for a concurrent edit to land and then be silently
  /// re-armed anyway by this call's now-stale copy of that event. Dispatching
  /// every still-needed `_applyEvent` call together via [Future.wait] instead
  /// of one at a time shrinks that whole pass to roughly the time of a single
  /// round trip rather than their sum, cutting the exposure window by
  /// roughly a factor of how many calls there are. This doesn't fully close
  /// the race the way the to-do side's re-fetch does — a concurrent edit
  /// could still land in that one shorter window — but it's a large,
  /// self-contained reduction that doesn't require giving this plugin
  /// wrapper its own DB dependency just to re-verify state it was never
  /// meant to own.
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

    // Every (event, offset) slot this pass could touch, split into the ones
    // that want an alert and the ones that want their id cleared. Collected
    // first rather than applied inline so the wanted ones can be ranked
    // against each other before anything is sent to the plugin — see
    // [maxPendingEventAlerts] for why asking for all of them is worse than
    // asking for the soonest few.
    final wanted = <({int id, DateTime alertAt, EventRow event})>[];
    final unwanted = <({int id, EventRow event})>[];
    for (final event in events) {
      for (final offset in reminderOffsetOptions) {
        final (:id, :alertAt) = _decideEvent(event, offset, now);
        if (alertAt == null) {
          unwanted.add((id: id, event: event));
        } else {
          wanted.add((id: id, alertAt: alertAt, event: event));
        }
      }
    }
    wanted.sort((a, b) => a.alertAt.compareTo(b.alertAt));

    final toApply = <Future<void>>[];
    for (final (index, slot) in wanted.indexed) {
      // Past the budget this stops being a request and becomes a cancel:
      // the slot may well be pending from an earlier pass that had room for
      // it, and leaving it there would spend one of the very slots this cap
      // exists to protect.
      final alertAt = index < maxPendingEventAlerts ? slot.alertAt : null;
      final alreadyCorrect = alertAt == null
          ? !pendingAlertById.containsKey(slot.id)
          : pendingAlertById[slot.id] == alertAt;
      if (alreadyCorrect) continue;
      toApply.add(
        _applyEvent(
          id: slot.id,
          alertAt: alertAt,
          event: slot.event,
          mode: mode,
        ),
      );
    }
    for (final slot in unwanted) {
      if (!pendingAlertById.containsKey(slot.id)) continue;
      toApply.add(
        _applyEvent(id: slot.id, alertAt: null, event: slot.event, mode: mode),
      );
    }
    await Future.wait(toApply);
  }

  @override
  Future<void> cancelForEvent(String eventId) async {
    await init();
    for (final offset in reminderOffsetOptions) {
      await _plugin.cancel(id: _allocateEventId(eventId, offset));
    }
  }

  /// A ~2.1 billion-value hash of the to-do's uuid and which reminder
  /// offset this is — namespaced (`todo#...` vs [notificationId]'s
  /// `eventId#offset`) so a to-do and an event never shared a hash-derived
  /// id even by coincidence. Same collision risk, and same "kept only as a
  /// last-resort fallback, real scheduling uses [_allocateTodoId] instead"
  /// status, as [notificationId] — see that field's own doc.
  static int todoNotificationId(String todoId, int offsetMinutes) =>
      'todo#$todoId#$offsetMinutes'.hashCode & 0x7fffffff;

  /// The real, collision-free id [todoId]/[offsetMinutes] resolves to — see
  /// [_allocateEventId]'s own doc (same reasoning, own namespace so a
  /// to-do and an event never share an allocated id either).
  int _allocateTodoId(String todoId, int offsetMinutes) {
    final allocator = notificationIdAllocator;
    if (allocator == null) {
      throw StateError(
        'NotificationService.scheduleForTodo/cancelForTodo called without '
        'a notificationIdAllocator',
      );
    }
    return allocator.allocate('todo#$todoId#$offsetMinutes');
  }

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
      final id = _allocateTodoId(todo.id, offset);
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
      await _plugin.cancel(id: _allocateTodoId(todoId, offset));
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
        _l10n(
          languageOverride: languageOverride,
        ).notificationEventFallbackTitle,
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
