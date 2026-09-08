import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/core/notifications/notification_service.dart';
import 'package:planfit/core/onboarding_prefs.dart';
import 'package:planfit/core/routing/app_router.dart';
import 'package:planfit/design/glass/glass_nav_bar.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/shell/app_shell.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:planfit/l10n/app_localizations_ko.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen_test.mocks.dart';

/// Regression test for the schedule tab's in-app badge going stale across
/// local midnight while the app sits foregrounded with no navigation to
/// force `AppShell`'s host route to rebuild — see `todayProvider`'s own doc
/// in schedule_providers.dart for why a plain ancestor rebuild alone (the
/// mechanism `PlanFitApp`'s own midnight timer relies on for the OS home
/// badge/widget) doesn't reach a `StatefulShellRoute` branch's cached page.
///
/// `todayProvider` didn't exist before this fix, so this file fails to
/// compile against pre-fix code — the same "compile error proves pre-fix
/// failure" verification already used elsewhere this round (e.g. the event
/// template location field's regression test).
class _FakeNotificationService extends NotificationService {
  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  testWidgets(
    "the schedule tab's badge reflects the day `todayProvider` reports, "
    "not a day computed once inside AppShell's own build()",
    (tester) async {
      final events = MockEventRepository();
      final todos = MockTodoDao();
      when(
        events.watchUpcoming(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => Stream.value(const <EventRow>[]));
      when(
        events.watchBetween(any, any),
      ).thenAnswer((_) => Stream.value(const <EventRow>[]));

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final tomorrowStart = todayEnd;
      final tomorrowEnd = tomorrowStart.add(const Duration(days: 1));

      TodoRow todo(String id) => TodoRow(
        id: id,
        eventId: null,
        title: id,
        slotStart: todayStart,
        slotEnd: null,
        hasTime: false,
        isDone: false,
        sortOrder: 0,
        priority: 0,
        tags: null,
        notify: false,
        isPinned: false,
        recurrenceRule: null,
        recurrenceGroupId: null,
        reminderSyncStatus: SyncStatus.pendingPush,
        createdAt: todayStart,
      );

      // Today has 2 undone to-dos; "tomorrow" (what `todayProvider` reports
      // right after the simulated midnight rollover below) has 5.
      when(
        todos.watchBetween(todayStart, todayEnd),
      ).thenAnswer((_) => Stream.value([todo('a'), todo('b')]));
      when(todos.watchBetween(tomorrowStart, tomorrowEnd)).thenAnswer(
        (_) => Stream.value([
          todo('c'),
          todo('d'),
          todo('e'),
          todo('f'),
          todo('g'),
        ]),
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingPrefs.completed, true);

      late final ProviderContainer container;
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
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp.router(
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
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      appRouter.go('/schedule');
      await tester.pumpAndSettle();

      expect(
        tester.widget<NavBadgeIcon>(find.byType(NavBadgeIcon).at(1)).count,
        2,
      );

      // Simulate the midnight rollover directly through the provider — the
      // same thing `TodayDate`'s own internal Timer does — rather than a
      // route navigation, since the whole point is that no navigation
      // happens across a real midnight.
      container.read(todayProvider.notifier).state = dateOnly(tomorrowStart);
      await tester.pump();
      // A newly-watched todosForDayProvider(tomorrow) family instance needs
      // an extra pump to receive its stream's first value.
      await tester.pump();

      expect(
        tester.widget<NavBadgeIcon>(find.byType(NavBadgeIcon).at(1)).count,
        5,
        reason:
            "AppShell's badge should follow todayProvider directly, not "
            'stay pinned to whatever day was current the last time its host '
            'route happened to rebuild',
      );
    },
  );

  group('iosTabSemanticLabel', () {
    // liquid_glass_widgets' GlassTab wraps its icon (which carries the
    // visible badge Text) in ExcludeSemantics and otherwise announces just
    // `label` — so a VoiceOver user on the iOS Liquid Glass tab bar hears
    // nothing about how many undone to-dos there are unless this function
    // spells it out. Plain test() (no widget needed): this is a pure
    // function specifically so Platform.isIOS not being true on the test
    // host is no obstacle to covering it.
    final l10n = AppL10nKo();

    test('includes the count when the badge is showing', () {
      const item = GlassNavItem(
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today,
        label: '시간표',
        badgeCount: 3,
      );

      expect(iosTabSemanticLabel(l10n, item), '시간표, 미완료 3개');
    });

    test('is just the plain label when there is no badge', () {
      const item = GlassNavItem(
        icon: Icons.wb_twilight_outlined,
        activeIcon: Icons.wb_twilight,
        label: '홈',
      );

      expect(iosTabSemanticLabel(l10n, item), '홈');
    });
  });
}
