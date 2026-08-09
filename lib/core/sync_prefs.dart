/// SharedPreferences key for when [CalendarReconciler] last completed a
/// successful device-calendar sync pass — surfaced in Settings so a broken
/// sync (e.g. calendar permission silently revoked in OS settings) doesn't
/// go unnoticed indefinitely. Kept separate from `AppSettings` for the same
/// reason as `OnboardingPrefs`: not a user-toggled setting, just observed
/// runtime state.
class SyncPrefs {
  const SyncPrefs._();

  static const String lastCalendarSyncAt = 'sync.lastCalendarSyncAt';
}
