import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'core/app_badge/app_badge_sync.dart';
import 'core/di.dart';
import 'core/home_widget/home_widget_sync.dart';
import 'core/notifications/notification_tap_target.dart';
import 'core/onboarding_prefs.dart';
import 'core/routing/app_router.dart';
import 'design/theme/app_theme.dart';
import 'features/schedule/application/schedule_providers.dart';
import 'features/schedule/presentation/event_edit/event_editor_sheet.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/todo/application/todo_providers.dart';
import 'features/todo/presentation/todo_detail_sheet.dart';
import 'l10n/app_localizations.dart';

/// Root widget. Owns the theme mode, localization, router, and triggers a
/// calendar reconciliation whenever the app returns to the foreground.
class PlanFitApp extends ConsumerStatefulWidget {
  const PlanFitApp({super.key});

  @override
  ConsumerState<PlanFitApp> createState() => _PlanFitAppState();
}

class _PlanFitAppState extends ConsumerState<PlanFitApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Onboarding itself is gated by appRouter's redirect (app_router.dart)
      // now, not here. Its own "get started" CTA is what requests
      // notification access (with context, instead of a bare OS popup) — so
      // only fire the standalone request below once onboarding's done.
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs.getBool(OnboardingPrefs.completed) ?? false) {
        // Ask for notification access once, on first launch — the app's core
        // value (alerting at schedule start) depends on it, so don't make the
        // user find the toggle in Settings first.
        _maybeRequestNotificationPermission();
      }
      _reconcile();
      _reconcileReminders();
      _syncHomeWidget();
      _syncAppBadge();
      _handleColdStartFromWidget();
      _handleColdStartFromNotification();
      _runAutoBackup();
      _refillTodoNotifications();
      _pruneCompletedTodos();
      _syncHolidayCalendar();
    });
    // Warm-app taps (the widget clicked while PlanFit is already running or
    // backgrounded) arrive on this stream instead of a fresh cold start.
    _widgetClickSub = HomeWidget.widgetClicked.listen(_openFromWidgetUri);
    // Same idea for notification taps while the app is already alive
    // (foreground or backgrounded-but-not-killed) — a cold-start tap is
    // handled separately by _handleColdStartFromNotification above.
    ref.read(notificationServiceProvider).onTap = _handleNotificationTap;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(notificationServiceProvider).onTap = null;
    _widgetClickSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconcile();
      _reconcileReminders();
      _syncHomeWidget();
      _syncAppBadge();
      _runAutoBackup();
      _refillTodoNotifications();
      _pruneCompletedTodos();
      _syncHolidayCalendar();
    }
  }

  Future<void> _maybeRequestNotificationPermission() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(OnboardingPrefs.notificationPrompted) ?? false) return;
    try {
      await ref.read(notificationServiceProvider).requestPermission();
    } finally {
      // Mark it shown even on failure — the OS itself won't re-prompt after a
      // decline, so retrying here would just do nothing forever.
      await prefs.setBool(OnboardingPrefs.notificationPrompted, true);
    }
  }

  Future<void> _reconcile() async {
    try {
      await ref.read(calendarReconcilerProvider).reconcile();
      // Only recorded when calendar sync is actually on — reconcile() also
      // runs its notification refill regardless of that, which isn't what
      // the "last synced" status in Settings is about.
      if (ref.read(calendarServiceProvider).isEnabled) {
        await ref
            .read(lastCalendarSyncAtProvider.notifier)
            .record(DateTime.now());
      }
    } catch (_) {
      // Sync is best-effort; never surface reconciliation failures to the user.
    }
  }

  /// The to-do equivalent of [_reconcile] — a no-op when reminders sync is
  /// off or on Android (see `RemindersService._supported`).
  Future<void> _reconcileReminders() async {
    try {
      await ref.read(remindersReconcilerProvider).reconcile();
    } catch (_) {
      // Sync is best-effort; never surface reconciliation failures to the user.
    }
  }

  /// Refreshes the HomeScreen widget with the next upcoming event and
  /// today's to-do progress. Best-effort, same as [_reconcile] — a widget
  /// push failing (or being a no-op pre-Xcode-setup on iOS) must never
  /// surface to the user.
  Future<void> _syncHomeWidget() async {
    try {
      final today = dateOnly(DateTime.now());
      final upcoming = await ref.read(upcomingEventsProvider.future);
      final todos = await ref.read(todosForDayProvider(today).future);
      await HomeWidgetSync.push(upcomingEvents: upcoming, todayTodos: todos);
    } catch (_) {
      // Best-effort, same as calendar reconciliation.
    }
  }

  /// Mirrors today's undone to-do count onto the HomeScreen app icon —
  /// same meaning as the schedule tab's in-app badge (see
  /// `features/shell/app_shell.dart`), just also visible without opening
  /// the app. Best-effort, same as [_reconcile].
  Future<void> _syncAppBadge() async {
    try {
      final today = dateOnly(DateTime.now());
      final todos = await ref.read(todosForDayProvider(today).future);
      await AppBadgeSync.push(todos.where((t) => !t.isDone).length);
    } catch (_) {
      // Best-effort, same as calendar reconciliation.
    }
  }

  /// (Re)arms due-time alerts for to-dos that have rolled inside the
  /// notification window since the last resume — see
  /// [TodoController.refillNotifications]. Best-effort, same as [_reconcile].
  Future<void> _refillTodoNotifications() async {
    try {
      await ref.read(todoControllerProvider).refillNotifications();
    } catch (_) {
      // Best-effort, same as calendar reconciliation.
    }
  }

  /// Runs settings > "완료된 할 일 자동 정리" if the user has turned it on —
  /// off (null) by default, in which case this is a no-op. Best-effort,
  /// same as [_reconcile]: a background sweep failing must never surface to
  /// the user, since there's no user gesture here to report back to anyway.
  Future<void> _pruneCompletedTodos() async {
    final days = ref
        .read(settingsControllerProvider)
        .completedTodoRetentionDays;
    if (days == null) return;
    try {
      await ref
          .read(todoControllerProvider)
          .pruneCompleted(Duration(days: days));
    } catch (_) {
      // Best-effort, same as calendar reconciliation.
    }
  }

  /// Writes a rolling local backup if one's due (see [AutoBackupService] —
  /// its own `runIfDue` already no-ops quietly when it isn't, and never
  /// throws, so no try/catch is needed here unlike the other best-effort
  /// tasks above).
  Future<void> _runAutoBackup() =>
      ref.read(autoBackupServiceProvider).runIfDue();

  /// Keeps the auto-imported holiday calendar current — see
  /// `HolidayCalendarService`'s own doc for why this needs no user-provided
  /// URL/calendar. No dedicated background job: piggybacks on the same
  /// foreground-resume trigger every other best-effort sync task here
  /// already uses, so subscribing simply means "the next resume (or this
  /// one) picks it up" rather than needing its own scheduling. Off entirely
  /// when the user has turned "공휴일 표시"/"Show holidays" off in Settings.
  Future<void> _syncHolidayCalendar() async {
    if (!ref.read(settingsControllerProvider).holidayCalendarEnabled) return;
    try {
      // The root Navigator's context, same as _handleNotificationTap below —
      // this widget's own `context` sits above MaterialApp.router's own
      // Localizations/Navigator, so Localizations.localeOf(context) throws
      // "does not include a Localizations ancestor" every single time from
      // here, silently swallowed by this method's own catch below (this was
      // in fact happening on every launch/resume until caught by manual
      // testing — holiday sync was never actually running).
      final navContext = appRouter.routerDelegate.navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      final localeCode = Localizations.localeOf(navContext).languageCode;
      await ref.read(holidayCalendarServiceProvider).sync(localeCode);
    } catch (_) {
      // Best-effort, same as the rest of foreground-resume sync.
    }
  }

  /// The app was launched fresh by tapping a HomeScreen widget section —
  /// distinct from [_widgetClickSub], which only fires for a tap while the
  /// app is already alive.
  Future<void> _handleColdStartFromWidget() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _openFromWidgetUri(uri);
    } catch (_) {
      // Best-effort, same as the rest of home widget sync.
    }
  }

  /// Jumps the schedule tab to the day encoded in a widget tap's uri (see
  /// [HomeWidgetSync.scheduleUri]). Anything else — a plain launch, an
  /// unrecognized link — is silently ignored rather than surfaced.
  void _openFromWidgetUri(Uri? uri) {
    final date = HomeWidgetSync.parseScheduleDate(uri);
    if (date == null) return;
    ref.read(selectedDateProvider.notifier).select(date);
    appRouter.go('/schedule');
  }

  /// The app was launched fresh (fully terminated, not just backgrounded)
  /// by tapping a notification — the counterpart to
  /// [_handleColdStartFromWidget]. A warm tap (app already alive) arrives
  /// instead through [NotificationService.onTap], wired in [initState].
  Future<void> _handleColdStartFromNotification() async {
    try {
      final details = await ref
          .read(notificationServiceProvider)
          .launchDetails();
      final response = details?.notificationResponse;
      if (details?.didNotificationLaunchApp ?? false) {
        if (response != null) await _handleNotificationTap(response);
      }
    } catch (_) {
      // Best-effort, same as the rest of cold-start handling.
    }
  }

  /// Opens the event or to-do a notification tap is for — parses
  /// [response] via [parseNotificationTapPayload] (see that function's own
  /// doc for the payload shapes and why a snooze action tap is ignored
  /// here), jumps the schedule tab to that day, and opens the specific
  /// editor/sheet. Silently gives up at any point the row a target points
  /// to isn't there any more (deleted since the notification fired) — same
  /// "never surface a best-effort failure" posture as every other handler
  /// in this file.
  Future<void> _handleNotificationTap(NotificationResponse response) async {
    final target = parseNotificationTapPayload(response);
    if (target == null) return;

    try {
      final event = switch (target) {
        EventTapTarget(:final eventId) =>
          await ref.read(eventRepositoryProvider).findById(eventId),
        TodoTapTarget() => null,
      };
      final todo = switch (target) {
        TodoTapTarget(:final todoId) =>
          await ref.read(todoDaoProvider).findById(todoId),
        EventTapTarget() => null,
      };
      final day = event?.startAt ?? todo?.slotStart;
      if (day == null) return; // deleted since the notification fired

      ref.read(selectedDateProvider.notifier).select(day);
      ref.read(scheduleViewProvider.notifier).set(ScheduleView.day);
      appRouter.go('/schedule');

      // The root Navigator's context — not this widget's own `context`,
      // which sits above MaterialApp.router's Navigator and can't resolve
      // one via Navigator.of(context) from here.
      final navContext = appRouter.routerDelegate.navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      if (event != null) {
        await showEventEditor(navContext, existing: event);
      } else if (todo != null) {
        await showTodoDetailSheet(navContext, todo);
      }
    } catch (_) {
      // Best-effort — see doc comment above.
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(
      settingsControllerProvider.select((s) => s.themeMode),
    );

    // Keep the widget fresh while the app is open too — e.g. checking off a
    // to-do or adding an event should reflect on the HomeScreen without
    // waiting for the next foreground resume.
    ref.listen(upcomingEventsProvider, (_, _) => _syncHomeWidget());
    ref.listen(todosForDayProvider(dateOnly(DateTime.now())), (_, _) {
      _syncHomeWidget();
      _syncAppBadge();
    });

    return MaterialApp.router(
      title: 'PlanFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
    );
  }
}
