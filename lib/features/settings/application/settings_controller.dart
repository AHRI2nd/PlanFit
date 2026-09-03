import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:device_calendar_plus/device_calendar_plus.dart' show Calendar;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/calendar_sync/holiday_calendar_service.dart'
    show
        HolidayCalendarSyncException,
        defaultHolidayCountryCode,
        holidayCountrySourceId,
        holidayCustomSourceId;
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
  // Legacy single-select keys from before holiday sources were
  // multi-select — never written again, only read once as a migration
  // seed in build() below (see the comment there).
  static const _kLegacyHolidayCountry = 'settings.holidayCountryCode';
  static const _kLegacyHolidayCustomUrl = 'settings.customHolidayCalendarUrl';
  static const _kHolidayCountries = 'settings.holidayCountryCodes';
  static const _kHolidayCustomUrls = 'settings.customHolidayCalendarUrls';
  static const _kHolidaySourceColors = 'settings.holidaySourceColors';
  static const _kShowLunarDates = 'settings.showLunarDates';
  static const _kLanguageOverride = 'settings.languageOverride';

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

  /// Resolves [holidayCountryCodes]/[customHolidayCalendarUrls] for [build],
  /// seeding them exactly once — see [AppSettings.holidayCountryCodes]'s own
  /// doc. `getStringList` returning `null` (the key was never written,
  /// distinct from an explicitly-persisted empty list) is what marks
  /// "never configured under the multi-select shape yet," at which point
  /// this reads whatever single selection (if any) the earlier
  /// single-select version of this feature had persisted under the now-dead
  /// [_kLegacyHolidayCountry]/[_kLegacyHolidayCustomUrl] keys, so upgrading
  /// doesn't silently drop it — falling back further to
  /// [defaultHolidayCountryCode] only if neither was ever set either (a
  /// fresh install, or one from before holiday-source selection existed at
  /// all).
  (Set<String>, Set<String>) _readHolidaySources(SharedPreferences prefs) {
    final storedCountries = prefs.getStringList(_kHolidayCountries);
    final storedCustomUrls = prefs.getStringList(_kHolidayCustomUrls);
    if (storedCountries != null || storedCustomUrls != null) {
      return (
        storedCountries?.toSet() ?? const {},
        storedCustomUrls?.toSet() ?? const {},
      );
    }
    final legacyCustomUrl = prefs.getString(_kLegacyHolidayCustomUrl);
    if (legacyCustomUrl != null) {
      return (const {}, {legacyCustomUrl});
    }
    final legacyCountry = prefs.getString(_kLegacyHolidayCountry);
    return ({legacyCountry ?? defaultHolidayCountryCode()}, const {});
  }

  /// `SharedPreferences` has no native map type — stored as one JSON object
  /// string, the same shape [_persistNow] writes back out. An unset key, or
  /// one that fails to parse (corrupted prefs, a restore from an
  /// incompatible app version), just means no source has a custom color yet
  /// — never worth crashing [build] over.
  Map<String, String> _readHolidaySourceColors(SharedPreferences prefs) {
    final raw = prefs.getString(_kHolidaySourceColors);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map((k, v) => MapEntry(k as String, v as String));
    } catch (_) {
      return const {};
    }
  }

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final (holidayCountryCodes, customHolidayCalendarUrls) =
        _readHolidaySources(prefs);
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
      holidayCountryCodes: holidayCountryCodes,
      customHolidayCalendarUrls: customHolidayCalendarUrls,
      holidaySourceColors: _readHolidaySourceColors(prefs),
      showLunarDates: prefs.getBool(_kShowLunarDates) ?? true,
      languageOverride: prefs.getString(_kLanguageOverride),
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
    await prefs.setStringList(
      _kHolidayCountries,
      s.holidayCountryCodes.toList(),
    );
    await prefs.setStringList(
      _kHolidayCustomUrls,
      s.customHolidayCalendarUrls.toList(),
    );
    if (s.holidaySourceColors.isEmpty) {
      await prefs.remove(_kHolidaySourceColors);
    } else {
      await prefs.setString(
        _kHolidaySourceColors,
        jsonEncode(s.holidaySourceColors),
      );
    }
    await prefs.setBool(_kShowLunarDates, s.showLunarDates);
    if (s.languageOverride == null) {
      await prefs.remove(_kLanguageOverride);
    } else {
      await prefs.setString(_kLanguageOverride, s.languageOverride!);
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

  Future<void> setShowLunarDates(bool enabled) =>
      _update(state.copyWith(showLunarDates: enabled));

  /// `null` reverts to following the OS locale — see
  /// [AppSettings.languageOverride]'s own doc.
  Future<void> setLanguageOverride(String? code) => _update(
    state.copyWith(languageOverride: code, clearLanguageOverride: code == null),
  );

  Future<void> setDialTimeFormatPreference(TimeFormatPreference preference) =>
      _update(state.copyWith(dialTimeFormatPreference: preference));

  Future<void> setDisplayTimeFormatPreference(
    TimeFormatPreference preference,
  ) => _update(state.copyWith(displayTimeFormatPreference: preference));

  /// Turns every selected holiday calendar on or off at once — see
  /// [AppSettings.holidayCalendarEnabled]. Turning it on pulls every
  /// currently-selected country/custom URL in immediately rather than
  /// waiting for the next foreground resume, same immediacy
  /// [setCalendarSubscribed] already gives device-calendar subscriptions;
  /// turning it off removes every mirrored row right away so the setting
  /// and what's visible never disagree. Failures (network, a since-removed
  /// custom feed) are swallowed here, not thrown — this flips a single
  /// switch covering a whole *set* of independent sources, so one bad
  /// source failing shouldn't block the other N from turning on, and
  /// there's no single sensible per-source snackbar to show anyway; a
  /// transient failure is picked up on the next foreground resume same as
  /// any other best-effort sync.
  Future<void> setHolidayCalendarEnabled(bool enabled) async {
    await _update(state.copyWith(holidayCalendarEnabled: enabled));
    final holidays = ref.read(holidayCalendarServiceProvider);
    for (final countryCode in state.holidayCountryCodes) {
      try {
        if (enabled) {
          await holidays.syncCountry(
            countryCode,
            colorHex: _holidayColorFor(holidayCountrySourceId(countryCode)),
          );
        } else {
          await holidays.unsubscribeCountry(countryCode);
        }
      } on HolidayCalendarSyncException {
        // Best-effort — see this method's own doc.
      }
    }
    for (final url in state.customHolidayCalendarUrls) {
      try {
        if (enabled) {
          await holidays.syncCustomUrl(
            url,
            colorHex: _holidayColorFor(holidayCustomSourceId(url)),
          );
        } else {
          await holidays.unsubscribeCustom(url);
        }
      } on HolidayCalendarSyncException {
        // Best-effort — see this method's own doc.
      }
    }
  }

  /// [sourceId]'s own chosen color, if any — the shared lookup every
  /// `syncCountry`/`syncCustomUrl` call site uses so a color picked while a
  /// source was, say, temporarily deselected still applies the moment it's
  /// mirrored again, not just from the two dedicated color setters below.
  String? _holidayColorFor(String sourceId) =>
      state.holidaySourceColors[sourceId];

  /// Adds or removes [countryCode] from the set of countries whose holidays
  /// are mirrored — any number can be selected at once, same shape as
  /// [setCalendarSubscribed]. Syncs/unsubscribes *before* persisting the
  /// new set — on a failed sync (throws [HolidayCalendarSyncException]) the
  /// setting stays exactly as it was, rather than claiming a country is
  /// selected that isn't actually mirrored yet.
  Future<void> setHolidayCountrySelected(
    String countryCode,
    bool selected,
  ) async {
    final holidays = ref.read(holidayCalendarServiceProvider);
    if (state.holidayCalendarEnabled) {
      if (selected) {
        await holidays.syncCountry(
          countryCode,
          colorHex: _holidayColorFor(holidayCountrySourceId(countryCode)),
        );
      } else {
        await holidays.unsubscribeCountry(countryCode);
      }
    }
    final next = Set<String>.from(state.holidayCountryCodes);
    if (selected) {
      next.add(countryCode);
    } else {
      next.remove(countryCode);
    }
    await _update(state.copyWith(holidayCountryCodes: next));
  }

  /// Adds a new custom ICS feed at [url] to the set already mirrored.
  /// Syncs before persisting, for the same reason as
  /// [setHolidayCountrySelected].
  Future<void> addCustomHolidayCalendarUrl(String url) async {
    if (state.holidayCalendarEnabled) {
      await ref
          .read(holidayCalendarServiceProvider)
          .syncCustomUrl(
            url,
            colorHex: _holidayColorFor(holidayCustomSourceId(url)),
          );
    }
    final next = Set<String>.from(state.customHolidayCalendarUrls)..add(url);
    await _update(state.copyWith(customHolidayCalendarUrls: next));
  }

  /// Removes a previously-added custom ICS feed.
  Future<void> removeCustomHolidayCalendarUrl(String url) async {
    if (state.holidayCalendarEnabled) {
      await ref.read(holidayCalendarServiceProvider).unsubscribeCustom(url);
    }
    final next = Set<String>.from(state.customHolidayCalendarUrls)..remove(url);
    await _update(state.copyWith(customHolidayCalendarUrls: next));
  }

  /// Sets (or, with `colorHex: null`, clears back to the default)
  /// [countryCode]'s own display color. If that country is currently
  /// selected, re-syncs it first — [HolidayCalendarService._syncFrom]
  /// upserts every already-mirrored event on every sync regardless of
  /// whether its own fields changed, so this is what actually repaints
  /// existing events with the new color rather than only affecting ones
  /// mirrored from here on. Same "sync before persisting" ordering as
  /// [setHolidayCountrySelected], so a failed re-sync leaves the setting
  /// unchanged rather than claiming a color that never actually made it to
  /// any mirrored row.
  Future<void> setHolidayCountryColor(
    String countryCode, {
    String? colorHex,
  }) async {
    if (state.holidayCalendarEnabled &&
        state.holidayCountryCodes.contains(countryCode)) {
      await ref
          .read(holidayCalendarServiceProvider)
          .syncCountry(countryCode, colorHex: colorHex);
    }
    final next = Map<String, String>.from(state.holidaySourceColors);
    final sourceId = holidayCountrySourceId(countryCode);
    if (colorHex == null) {
      next.remove(sourceId);
    } else {
      next[sourceId] = colorHex;
    }
    await _update(state.copyWith(holidaySourceColors: next));
  }

  /// [url]'s own display color — same shape as [setHolidayCountryColor], for
  /// a custom feed instead of a built-in country.
  Future<void> setCustomHolidayColor(String url, {String? colorHex}) async {
    if (state.holidayCalendarEnabled &&
        state.customHolidayCalendarUrls.contains(url)) {
      await ref
          .read(holidayCalendarServiceProvider)
          .syncCustomUrl(url, colorHex: colorHex);
    }
    final next = Map<String, String>.from(state.holidaySourceColors);
    final sourceId = holidayCustomSourceId(url);
    if (colorHex == null) {
      next.remove(sourceId);
    } else {
      next[sourceId] = colorHex;
    }
    await _update(state.copyWith(holidaySourceColors: next));
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
