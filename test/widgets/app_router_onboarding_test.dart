import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/core/notifications/notification_service.dart';
import 'package:planfit/core/onboarding_prefs.dart';
import 'package:planfit/core/routing/app_router.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/onboarding/presentation/onboarding_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen_test.mocks.dart';

/// Regression test for the widget-deep-link onboarding bypass: a HomeScreen
/// widget tap used to call `appRouter.go('/schedule')` unconditionally,
/// landing the user in the tabbed shell even if they'd never finished
/// onboarding. The fix moved the gate into `appRouter`'s own `redirect`, so
/// it now applies to *every* navigation attempt, not just the initial one.
class _FakeNotificationService extends NotificationService {
  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  // appRouter is a process-wide singleton (imported directly, not rebuilt
  // per test), and go_router's `redirect` re-resolves against whatever
  // BuildContext it last saw — so this exercises both the bypass-prevention
  // and the "completed" case as one continuous scenario in a single pumped
  // tree, rather than two separate tests that would each remount the router
  // fresh and risk it redirecting against a stale context from a prior test.
  testWidgets(
    'a widget-deep-link navigation is bounced back to onboarding until '
    'onboarding is completed, then proceeds normally',
    (tester) async {
      final events = MockEventRepository();
      final todos = MockTodoDao();
      when(
        events.watchUpcoming(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => Stream.value(const <EventRow>[]));
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const <EventRow>[]));
      when(
        todos.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const <TodoRow>[]));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            notificationServiceProvider.overrideWithValue(
              _FakeNotificationService(),
            ),
            eventRepositoryProvider.overrideWithValue(events),
            todoDaoProvider.overrideWithValue(todos),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            locale: const Locale('ko'),
            localizationsDelegates: const [
              AppL10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppL10n.supportedLocales,
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Fresh SharedPreferences → OnboardingPrefs.completed is unset → even
      // the default initialLocation ('/home') should already have redirected.
      expect(find.byType(OnboardingScreen), findsOneWidget);

      // Simulate exactly what a HomeScreen-widget tap does.
      appRouter.go('/schedule');
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);

      // Now complete onboarding (as OnboardingScreen._finish() would) and
      // retry the same navigation — it should go through this time.
      await prefs.setBool(OnboardingPrefs.completed, true);
      appRouter.go('/schedule');
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );
}
