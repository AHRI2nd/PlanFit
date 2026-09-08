import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/core/notifications/notification_service.dart';
import 'package:planfit/core/onboarding_prefs.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/onboarding/presentation/onboarding_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the real plugin-backed service so `_finish()` (fired by
/// both the skip button and the final page's CTA) never touches a platform
/// channel that isn't wired up in a widget test.
class _FakeNotificationService extends NotificationService {
  @override
  Future<bool> requestPermission() async => true;
}

/// Stands in for a real (known) failure mode — a PlatformException from the
/// underlying flutter_local_notifications call.
class _ThrowingNotificationService extends NotificationService {
  @override
  Future<bool> requestPermission() =>
      throw Exception('permission request failed');
}

/// Counts calls and lets the test hold [requestPermission] open — stands in
/// for the OS permission dialog actually being on screen, awaiting the
/// user's answer, while a second tap on "시작하기" fires in the meantime.
class _CountingDelayedNotificationService extends NotificationService {
  var requestPermissionCalls = 0;
  final _gate = Completer<void>();

  void openGate() => _gate.complete();

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls++;
    await _gate.future;
    return true;
  }
}

void main() {
  Future<SharedPreferences> pumpOnboarding(
    WidgetTester tester, {
    NotificationService? notificationService,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(path: '/home', builder: (_, _) => const Text('HOME_STUB')),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationServiceProvider.overrideWithValue(
            notificationService ?? _FakeNotificationService(),
          ),
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
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  testWidgets('paging reaches the last page and swaps Next for Get started', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    expect(find.text('하루를 시간의 흐름으로'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
    expect(find.text('시작하기'), findsNothing);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('일정과 할 일을 한 곳에'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('놓치지 않게 알려드려요'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
    // The skip button is hidden once there's nothing left to skip past.
    expect(find.text('건너뛰기'), findsNothing);
  });

  testWidgets(
    'Get started on the last page marks onboarding complete and leaves the screen',
    (tester) async {
      final prefs = await pumpOnboarding(tester);

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      expect(prefs.getBool(OnboardingPrefs.completed), isTrue);
      expect(find.text('HOME_STUB'), findsOneWidget);
    },
  );

  testWidgets('skip completes onboarding immediately from the first page', (
    tester,
  ) async {
    final prefs = await pumpOnboarding(tester);

    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(prefs.getBool(OnboardingPrefs.completed), isTrue);
    expect(find.text('HOME_STUB'), findsOneWidget);
  });

  testWidgets(
    'Get started still leaves the screen even when the notification '
    'permission request throws — regression test: _finish() used to have '
    'no catch around that call, so the exception propagated out and '
    "skipped context.go('/home') entirely, even though "
    'OnboardingPrefs.completed was already persisted just above — a '
    'same-session stuck screen masked on the next launch (which reads '
    "completed and redirects straight past onboarding, hiding the bug)",
    (tester) async {
      final prefs = await pumpOnboarding(
        tester,
        notificationService: _ThrowingNotificationService(),
      );

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      expect(prefs.getBool(OnboardingPrefs.completed), isTrue);
      expect(
        find.text('HOME_STUB'),
        findsOneWidget,
        reason:
            'a thrown permission request must not prevent navigating home',
      );
    },
  );

  testWidgets(
    'tapping Get started twice while the permission dialog is still up '
    'only requests permission once — regression test: _finish() had no '
    'guard against a second call landing while the first was still '
    'mid-await (e.g. the OS permission dialog on screen), so a second tap '
    'fired a second concurrent requestPermission() platform-channel call',
    (tester) async {
      final service = _CountingDelayedNotificationService();
      final prefs = await pumpOnboarding(
        tester,
        notificationService: service,
      );

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('시작하기'));
      await tester.pump();
      // Still mid-flight — requestPermission's own future hasn't resolved.
      await tester.tap(find.text('시작하기'));
      await tester.pump();

      expect(service.requestPermissionCalls, 1);

      service.openGate();
      await tester.pumpAndSettle();

      expect(prefs.getBool(OnboardingPrefs.completed), isTrue);
      expect(find.text('HOME_STUB'), findsOneWidget);
    },
  );
}
