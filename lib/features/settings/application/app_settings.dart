import 'package:flutter/material.dart';

import '../../../core/calendar_sync/holiday_calendar_service.dart'
    show defaultHolidayCountryCode;

/// Which hour format a `TimeOfDay`/hour-minute display uses. `system`
/// follows the OS's own 24-hour setting (`MediaQuery.alwaysUse24HourFormat`)
/// — same as before either of the two settings below existed.
enum TimeFormatPreference { system, h12, h24 }

/// User-tunable app settings, persisted across launches.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.notificationSound = true,
    this.calendarSyncEnabled = false,
    this.targetCalendarId,
    this.autoImportCalendarEnabled = false,
    this.remindersSyncEnabled = false,
    this.weekStartsMonday = true,
    this.subscribedCalendarIds = const {},
    this.completedTodoRetentionDays,
    this.dialTimeFormatPreference = TimeFormatPreference.system,
    this.displayTimeFormatPreference = TimeFormatPreference.system,
    this.holidayCalendarEnabled = true,
    this.holidayCountryCode,
    this.customHolidayCalendarUrl,
  });

  final ThemeMode themeMode;
  final bool notificationSound;
  final bool calendarSyncEnabled;
  final String? targetCalendarId;

  /// Whether the reconciler also imports events created *directly* in the
  /// device calendar app's PlanFit calendar as new PlanFit events — off by
  /// default, and only ever meaningful while [calendarSyncEnabled] is also
  /// on (the settings screen only shows the toggle then). Independent of
  /// [calendarSyncEnabled] itself so it persists its own on/off choice
  /// separately: turning calendar sync off and back on doesn't silently
  /// re-enable auto-import if the user had deliberately left it off.
  final bool autoImportCalendarEnabled;

  /// Whether to-dos sync with the OS reminders list — iOS only (Android has
  /// no OS reminders concept), independent of [calendarSyncEnabled]. See
  /// `RemindersService`/`RemindersReconciler`.
  final bool remindersSyncEnabled;

  /// Which day the week/month grid and the home screen's weekly stats treat
  /// as day one — `true` for Monday, `false` for Sunday.
  final bool weekStartsMonday;

  /// Device calendars the user subscribed to as a read-only, continuously
  /// mirrored source — see [CalendarImportService.syncMirroredCalendars].
  /// Independent of [calendarSyncEnabled]/[targetCalendarId], which govern
  /// the opposite direction (PlanFit's own events pushed *out*).
  final Set<String> subscribedCalendarIds;

  /// How many days a completed to-do is kept before
  /// `TodoController.pruneCompleted` deletes it for good — `null` means the
  /// sweep never runs at all (the default: nothing is ever auto-deleted
  /// unless the user opts in from Settings).
  final int? completedTodoRetentionDays;

  /// The time-picker dial's own hour format — applied by wrapping just that
  /// dialog's `builder:` (see `showAppTimePicker` in
  /// `core/time_format.dart`), never the whole app, so it can't leak into
  /// [displayTimeFormatPreference]'s "system" resolution or vice versa.
  final TimeFormatPreference dialTimeFormatPreference;

  /// Every other hour-minute label in the app (day/week timeline, event and
  /// to-do rows, search results, sync log, ...) — see `Fmt.time`/`Fmt.hour`'s
  /// `use24Hour` param. Deliberately a separate setting from
  /// [dialTimeFormatPreference]: someone may want a 24-hour dial (faster to
  /// scrub through) while still reading "오후 3:00"-style labels elsewhere,
  /// or vice versa.
  final TimeFormatPreference displayTimeFormatPreference;

  /// Whether the app auto-imports a holiday calendar as a read-only mirror
  /// — on by default. Which calendar is [holidayCountryCode]/
  /// [customHolidayCalendarUrl]'s job to say; this only turns the whole
  /// thing on or off.
  final bool holidayCalendarEnabled;

  /// The country whose public holidays to mirror (an ISO alpha-2 key of
  /// `HolidayCalendarService.holidayCountryCalendarIds`) — `null` means
  /// "auto," resolved via [resolvedHolidayCountryCode]. Ignored while
  /// [customHolidayCalendarUrl] is set; the two are mutually exclusive from
  /// the user's perspective (picking one clears the other — see
  /// `SettingsController.setHolidayCountryCode`/`setCustomHolidayCalendarUrl`).
  final String? holidayCountryCode;

  /// A user-supplied ICS feed URL, if they added one instead of picking a
  /// country — takes priority over [holidayCountryCode] wherever both are
  /// read. `null` means no custom calendar is active.
  final String? customHolidayCalendarUrl;

  /// [holidayCountryCode], folding in the "auto" default (the exact
  /// locale-based fallback this app always used before country selection
  /// existed) so every call site can just read this instead of each
  /// re-deriving the same null-check.
  String get resolvedHolidayCountryCode =>
      holidayCountryCode ?? defaultHolidayCountryCode();

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationSound,
    bool? calendarSyncEnabled,
    String? targetCalendarId,
    bool clearTargetCalendar = false,
    bool? autoImportCalendarEnabled,
    bool? remindersSyncEnabled,
    bool? weekStartsMonday,
    Set<String>? subscribedCalendarIds,
    int? completedTodoRetentionDays,
    bool clearCompletedTodoRetentionDays = false,
    TimeFormatPreference? dialTimeFormatPreference,
    TimeFormatPreference? displayTimeFormatPreference,
    bool? holidayCalendarEnabled,
    String? holidayCountryCode,
    bool clearHolidayCountryCode = false,
    String? customHolidayCalendarUrl,
    bool clearCustomHolidayCalendarUrl = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationSound: notificationSound ?? this.notificationSound,
      calendarSyncEnabled: calendarSyncEnabled ?? this.calendarSyncEnabled,
      targetCalendarId: clearTargetCalendar
          ? null
          : (targetCalendarId ?? this.targetCalendarId),
      autoImportCalendarEnabled:
          autoImportCalendarEnabled ?? this.autoImportCalendarEnabled,
      remindersSyncEnabled: remindersSyncEnabled ?? this.remindersSyncEnabled,
      weekStartsMonday: weekStartsMonday ?? this.weekStartsMonday,
      subscribedCalendarIds:
          subscribedCalendarIds ?? this.subscribedCalendarIds,
      completedTodoRetentionDays: clearCompletedTodoRetentionDays
          ? null
          : (completedTodoRetentionDays ?? this.completedTodoRetentionDays),
      dialTimeFormatPreference:
          dialTimeFormatPreference ?? this.dialTimeFormatPreference,
      displayTimeFormatPreference:
          displayTimeFormatPreference ?? this.displayTimeFormatPreference,
      holidayCalendarEnabled:
          holidayCalendarEnabled ?? this.holidayCalendarEnabled,
      holidayCountryCode: clearHolidayCountryCode
          ? null
          : (holidayCountryCode ?? this.holidayCountryCode),
      customHolidayCalendarUrl: clearCustomHolidayCalendarUrl
          ? null
          : (customHolidayCalendarUrl ?? this.customHolidayCalendarUrl),
    );
  }
}
