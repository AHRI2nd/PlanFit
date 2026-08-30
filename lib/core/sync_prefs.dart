/// SharedPreferences key for when [CalendarReconciler] last completed a
/// successful device-calendar sync pass — surfaced in Settings so a broken
/// sync (e.g. calendar permission silently revoked in OS settings) doesn't
/// go unnoticed indefinitely. Kept separate from `AppSettings` for the same
/// reason as `OnboardingPrefs`: not a user-toggled setting, just observed
/// runtime state.
class SyncPrefs {
  const SyncPrefs._();

  static const String lastCalendarSyncAt = 'sync.lastCalendarSyncAt';

  /// Set once [HolidayCalendarService.migrateLegacySources] has run —
  /// cleans up mirrored rows from before country/custom holiday-calendar
  /// selection existed (see that method's own doc). Gating it behind this
  /// flag means the one-time cleanup actually runs once, not a repeated
  /// full-table scan on every single foreground resume for the rest of the
  /// app's life.
  static const String holidayLegacySourcesMigrated =
      'sync.holidayLegacySourcesMigrated';
}
