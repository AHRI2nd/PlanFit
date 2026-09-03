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

  testWidgets(
    "the month wheel offers fewer than 12 months once scrolled to klc's "
    "upper-boundary year (2050) — regression test: it used to always offer "
    "all 12 regardless of year, so picking year 2050 + month 12 (both "
    "individually reachable, nothing tied them together) landed on a month "
    "with no valid day 1 at all — the day wheel then silently fell back to "
    'a fake 29-day range, and "Done" became a no-op with no feedback since '
    'the (year, month, day) combination could never actually convert',
    (tester) async {
      final key = await pumpAndOpen(tester, DateTime(2026, 3, 22));

      // Drag the year wheel forward to 2050 — the picker's own default
      // window already runs 1920-2050 (see _effectiveMinYear/MaxYear), so
      // this doesn't need the out-of-range-clamping path either fixture
      // above exercises.
      final yearsForward = 2050 - 2026;
      await tester.drag(
        find.byType(CupertinoPicker).at(0),
        Offset(0, -36.0 * yearsForward),
      );
      await tester.pumpAndSettle();

      final monthWheel = tester.widget<CupertinoPicker>(
        find.byType(CupertinoPicker).at(1),
      );
      expect(monthWheel.childDelegate.estimatedChildCount, lessThan(12));

      // Confirms Done is reachable at all from this state — the actual
      // failure mode this guards against was Done silently doing nothing.
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();
      expect(key.currentState!.picked, isNotNull);
    },
  );

  // Finds the Semantics widget wrapping a given wheel by its label — the
  // simpler, lower-level alternative to dispatching real SemanticsActions
  // through the semantics tree: `Semantics.properties` exposes the exact
  // same onIncrease/onDecrease closures a screen reader's increase/decrease
  // gesture would end up invoking, so calling them directly here exercises
  // the identical code path.
  Semantics wheelSemantics(WidgetTester tester, String label) {
    return tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == label);
  }

  group('screen-reader semantics', () {
    testWidgets(
      'each of the year/month/day wheels carries its own screen-reader '
      'label — regression test: CupertinoPicker\'s raw drag gesture isn\'t '
      'itself screen-reader-operable, so without a Semantics wrapper a '
      'VoiceOver/TalkBack user had no way to even discover these wheels, '
      'let alone operate them',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpAndOpen(tester, DateTime(2026, 3, 22));

        // Literal Korean strings (matching l10n.lunarDatePickerYear/Month/
        // Day for the 'ko' locale this harness pumps), same convention as
        // schedule_screen_test's own chevron-label regression test.
        expect(find.bySemanticsLabel('연도'), findsOneWidget);
        expect(find.bySemanticsLabel('월'), findsOneWidget);
        expect(find.bySemanticsLabel('일'), findsOneWidget);

        handle.dispose();
      },
    );

    testWidgets(
      'the day wheel\'s onIncrease/onDecrease move _day the same way '
      'dragging the wheel would, keeping the wheel controller in sync',
      (tester) async {
        await pumpAndOpen(tester, DateTime(2026, 3, 22));

        final dayController = tester
            .widget<CupertinoPicker>(find.byType(CupertinoPicker).at(2))
            .scrollController!;
        final before = int.parse(wheelSemantics(tester, '일').properties.value!);

        wheelSemantics(tester, '일').properties.onIncrease!();
        await tester.pump();
        expect(wheelSemantics(tester, '일').properties.value, '${before + 1}');
        // onIncrease bypasses the wheel's own onSelectedItemChanged (which
        // only fires from a real drag), so the controller doesn't move on
        // its own — the wheel's onIncrease closure has to jumpToItem it
        // explicitly the same way _clampDay already does, or the visible
        // wheel would silently fall out of sync with _day.
        expect(dayController.selectedItem, before + 1 - 1);

        wheelSemantics(tester, '일').properties.onDecrease!();
        await tester.pump();
        expect(wheelSemantics(tester, '일').properties.value, '$before');
        expect(dayController.selectedItem, before - 1);
      },
    );

    testWidgets(
      'the day wheel\'s onDecrease disables itself (no-op, not a crash) '
      'once driven down to day 1',
      (tester) async {
        await pumpAndOpen(tester, DateTime(2026, 3, 22));

        // Repeatedly decrease until the wheel itself reports there's
        // nothing left to decrease — mirrors what a screen reader does:
        // a null onDecrease means the swipe-down gesture is simply not
        // offered any more, rather than the app crashing or going negative.
        var guard = 0;
        while (wheelSemantics(tester, '일').properties.onDecrease != null) {
          wheelSemantics(tester, '일').properties.onDecrease!();
          await tester.pump();
          guard++;
          expect(guard, lessThan(40), reason: 'never reached day 1');
        }

        expect(wheelSemantics(tester, '일').properties.value, '1');
      },
    );

    testWidgets(
      'the year wheel\'s onIncrease resets a stale leap flag exactly like '
      'dragging the wheel already does (see the drag-based regression test '
      'above) — exercised here through the screen-reader semantic action '
      'instead, including the controller staying in sync',
      (tester) async {
        // 2023's real leap month is 2 (윤2월); 2024 has no leap month 2, so
        // moving only the year forward should silently turn the leap flag
        // off, same as the equivalent drag does.
        await pumpAndOpen(tester, DateTime(2023, 3, 22));

        final chipBefore = tester.widget<FilterChip>(find.byType(FilterChip));
        expect(chipBefore.selected, isTrue);

        final yearController = tester
            .widget<CupertinoPicker>(find.byType(CupertinoPicker).at(0))
            .scrollController!;

        wheelSemantics(tester, '연도').properties.onIncrease!();
        await tester.pump();

        expect(wheelSemantics(tester, '연도').properties.value, '2024');
        // _effectiveMinYear is 1920 here — well below 2023, so this default
        // window applies unwidened (see _effectiveMinYear's own doc).
        expect(yearController.selectedItem, 2024 - 1920);

        final chipAfter = tester.widget<FilterChip>(find.byType(FilterChip));
        expect(
          chipAfter.selected,
          isFalse,
          reason: 'the leap flag should reset once the year wheel moves to '
              'a year with no matching leap month',
        );
      },
    );

    testWidgets(
      'repeatedly triggering the year wheel\'s onIncrease reaches klc\'s '
      '2050 ceiling and clamps the month wheel in sync, the same as the '
      'drag-based path above',
      (tester) async {
        final key = await pumpAndOpen(tester, DateTime(2026, 3, 22));

        for (var i = 0; i < 2050 - 2026; i++) {
          wheelSemantics(tester, '연도').properties.onIncrease!();
          await tester.pump();
        }

        expect(wheelSemantics(tester, '연도').properties.value, '2050');
        // Already at the ceiling — one more increase must be a no-op, not
        // a crash or a year past what the wheel actually offers.
        expect(wheelSemantics(tester, '연도').properties.onIncrease, isNull);

        final monthWheel = tester.widget<CupertinoPicker>(
          find.byType(CupertinoPicker).at(1),
        );
        expect(monthWheel.childDelegate.estimatedChildCount, lessThan(12));

        await tester.tap(find.text('완료'));
        await tester.pumpAndSettle();
        expect(key.currentState!.picked, isNotNull);
      },
    );
  });
}
