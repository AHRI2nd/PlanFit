import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/schedule/presentation/calendar_legend_sheet.dart';
import 'package:planfit/l10n/app_localizations.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCalendarLegendSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping the info button opens a sheet explaining all 3 dot '
      'colors, plus the multi-day-bar note', (tester) async {
    await pumpHost(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(tester.element(find.text('open')));
    expect(find.text(l10n.calendarLegendTitle), findsOneWidget);
    expect(find.text(l10n.calendarLegendOverdueTodo), findsOneWidget);
    expect(find.text(l10n.calendarLegendTodo), findsOneWidget);
    expect(find.text(l10n.calendarLegendEvent), findsOneWidget);
    expect(find.text(l10n.calendarLegendMultiDayBarNote), findsOneWidget);
  });
}
