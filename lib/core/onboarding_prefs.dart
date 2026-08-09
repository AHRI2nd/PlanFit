/// SharedPreferences keys for one-time, non-user-facing app state — kept
/// separate from [AppSettings] since these aren't settings a user toggles,
/// just "has this already happened" flags shared between app.dart and the
/// onboarding screen.
class OnboardingPrefs {
  const OnboardingPrefs._();

  static const String completed = 'onboarding.completed';
  static const String notificationPrompted = 'onboarding.notificationPrompted';
}
