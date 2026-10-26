import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/settings/application/integration_health.dart';
import 'package:planfit/features/settings/presentation/integration_status_screen.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:planfit/features/settings/application/app_settings.dart';
import 'package:planfit/features/settings/application/settings_controller.dart';

class _Settings extends SettingsController {
  @override
  AppSettings build() => const AppSettings();
}

void main() {
  testWidgets(
    'disabled features and missing permissions have distinct states',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsControllerProvider.overrideWith(_Settings.new),
            integrationHealthProvider.overrideWith(
              (ref) async => const [
                IntegrationHealth(
                  IntegrationFeature.notifications,
                  IntegrationState.needsPermission,
                ),
                IntegrationHealth(
                  IntegrationFeature.calendar,
                  IntegrationState.off,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ko'),
            supportedLocales: AppL10n.supportedLocales,
            localizationsDelegates: AppL10n.localizationsDelegates,
            home: const IntegrationStatusScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('권한이 필요해요'), findsOneWidget);
      expect(find.text('꺼져 있어요'), findsOneWidget);
      expect(
        find.byKey(const Key('health-notifications-action')),
        findsOneWidget,
      );
    },
  );
}
