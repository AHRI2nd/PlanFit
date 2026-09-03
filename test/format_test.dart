import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:planfit/core/format.dart';

void main() {
  setUpAll(() async {
    // Fmt.time/Fmt.hour construct DateFormat instances for 'ja' (and any
    // other non-'en' locale), which throws LocaleDataException until the
    // CLDR data behind them is loaded — flutter_test doesn't do this
    // automatically the way a real app run (via WidgetsFlutterBinding) does.
    await initializeDateFormatting();
  });

  group('Fmt.relative', () {
    final now = DateTime(2026, 1, 1, 12);

    test('an already-started event (target before now) reads as in progress', () {
      expect(
        Fmt.relative(now.subtract(const Duration(minutes: 1)), now, 'ko'),
        '진행 중',
      );
      expect(
        Fmt.relative(now.subtract(const Duration(hours: 2)), now, 'en'),
        'in progress',
      );
    });

    test('starting within the next minute reads as soon/now', () {
      expect(Fmt.relative(now.add(const Duration(seconds: 30)), now, 'ko'), '곧');
      expect(Fmt.relative(now, now, 'en'), 'now');
    });

    test('starting later this hour counts minutes', () {
      expect(
        Fmt.relative(now.add(const Duration(minutes: 45)), now, 'ko'),
        '45분 뒤',
      );
      expect(
        Fmt.relative(now.add(const Duration(minutes: 45)), now, 'en'),
        'in 45m',
      );
    });

    test('starting later today counts hours', () {
      expect(
        Fmt.relative(now.add(const Duration(hours: 5)), now, 'ko'),
        '5시간 뒤',
      );
      expect(
        Fmt.relative(now.add(const Duration(hours: 5)), now, 'en'),
        'in 5h',
      );
    });

    test('starting on a later day counts days', () {
      expect(
        Fmt.relative(now.add(const Duration(days: 3)), now, 'ko'),
        '3일 뒤',
      );
      expect(
        Fmt.relative(now.add(const Duration(days: 3)), now, 'en'),
        'in 3d',
      );
    });

    test('ja gets its own strings, not the en fallback', () {
      expect(
        Fmt.relative(now.subtract(const Duration(hours: 2)), now, 'ja'),
        '進行中',
      );
      expect(Fmt.relative(now, now, 'ja'), 'まもなく');
      expect(
        Fmt.relative(now.add(const Duration(minutes: 45)), now, 'ja'),
        '45分後',
      );
      expect(
        Fmt.relative(now.add(const Duration(hours: 5)), now, 'ja'),
        '5時間後',
      );
      expect(
        Fmt.relative(now.add(const Duration(days: 3)), now, 'ja'),
        '3日後',
      );
    });
  });

  group('Fmt.time / Fmt.hour — forced 12-hour across locales', () {
    // ja's own locale-preferred hour convention (DateFormat.jm/j) is
    // 24-hour, unlike ko/en's — a regression risk this group specifically
    // guards against: use24Hour:false must still force 12-hour for ja, not
    // silently fall through to its 24-hour default the way it did before
    // Fmt.time/Fmt.hour's `_force12h` helper existed.
    final pm = DateTime(2026, 1, 1, 15, 30); // 3:30 PM
    final am = DateTime(2026, 1, 1, 9, 5); // 9:05 AM

    test('use24Hour:true is always 24-hour, every locale', () {
      for (final locale in ['ko', 'en', 'ja']) {
        expect(Fmt.time(pm, locale, use24Hour: true), contains('15:30'));
        expect(Fmt.hour(15, locale, use24Hour: true), contains('15'));
      }
    });

    test("use24Hour:null (system) follows each locale's own convention", () {
      expect(Fmt.time(pm, 'ko', use24Hour: null), '오후 3:30');
      // intl's en CLDR data separates the time from AM/PM with U+202F
      // (narrow no-break space), not a plain space.
      expect(Fmt.time(pm, 'en', use24Hour: null), '3:30 PM');
      expect(Fmt.time(pm, 'ja', use24Hour: null), '15:30');
    });

    test('use24Hour:false forces 12-hour even for ja', () {
      expect(Fmt.time(pm, 'ko', use24Hour: false), '오후 3:30');
      expect(Fmt.time(pm, 'en', use24Hour: false), '3:30 PM');
      expect(Fmt.time(pm, 'ja', use24Hour: false), '午後 3:30');
      expect(Fmt.time(am, 'ja', use24Hour: false), '午前 9:05');
    });

    test('Fmt.hour forces 12-hour for ja the same way', () {
      expect(Fmt.hour(15, 'ja', use24Hour: false), '午後 3時');
      expect(Fmt.hour(9, 'ja', use24Hour: false), '午前 9時');
    });

    test(
      "a locale whose own 24-hour pattern quotes a literal 'h' isn't fooled "
      'into thinking it\'s already 12-hour — regression test: this app '
      "only ships ko/en/ja (none of which hit this), but _force12h's own "
      'contains(\'h\')/contains(\'a\') checks used to search the *whole* '
      'pattern string including quoted literal text, not just real fields. '
      "French's own `j` skeleton is exactly this case: `\"HH 'h'\"` — a "
      'real 24-hour HH field followed by the literal word "h" (heures), '
      'not a second hour field',
      () {
        // Not a supported locale in this app — reachable via intl's own
        // CLDR data directly, which is all Fmt.hour actually needs.
        expect(Fmt.hour(15, 'fr', use24Hour: true), contains('15'));
        final forced = Fmt.hour(15, 'fr', use24Hour: false);
        expect(forced, isNot(contains('15')));
        expect(forced, contains('3'));
      },
    );
  });
}
