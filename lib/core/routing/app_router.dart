import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/settings/presentation/auto_backup_screen.dart';
import '../../features/settings/presentation/calendar_import_screen.dart';
import '../../features/settings/presentation/calendar_picker_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/sync_log_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/social/presentation/social_screen.dart';
import '../di.dart';
import '../onboarding_prefs.dart';

/// Four-tab app with per-tab navigation stacks via [StatefulShellRoute]. Each
/// branch keeps its own history, so switching tabs preserves where the user was.
///
/// `/onboarding` sits outside the shell (no tab bar). The [redirect] below
/// gates *every* navigation attempt on onboarding being complete — not just
/// the initial one — so a HomeScreen-widget deep link (see app.dart's
/// `_openFromWidgetUri`) firing before onboarding is done gets bounced back
/// to `/onboarding` instead of dropping the user straight into the shell.
/// It also removes the one-frame flash of `/home` that an imperative
/// `appRouter.go('/onboarding')` from a post-frame callback used to cause,
/// since redirects resolve before the first frame paints.
final appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    final prefs = ProviderScope.containerOf(context).read(sharedPreferencesProvider);
    final completed = prefs.getBool(OnboardingPrefs.completed) ?? false;
    final onOnboarding = state.matchedLocation == '/onboarding';
    if (!completed && !onOnboarding) return '/onboarding';
    if (completed && onOnboarding) return '/home';
    return null;
  },
  routes: [
    GoRoute(
        path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
                path: '/schedule', builder: (_, _) => const ScheduleScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/social', builder: (_, _) => const SocialScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'sync-log',
                  builder: (_, _) => const SyncLogScreen(),
                ),
                GoRoute(
                  path: 'calendar-picker',
                  builder: (_, _) => const CalendarPickerScreen(),
                ),
                GoRoute(
                  path: 'calendar-import',
                  builder: (_, _) => const CalendarImportScreen(),
                ),
                GoRoute(
                  path: 'auto-backup',
                  builder: (_, _) => const AutoBackupScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
