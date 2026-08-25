import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/widgets/friendly_error_widget.dart';
import 'package:planfit/l10n/app_localizations.dart';

class _Boom extends StatelessWidget {
  const _Boom();

  @override
  Widget build(BuildContext context) => throw StateError('boom');
}

void main() {
  final originalBuilder = ErrorWidget.builder;
  setUp(() => ErrorWidget.builder = buildFriendlyErrorWidget);
  tearDown(() => ErrorWidget.builder = originalBuilder);

  testWidgets(
    'a widget that throws during build renders the friendly fallback, not '
    "Flutter's default red/gray error box",
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(body: _Boom()),
        ),
      );
      // _Boom's build() throwing is the whole point of this test — consume
      // it so the framework doesn't also fail the test over the very error
      // ErrorWidget.builder exists to present gracefully.
      expect(tester.takeException(), isA<StateError>());

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Test environment defaults to en_US — see the ko-specific assertion
      // below for confirmation this is actually the localized string, not
      // just the widget's own hardcoded English fallback.
      expect(find.text('Something went wrong'), findsOneWidget);
      // Flutter's default ErrorWidget renders its message in a Text with an
      // ErrorDescription-derived string — confirming ours replaced it rather
      // than just rendering alongside it.
      expect(find.textContaining('StateError'), findsNothing);
    },
  );

  testWidgets('resolves the Korean string under a ko locale', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: _Boom()),
      ),
    );
    expect(tester.takeException(), isA<StateError>());

    expect(find.text('문제가 발생했어요'), findsOneWidget);
  });
}
