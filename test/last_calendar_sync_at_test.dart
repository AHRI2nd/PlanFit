import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/di.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts null with nothing persisted, then record() sets state and '
      'persists it for the next read', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    expect(container.read(lastCalendarSyncAtProvider), isNull);

    final now = DateTime(2026, 5, 1, 12, 30);
    await container.read(lastCalendarSyncAtProvider.notifier).record(now);

    expect(container.read(lastCalendarSyncAtProvider), now);

    // A fresh container (simulating an app restart) should read the
    // persisted value back rather than starting null again.
    final restarted = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(restarted.dispose);
    expect(restarted.read(lastCalendarSyncAtProvider), now);
  });
}
