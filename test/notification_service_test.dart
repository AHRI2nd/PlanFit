import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
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
        'settings.languageOverride': 'ko',
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
      // Asserted against the literal Korean string (not just "differs
      // from whatever the no-override default resolves to") so this can't
      // pass by accident depending on the test environment's own default
      // locale. Was 'ja'/"5分後に再通知" until Japanese app-language
      // support was paused (see l10n_disabled/README.md) — 'ko' proves
      // the same "override wins over device locale" point just as well.
      expect(action.title, '5분 뒤 다시 알림');
    },
  );

  test(
    "falls back to English instead of crashing for a languageOverride/OS "
    "locale outside {en, ja, ko} — regression test: lookupAppL10n itself "
    "throws for an unrecognized language code (it has no built-in "
    "fallback, despite this file's own doc previously claiming one), so "
    "any device set to French, German, Chinese, or anything else outside "
    "the 3 shipped locales used to crash on the very first notification "
    "call",
    () async {
      SharedPreferences.setMockInitialValues({
        'settings.languageOverride': 'fr',
      });

      await expectLater(
        handleNotificationAction(
          response(
            actionId: NotificationService.snoozeActionId,
            payload: jsonEncode({'eventId': 'e44', 'title': 'Standup'}),
          ),
          plugin,
        ),
        completes,
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
      expect(action.title, 'Remind me in 5 min');
    },
  );

  group('NotificationService.languageOverride setter', () {
    // The iOS re-registration path this setter drives only runs on an
    // actual iOS platform/plugin binding — so, like
    // `defaultHolidayCountryCode()`'s own established precedent, the deeper
    // "did the plugin actually get re-initialized with a fresh label"
    // behavior can't be exercised from a host-run test even with the
    // plugin now injectable (see the constructor's own doc). What *is*
    // testable here: the setter's own bookkeeping doesn't throw or misbehave
    // regardless of init/platform state, which is what every call site
    // (SettingsController._apply, on every settings change) actually
    // depends on.
    test('updates the getter and is a safe no-op before init() has run', () {
      final service = NotificationService(languageOverride: 'en');
      expect(service.languageOverride, 'en');

      service.languageOverride = 'ko';
      expect(service.languageOverride, 'ko');
    });

    test('setting the same value again is a true no-op', () {
      final service = NotificationService(languageOverride: 'ko');

      // Should not throw, and should leave the value exactly as it was —
      // guards the `if (value == _languageOverride) return;` early-out.
      service.languageOverride = 'ko';
      expect(service.languageOverride, 'ko');
    });
  });

  group('NotificationService.refillEvents', () {
    // Round-4 audit: refillEvents used to dispatch its per-(event, offset)
    // _applyEvent calls one at a time in a plain sequential loop, spending
    // real wall-clock time (one platform-channel round trip per call) that
    // a concurrent edit could land inside and go unnoticed until this whole
    // pass finished — see refillEvents' own doc comment. Fixed by batching
    // every still-needed call through Future.wait instead. These tests
    // confirm that change didn't alter *which* calls get made or their
    // net effect, only that they now fire together rather than one by one.
    late NotificationService service;

    setUp(() {
      when(
        plugin.initialize(
          settings: anyNamed('settings'),
          onDidReceiveNotificationResponse: anyNamed(
            'onDidReceiveNotificationResponse',
          ),
          onDidReceiveBackgroundNotificationResponse: anyNamed(
            'onDidReceiveBackgroundNotificationResponse',
          ),
        ),
      ).thenAnswer((_) async => true);
      when(
        plugin.pendingNotificationRequests(),
      ).thenAnswer((_) async => const []);
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
      when(plugin.cancel(id: anyNamed('id'))).thenAnswer((_) async {});
      service = NotificationService(plugin: plugin);
    });

    EventRow event({
      required String id,
      required DateTime startAt,
      int reminderMinutesBefore = 30,
      String? additionalReminderMinutes,
    }) {
      return EventRow(
        id: id,
        title: 'Standup',
        memo: null,
        location: null,
        startAt: startAt,
        endAt: startAt.add(const Duration(hours: 1)),
        isAllDay: false,
        colorTag: null,
        notify: true,
        reminderMinutesBefore: reminderMinutesBefore,
        additionalReminderMinutes: additionalReminderMinutes,
        recurrenceRule: null,
        recurrenceGroupId: null,
        osCalendarId: null,
        osEventId: null,
        osLastKnownModified: null,
        syncStatus: SyncStatus.pendingPush,
        importSourceCalendarId: null,
        importSourceEventId: null,
        createdAt: startAt,
        updatedAt: startAt,
      );
    }

    test(
      'schedules exactly the selected, in-window offsets for each event, '
      'nothing more',
      () async {
        final now = DateTime.now();
        await service.refillEvents([
          event(
            id: 'e1',
            startAt: now.add(const Duration(hours: 2)),
            reminderMinutesBefore: 30,
          ),
          event(
            id: 'e2',
            startAt: now.add(const Duration(hours: 3)),
            reminderMinutesBefore: 0,
            additionalReminderMinutes: '60',
          ),
        ]);

        // e1: only its one selected offset (30) schedules.
        // e2: both its selected offsets (0 and 60) schedule.
        verify(
          plugin.zonedSchedule(
            id: anyNamed('id'),
            title: anyNamed('title'),
            body: anyNamed('body'),
            scheduledDate: anyNamed('scheduledDate'),
            notificationDetails: anyNamed('notificationDetails'),
            androidScheduleMode: anyNamed('androidScheduleMode'),
            payload: anyNamed('payload'),
          ),
        ).called(3);
      },
    );

    test(
      'an offset already correctly pending is not re-scheduled',
      () async {
        // Millisecond-precision, not DateTime.now()'s microsecond
        // precision: the pending payload below round-trips through
        // millisecondsSinceEpoch (see refillEvents' own decoding), so a
        // `now`/`start` carrying microseconds would never compare equal to
        // its own reconstructed pending value — a test-construction
        // artifact, not something real event data (already millisecond-
        // granular coming out of the DB) would ever hit.
        final now = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
        );
        final start = now.add(const Duration(hours: 2));
        final e = event(id: 'e1', startAt: start, reminderMinutesBefore: 30);
        final alreadyPendingId = NotificationService.notificationId('e1', 30);
        final alertAt = start.subtract(const Duration(minutes: 30));

        when(plugin.pendingNotificationRequests()).thenAnswer(
          (_) async => [
            PendingNotificationRequest(
              alreadyPendingId,
              'Standup',
              null,
              jsonEncode({'alertAtMillis': alertAt.millisecondsSinceEpoch}),
            ),
          ],
        );

        await service.refillEvents([e]);

        verifyNever(
          plugin.zonedSchedule(
            id: anyNamed('id'),
            title: anyNamed('title'),
            body: anyNamed('body'),
            scheduledDate: anyNamed('scheduledDate'),
            notificationDetails: anyNamed('notificationDetails'),
            androidScheduleMode: anyNamed('androidScheduleMode'),
            payload: anyNamed('payload'),
          ),
        );
      },
    );
  });
}
