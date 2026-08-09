import 'package:device_calendar_plus/device_calendar_plus.dart' show Calendar;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import 'app_settings.dart';

/// Loads settings from [SharedPreferences], applies them to the notification
/// and calendar services, and persists every change.
class SettingsController extends Notifier<AppSettings> {
  static const _kTheme = 'settings.themeMode';
  static const _kSound = 'settings.notificationSound';
  static const _kSync = 'settings.calendarSyncEnabled';
  static const _kCalendar = 'settings.targetCalendarId';
  static const _kWeekStart = 'settings.weekStartsMonday';
  static const _kSubscribed = 'settings.subscribedCalendarIds';
  static const _kTodoRetention = 'settings.completedTodoRetentionDays';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final settings = AppSettings(
      themeMode: ThemeMode.values[prefs.getInt(_kTheme) ?? 0],
      notificationSound: prefs.getBool(_kSound) ?? true,
      calendarSyncEnabled: prefs.getBool(_kSync) ?? false,
      targetCalendarId: prefs.getString(_kCalendar),
      weekStartsMonday: prefs.getBool(_kWeekStart) ?? true,
      subscribedCalendarIds: (prefs.getStringList(_kSubscribed) ?? const [])
          .toSet(),
      completedTodoRetentionDays: prefs.getInt(_kTodoRetention),
    );
    _apply(settings);
    return settings;
  }

  /// Pushes config into the long-lived services so the repository sees it.
  void _apply(AppSettings s) {
    ref.read(notificationServiceProvider).soundEnabled = s.notificationSound;
    final calendar = ref.read(calendarServiceProvider);
    calendar.enabled = s.calendarSyncEnabled;
    calendar.targetCalendarId = s.targetCalendarId;
    calendar.subscribedCalendarIds = s.subscribedCalendarIds;
  }

  Future<void> _persist(AppSettings s) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kTheme, s.themeMode.index);
    await prefs.setBool(_kSound, s.notificationSound);
    await prefs.setBool(_kSync, s.calendarSyncEnabled);
    if (s.targetCalendarId == null) {
      await prefs.remove(_kCalendar);
    } else {
      await prefs.setString(_kCalendar, s.targetCalendarId!);
    }
    await prefs.setBool(_kWeekStart, s.weekStartsMonday);
    await prefs.setStringList(_kSubscribed, s.subscribedCalendarIds.toList());
    if (s.completedTodoRetentionDays == null) {
      await prefs.remove(_kTodoRetention);
    } else {
      await prefs.setInt(_kTodoRetention, s.completedTodoRetentionDays!);
    }
  }

  Future<void> _update(AppSettings next) async {
    state = next;
    _apply(next);
    await _persist(next);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  Future<void> setNotificationSound(bool enabled) =>
      _update(state.copyWith(notificationSound: enabled));

  Future<void> setCalendarSyncEnabled(bool enabled) =>
      _update(state.copyWith(calendarSyncEnabled: enabled));

  Future<void> setTargetCalendar(String? calendarId) => _update(
    state.copyWith(
      targetCalendarId: calendarId,
      clearTargetCalendar: calendarId == null,
    ),
  );

  Future<void> setWeekStartsMonday(bool monday) =>
      _update(state.copyWith(weekStartsMonday: monday));

  /// `null` turns the sweep off entirely — see
  /// `AppSettings.completedTodoRetentionDays`.
  Future<void> setCompletedTodoRetentionDays(int? days) => _update(
    state.copyWith(
      completedTodoRetentionDays: days,
      clearCompletedTodoRetentionDays: days == null,
    ),
  );

  /// Turns continuous mirroring of [calendarId] on or off — see
  /// [AppSettings.subscribedCalendarIds]. Subscribing pulls its current
  /// events in immediately rather than waiting for the next foreground
  /// resume; unsubscribing removes the local mirror rows right away too,
  /// so the setting and what's visible never disagree.
  Future<void> setCalendarSubscribed(String calendarId, bool subscribed) async {
    final next = Set<String>.from(state.subscribedCalendarIds);
    if (subscribed) {
      next.add(calendarId);
    } else {
      next.remove(calendarId);
    }
    await _update(state.copyWith(subscribedCalendarIds: next));

    final importService = ref.read(calendarImportServiceProvider);
    if (subscribed) {
      await importService.syncMirroredCalendars(
        {calendarId},
        from: DateTime.now().subtract(const Duration(days: 30)),
        to: DateTime.now().add(const Duration(days: 365)),
      );
    } else {
      await importService.removeMirroredCalendar(calendarId);
    }
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Calendars the sync-target picker can offer — read-only feeds excluded
/// since PlanFit can't write events into them.
final writableCalendarsProvider = FutureProvider<List<Calendar>>((ref) {
  return ref.watch(calendarServiceProvider).writableCalendars();
});

/// Calendars the *import* picker can offer — unlike [writableCalendarsProvider],
/// read-only feeds (a subscribed holiday calendar, a shared calendar the
/// user can only read) are included, since importing only ever reads from
/// them.
final importSourceCalendarsProvider = FutureProvider<List<Calendar>>((ref) {
  return ref.watch(calendarImportServiceProvider).availableCalendars();
});

/// The display name of the currently-selected sync target, resolved against
/// [writableCalendarsProvider] — null while unset or if the id no longer
/// matches anything writable (e.g. the calendar was deleted on-device).
final targetCalendarNameProvider = FutureProvider<String?>((ref) async {
  final id = ref.watch(settingsControllerProvider).targetCalendarId;
  if (id == null) return null;
  final calendars = await ref.watch(writableCalendarsProvider.future);
  for (final c in calendars) {
    if (c.id == id) return c.name;
  }
  return null;
});
