import 'package:flutter/material.dart';

/// User-tunable app settings, persisted across launches.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.notificationSound = true,
    this.calendarSyncEnabled = false,
    this.targetCalendarId,
    this.remindersSyncEnabled = false,
    this.weekStartsMonday = true,
    this.subscribedCalendarIds = const {},
    this.completedTodoRetentionDays,
  });

  final ThemeMode themeMode;
  final bool notificationSound;
  final bool calendarSyncEnabled;
  final String? targetCalendarId;

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

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationSound,
    bool? calendarSyncEnabled,
    String? targetCalendarId,
    bool clearTargetCalendar = false,
    bool? remindersSyncEnabled,
    bool? weekStartsMonday,
    Set<String>? subscribedCalendarIds,
    int? completedTodoRetentionDays,
    bool clearCompletedTodoRetentionDays = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationSound: notificationSound ?? this.notificationSound,
      calendarSyncEnabled: calendarSyncEnabled ?? this.calendarSyncEnabled,
      targetCalendarId: clearTargetCalendar
          ? null
          : (targetCalendarId ?? this.targetCalendarId),
      remindersSyncEnabled: remindersSyncEnabled ?? this.remindersSyncEnabled,
      weekStartsMonday: weekStartsMonday ?? this.weekStartsMonday,
      subscribedCalendarIds:
          subscribedCalendarIds ?? this.subscribedCalendarIds,
      completedTodoRetentionDays: clearCompletedTodoRetentionDays
          ? null
          : (completedTodoRetentionDays ?? this.completedTodoRetentionDays),
    );
  }
}
