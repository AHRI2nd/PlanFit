import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/schedule/presentation/event_edit/lunar_date_picker.dart';
import 'package:planfit/l10n/app_localizations.dart';

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.initialDate});
  final DateTime initialDate;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  DateTime? picked;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ko'),
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await showLunarDatePicker(
                context: context,
                initialDate: widget.initialDate,
              );
              setState(() => picked = result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

void main() {
  Future<GlobalKey<_HarnessState>> pumpAndOpen(
    WidgetTester tester,
    DateTime initialDate,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initialDate: initialDate));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return key;
  }

  testWidgets(
    'the year wheel resets a stale leap flag the same way the month wheel '
    'already did — regression test: only the month wheel used to do this, '
    'so scrolling just the *year* wheel away from a leap year left the leap '
    'chip shown as selected-but-disabled instead of correctly turning off',
    (tester) async {
      // 2023's real leap month is 2 (윤2월), day 1 — 2024 has no leap month
      // 2, so moving only the year wheel forward by one should silently
      // turn the leap flag off, exactly like the month wheel's own onChanged
      // already does when it moves to a non-leap month.
      await pumpAndOpen(tester, DateTime(2023, 3, 22));

      final chipBefore = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(chipBefore.selected, isTrue);

      // One item forward on the year wheel (itemExtent: 36) — verified
      // empirically that dragging up by one item's height advances the
      // wheel's selection forward, not back.
      await tester.drag(
        find.byType(CupertinoPicker).at(0),
        const Offset(0, -36),
      );
      await tester.pumpAndSettle();

      // 2024 has no leap month 2 either, so the chip staying *disabled* is
      // correct (see FilterChip's own leapAvailable condition) — the actual
      // bug this guards against is `selected` staying stuck on `true` while
      // disabled, which would show as a chip the user can't turn off
      // themselves even though it's silently still claiming "leap".
      final chipAfter = tester.widget<FilterChip>(find.byType(FilterChip));
      expect(
        chipAfter.selected,
        isFalse,
        reason: 'the leap flag should reset once the year wheel moves to a '
            'year with no matching leap month',
      );
    },
  );

  testWidgets(
    'an out-of-range initial date is clamped into klc\'s supported range, '
    'not silently reseeded from today — regression test: this app\'s own '
    'native date picker allows years up to 2100, 50 years past what klc '
    'supports, and the old fallback discarded the user\'s actual selection '
    'with no warning whenever that happened',
    (tester) async {
      final key = await pumpAndOpen(tester, DateTime(2075, 6, 1));
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();

      // Clamped to klc's own solar ceiling (2050-12-31), not "whatever
      // today happens to be" when this test runs.
      final picked = key.currentState!.picked;
      expect(picked, isNotNull);
      expect(picked!.year, 2050);
    },
  );

  testWidgets(
    'a date before klc\'s range is clamped to its floor the same way',
    (tester) async {
      final key = await pumpAndOpen(tester, DateTime(1200, 1, 1));
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();

      final picked = key.currentState!.picked;
      expect(picked, isNotNull);
      expect(picked!.year, 1391);
    },
  );
}
