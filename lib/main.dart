import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/di.dart';
import 'core/home_widget/home_widget_background.dart';
import 'features/settings/application/settings_controller.dart';
import 'core/time/timezone_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Locale-aware date formatting (used by the calendar and formatters).
  await initializeDateFormatting();
  await TimezoneSetup.init();
  // Pre-warms the Liquid Glass shaders; the bottom nav bar uses real shader
  // glass on iOS (see AppShell), a no-op elsewhere since nothing else in the
  // tree reaches for Glass* widgets.
  await LiquidGlassWidgets.initialize();

  // Wires up the HomeScreen widget's checkbox taps to
  // homeWidgetBackgroundCallback (see its own doc) — must be re-registered
  // on every launch, same as flutter_local_notifications' handlers, since
  // the OS doesn't remember Dart callback handles across process restarts.
  // Best-effort, same reasoning as every other home-widget call: a missing
  // iOS extension (see HomeWidgetSync's doc) must never block startup.
  try {
    await HomeWidget.registerInteractivityCallback(
        homeWidgetBackgroundCallback);
  } catch (_) {
    // Ignored — see comment above.
  }

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Warm up the notification plugin (channels, timezone-aware scheduling).
  await container.read(notificationServiceProvider).init();
  // Building the settings controller applies persisted config to the services.
  container.read(settingsControllerProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: LiquidGlassWidgets.wrap(child: const PlanFitApp()),
    ),
  );
}
