import 'package:device_calendar_plus/device_calendar_plus.dart' show Calendar;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di.dart';
import '../../../core/serial_queue.dart';
import 'app_settings.dart';

/// Loads settings from [SharedPreferences], applies them to the notification
/// and calendar services, and persists every change.
class SettingsController extends Notifier<AppSettings> {
  static const _kTheme = 'settings.themeMode';
  static const _kSound = 'settings.notificationSound';
  static const _kSync = 'settings.calendarSyncEnabled';
  static const _kCalendar = 'settings.targetCalendarId';
  static const _kAutoImportCalendar = 'settings.autoImportCalendarEnabled';
  static const _kReminderSync = 'settings.remindersSyncEnabled';
  static const _kWeekStart = 'settings.weekStartsMonday';
  static const _kSubscribed = 'settings.subscribedCalendarIds';
  static const _kTodoRetention = 'settings.completedTodoRetentionDays';
  static const _kDialTimeFormat = 'settings.dialTimeFormatPreference';
  static const _kDisplayTimeFormat = 'settings.displayTimeFormatPreference';
  static const _kHolidayCalendar = 'settings.holidayCalendarEnabled';
  static const _kHolidayCountry = 'settings.holidayCountryCode';
  static const _kHolidayCustomUrl = 'settings.customHolidayCalendarUrl';

  static TimeFormatPreference _readTimeFormat(
    SharedPreferences prefs,
    String key,
  ) {
    final index = prefs.getInt(key);
    if (index == null ||
        index < 0 ||
        index >= TimeFormatPreference.values.length) {
      return TimeFormatPreference.system;
    }
    return TimeFormatPreference.values[index];
  }

  /// Same out-of-range guard as [_readTimeFormat] — an unindexable stored
  /// int (corrupted prefs, a prefs restore from a different app version)
  /// must fall back to a safe default instead of throwing a RangeError out
  /// of [build], which would crash the app on every single launch with no
  /// in-app recovery short of clearing app data.
  static ThemeMode _readThemeMode(SharedPreferences prefs) {
    final index = prefs.getInt(_kTheme);
    if (index == null || index < 0 || index >= ThemeMode.values.length) {
      return ThemeMode.system;
    }
    return ThemeMode.values[index];
  }

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final settings = AppSettings(
      themeMode: _readThemeMode(prefs),
      notificationSound: prefs.getBool(_kSound) ?? true,
      calendarSyncEnabled: prefs.getBool(_kSync) ?? false,
      targetCalendarId: prefs.getString(_kCalendar),
      autoImportCalendarEnabled: prefs.getBool(_kAutoImportCalendar) ?? false,
      remindersSyncEnabled: prefs.getBool(_kReminderSync) ?? false,
      weekStartsMonday: prefs.getBool(_kWeekStart) ?? true,
      subscribedCalendarIds: (prefs.getStringList(_kSubscribed) ?? const [])
          .toSet(),
      completedTodoRetentionDays: prefs.getInt(_kTodoRetention),
      dialTimeFormatPreference: _readTimeFormat(prefs, _kDialTimeFormat),
      displayTimeFormatPreference: _readTimeFormat(prefs, _kDisplayTimeFormat),
      holidayCalendarEnabled: prefs.getBool(_kHolidayCalendar) ?? true,
      holidayCountryCode: prefs.getString(_kHolidayCountry),
      customHolidayCalendarUrl: prefs.getString(_kHolidayCustomUrl),
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
    calendar.autoImportEnabled = s.autoImportCalendarEnabled;
    calendar.subscribedCalendarIds = s.subscribedCalendarIds;
    ref.read(remindersServiceProvider).enabled = s.remindersSyncEnabled;
  }

  /// Serializes [_persist] calls so two overlapping settings changes (e.g.
  /// tapping two different toggles before the first one's writes finish —
  /// each `_persist` call is ~11 sequential `await`s, easy to land inside)
  /// can never interleave their writes. Without this, whichever call's
  /// write to a given key happens to land *last* wins on disk, regardless of
  /// which `AppSettings` snapshot was actually more recent — so the older
  /// change could silently overwrite the newer one for that one key, even
  /// though the in-memory `state` (and the UI) already reflects both changes
  /// correctly.
  final _writeQueue = SerialQueue();

  Future<void> _persist(AppSettings s) => _writeQueue.run(() => _persistNow(s));

  Future<void> _persistNow(AppSettings s) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kTheme, s.themeMode.index);
    await prefs.setBool(_kSound, s.notificationSound);
    await prefs.setBool(_kSync, s.calendarSyncEnabled);
    if (s.targetCalendarId == null) {
      await prefs.remove(_kCalendar);
    } else {
      await prefs.setString(_kCalendar, s.targetCalendarId!);
    }
    await prefs.setBool(_kAutoImportCalendar, s.autoImportCalendarEnabled);
    await prefs.setBool(_kReminderSync, s.remindersSyncEnabled);
    await prefs.setBool(_kWeekStart, s.weekStartsMonday);
    await prefs.setStringList(_kSubscribed, s.subscribedCalendarIds.toList());
    if (s.completedTodoRetentionDays == null) {
      await prefs.remove(_kTodoRetention);
    } else {
      await prefs.setInt(_kTodoRetention, s.completedTodoRetentionDays!);
    }
    await prefs.setInt(_kDialTimeFormat, s.dialTimeFormatPreference.index);
    await prefs.setInt(
      _kDisplayTimeFormat,
      s.displayTimeFormatPreference.index,
    );
    await prefs.setBool(_kHolidayCalendar, s.holidayCalendarEnabled);
    if (s.holidayCountryCode == null) {
      await prefs.remove(_kHolidayCountry);
    } else {
      await prefs.setString(_kHolidayCountry, s.holidayCountryCode!);
    }
    if (s.customHolidayCalendarUrl == null) {
      await prefs.remove(_kHolidayCustomUrl);
    } else {
      await prefs.setString(_kHolidayCustomUrl, s.customHolidayCalendarUrl!);
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

  /// Only meaningful while [AppSettings.calendarSyncEnabled] is also on —
  /// see that field's doc. The settings screen only shows this toggle then,
  /// but nothing stops the persisted flag from staying on if the user later
  /// turns calendar sync off; `CalendarReconciler` itself re-checks
  /// `CalendarService.isEnabled` before ever acting on it, so that's safe.
  Future<void> setAutoImportCalendarEnabled(bool enabled) =>
      _update(state.copyWith(autoImportCalendarEnabled: enabled));

  /// Flips to-do/reminders sync — access request and reminders-list
  /// resolution happen in the settings screen before this is called, same
  /// split as calendar sync's `toggleSync`.
  Future<void> setRemindersSyncEnabled(bool enabled) =>
      _update(state.copyWith(remindersSyncEnabled: enabled));

  Future<void> setWeekStartsMonday(bool monday) =>
      _update(state.copyWith(weekStartsMonday: monday));

  Future<void> setDialTimeFormatPreference(TimeFormatPreference preference) =>
      _update(state.copyWith(dialTimeFormatPreference: preference));

  Future<void> setDisplayTimeFormatPreference(
    TimeFormatPreference preference,
  ) => _update(state.copyWith(displayTimeFormatPreference: preference));

  /// Turns the auto-imported holiday calendar on or off — see
  /// [AppSettings.holidayCalendarEnabled]. No locale/context needed any
  /// more — [AppSettings.resolvedHolidayCountryCode] resolves "auto" on its
  /// own via `dart:ui`, and a custom URL (if any) is just read off `state`.
  /// Turning it on pulls the current feed in immediately rather than
  /// waiting for the next foreground resume, same immediacy
  /// [setCalendarSubscribed] already gives device-calendar subscriptions;
  /// turning it off removes the mirrored rows right away so the setting and
  /// what's visible never disagree. Throws [HolidayCalendarSyncException]
  /// on a failed sync (turning it on) — the caller (the settings screen)
  /// catches it and shows a snackbar; the setting itself is still flipped
  /// on regardless (the toggle reflects intent, not whether the last fetch
  /// happened to succeed — a transient failure gets picked up on the next
  /// foreground resume same as any other best-effort sync).
  Future<void> setHolidayCalendarEnabled(bool enabled) async {
    await _update(state.copyWith(holidayCalendarEnabled: enabled));
    final holidays = ref.read(holidayCalendarServiceProvider);
    if (!enabled) {
      final customUrl = state.customHolidayCalendarUrl;
      if (customUrl != null) {
        await holidays.unsubscribeCustom();
      } else {
        await holidays.unsubscribeCountry(state.resolvedHolidayCountryCode);
      }
      return;
    }
    final customUrl = state.customHolidayCalendarUrl;
    if (customUrl != null) {
      await holidays.syncCustomUrl(customUrl);
    } else {
      await holidays.syncCountry(state.resolvedHolidayCountryCode);
    }
  }

  /// Switches the active holiday source to [countryCode], dropping any
  /// custom URL — or previously-selected different country — that was
  /// active. Syncs *before* persisting the new choice — on failure (throws
  /// [HolidayCalendarSyncException]) the setting stays pointed at whatever
  /// was last actually working, rather than at a source that isn't
  /// mirrored yet.
  Future<void> setHolidayCountryCode(String countryCode) async {
    final holidays = ref.read(holidayCalendarServiceProvider);
    if (state.holidayCalendarEnabled) {
      await holidays.syncCountry(countryCode);
    }
    final hadCustomUrl = state.customHolidayCalendarUrl != null;
    // Each country has its own source id (unlike swapping one custom URL
    // for another, which reuses the single 'holiday:custom' id and lets
    // _syncFrom's own uid-diff clean up the old feed's rows automatically)
    // — so switching country requires an explicit unsubscribe of whichever
    // country was active before, or its rows just sit there forever
    // alongside the new one.
    final previousCountry = state.resolvedHolidayCountryCode;
    await _update(
      state.copyWith(
        holidayCountryCode: countryCode,
        clearCustomHolidayCalendarUrl: true,
      ),
    );
    if (hadCustomUrl) {
      await holidays.unsubscribeCustom();
    } else if (previousCountry != countryCode) {
      await holidays.unsubscribeCountry(previousCountry);
    }
  }

  /// Switches the active holiday source to the custom feed at [url],
  /// dropping whatever country source was active. Same sync-before-persist
  /// ordering as [setHolidayCountryCode], for the same reason.
  Future<void> setCustomHolidayCalendarUrl(String url) async {
    final holidays = ref.read(holidayCalendarServiceProvider);
    if (state.holidayCalendarEnabled) {
      await holidays.syncCustomUrl(url);
    }
    // Harmless (a no-op _unsubscribe) if a custom URL was already active
    // and this was already unsubscribed the last time this ran — the
    // country source id doesn't change just because it's currently
    // inactive.
    final previousCountry = state.resolvedHolidayCountryCode;
    await _update(state.copyWith(customHolidayCalendarUrl: url));
    await holidays.unsubscribeCountry(previousCountry);
  }

  /// Drops the custom URL and falls back to the last-selected (or auto)
  /// country.
  Future<void> clearCustomHolidayCalendarUrl() async {
    final holidays = ref.read(holidayCalendarServiceProvider);
    await holidays.unsubscribeCustom();
    await _update(state.copyWith(clearCustomHolidayCalendarUrl: true));
    if (state.holidayCalendarEnabled) {
      await holidays.syncCountry(state.resolvedHolidayCountryCode);
    }
  }

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
