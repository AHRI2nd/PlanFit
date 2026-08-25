import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts at the built-in default with nothing persisted, then set() + '
      'persist() carries the value to the next read (app restart)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(monthCalendarRowHeightProvider),
      MonthCalendarRowHeight.defaultHeight,
    );

    container.read(monthCalendarRowHeightProvider.notifier).set(70);
    expect(container.read(monthCalendarRowHeightProvider), 70);
    await container.read(monthCalendarRowHeightProvider.notifier).persist();

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(monthCalendarRowHeightProvider), 70);
  });

  test('set() clamps to [min, max] so a long drag can\'t shrink the grid to '
      'nothing or blow past a sane maximum', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(monthCalendarRowHeightProvider.notifier).set(-500);
    expect(
      container.read(monthCalendarRowHeightProvider),
      MonthCalendarRowHeight.min,
    );

    container.read(monthCalendarRowHeightProvider.notifier).set(500);
    expect(
      container.read(monthCalendarRowHeightProvider),
      MonthCalendarRowHeight.max,
    );
  });

  test('a value persisted from an old build outside the current [min, max] '
      'range is clamped on load too', () async {
    SharedPreferences.setMockInitialValues({
      'schedule.monthCalendarRowHeight': 500.0,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(monthCalendarRowHeightProvider),
      MonthCalendarRowHeight.max,
    );
  });
}
