import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/widgets/async_content.dart';
import 'package:planfit/l10n/app_localizations.dart';

void main() {
  testWidgets('query failures expose retry instead of empty data', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [AppL10n.delegate],
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: AsyncContent<List<int>>(
            value: AsyncError(StateError('unavailable'), StackTrace.empty),
            onRetry: () => retries++,
            builder: (_) => const Text('empty data'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('empty data'), findsNothing);
    await tester.tap(find.byType(TextButton));
    expect(retries, 1);
  });
}
