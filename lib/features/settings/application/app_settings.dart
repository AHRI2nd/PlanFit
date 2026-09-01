import 'package:flutter/material.dart';

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
    this.holidayCountryCodes = const {},
    this.customHolidayCalendarUrls = const {},
    this.holidaySourceColors = const {},
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

  /// Whether the app auto-imports holiday calendars as read-only mirrors —
  /// on by default. Which calendars is [holidayCountryCodes]/
  /// [customHolidayCalendarUrls]'s job to say; this only turns the whole
  /// thing on or off.
  final bool holidayCalendarEnabled;

  /// Every country whose public holidays to mirror, simultaneously (ISO
  /// alpha-2 keys of `HolidayCalendarService.holidayCountryCalendarIds`) —
  /// any number can be selected at once, same multi-select shape as
  /// [subscribedCalendarIds]. Genuinely empty means the user deselected
  /// every country (and isn't relying on any custom URL either) — unlike
  /// the single-select version this replaced, there's no getter-level
  /// "auto" fallback here any more: `SettingsController.build()` seeds this
  /// with [HolidayCalendarService.defaultHolidayCountryCode] exactly once,
  /// the first time it ever reads prefs with neither this nor
  /// [customHolidayCalendarUrls] persisted yet, so from then on this field
  /// is always the actual truth, not something every reader has to
  /// re-derive a fallback for.
  final Set<String> holidayCountryCodes;

  /// Every user-supplied ICS feed URL the user added, mirrored alongside
  /// whatever [holidayCountryCodes] selects — not mutually exclusive with
  /// it; both can be active at once.
  final Set<String> customHolidayCalendarUrls;

  /// Per-source display color for mirrored holiday events, keyed by the
  /// same source id `holidayCountrySourceId`/`holidayCustomSourceId`
  /// (`holiday_calendar_service.dart`) produce (values are `#RRGGBB`, same
  /// as `Events.colorTag`'s hex form). A source with no entry here falls
  /// back to `HolidayCalendarService.defaultColorHex` — the one fixed color
  /// every holiday event used before per-source colors existed.
  final Map<String, String> holidaySourceColors;

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
    Set<String>? holidayCountryCodes,
    Set<String>? customHolidayCalendarUrls,
    Map<String, String>? holidaySourceColors,
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
      holidayCountryCodes: holidayCountryCodes ?? this.holidayCountryCodes,
      customHolidayCalendarUrls:
          customHolidayCalendarUrls ?? this.customHolidayCalendarUrls,
      holidaySourceColors: holidaySourceColors ?? this.holidaySourceColors,
    );
  }
}
