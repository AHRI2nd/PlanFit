# Disabled: Japanese (ja) localization

Japanese app-language support is paused for now — `app_ja.arb`'s 401
translated keys are machine-translated and hadn't had a native-speaker
review pass yet, and today's testing turned up several ja-specific layout
bugs (text overflow in the settings/schedule screens) on top of that.
Rather than delete the work, it's parked here, outside `lib/`, so it's
excluded from the analyzer/build entirely until it's ready.

## What's here

- `app_ja.arb` — the original Japanese translation source (belongs in
  `lib/l10n/` when restored).
- `app_localizations_ja.dart` — the generated Dart file `flutter gen-l10n`
  produced from it (stale the moment `app_ja.arb` changes; regenerate
  rather than restoring this file directly — see below).

## What's NOT here (i.e. still live, but currently unreachable)

Removing `ja` from `AppL10n.supportedLocales` (done by moving `app_ja.arb`
out and re-running `flutter gen-l10n`) is what actually excludes it — a
device set to Japanese, or an in-app language override of `'ja'`, now
falls back to English. Everything else that was built alongside Japanese
support is untouched and harmless while unreachable:

- `Fmt._force12h`'s `locale.startsWith('ja')` branch (core/format.dart)
  and the `ja`-locale test coverage for `Fmt.*` in `test/format_test.dart`
  — these are locale-string-driven utility functions with no dependency
  on `AppL10n.supportedLocales`, so they still work correctly if ever
  called with `'ja'` again; nothing here needed touching.
- `holiday_calendar_service.dart`'s `'ja' -> 'JP'` default-country branch,
  and the `'JP'` entry in the holiday-country *picker* itself (a separate
  feature — any user, in any app language, can already subscribe to
  Japan's holiday calendar; that was intentionally left alone).
- `quick_add_parser.dart`'s Japanese date/time phrase recognition.
- `settings_screen.dart`'s `_LanguageRow._nativeNames` still has a
  `'ja': '日本語'` entry — that map is only ever looked up for locales in
  `AppL10n.supportedLocales` (`for (final locale in
  AppL10n.supportedLocales) ... _nativeNames[locale.languageCode]`), so
  with `ja` out of that list this entry is unreachable, same as the
  items above; left in place rather than deleted so the language picker
  needs no further changes the moment `ja` is restored.

iOS's own per-app Language list used to still offer "日本語" (`ios/Runner/
ja.lproj/InfoPlist.strings` + `ja` in `Runner.xcodeproj`'s `knownRegions`)
even with the app itself falling back to English — confusing enough on
its own (picking 日本語 there did nothing) that this has since been
removed too: `ja.lproj` deleted, and its `PBXFileReference`/
`PBXVariantGroup` entry plus the `knownRegions` entry removed from
`project.pbxproj` by hand (`plutil -lint` used to confirm the edit kept
the file valid, and a full clean rebuild — `flutter clean` +
`rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*` — to confirm
Xcode actually stopped bundling `ja.lproj`, since an incremental build
had been seen to keep shipping the old one even after the pbxproj no
longer listed it). Re-adding `ja` back to the Xcode project is part of
re-enabling below now, not a separate step to "revisit".

## To re-enable

1. `git mv l10n_disabled/app_ja.arb lib/l10n/app_ja.arb`
2. `flutter gen-l10n` (regenerates `lib/l10n/app_localizations*.dart`,
   including a fresh `app_localizations_ja.dart` — the copy in this
   folder can be deleted once that succeeds).
3. Get the ja strings reviewed by an actual Japanese speaker first if
   that still hasn't happened.
4. `flutter analyze` && `flutter test` — expect ja-specific assertions to
   need restoring in `test/notification_service_test.dart` and
   `test/settings_controller_language_test.dart` (they were adjusted to
   expect the English-fallback behavior while ja was disabled).
5. Restore iOS's native Japanese localization: recreate
   `ios/Runner/ja.lproj/InfoPlist.strings` (see en.lproj/ko.lproj for the
   two keys it needs) and add `ja` back to both `knownRegions` and the
   `InfoPlist.strings` `PBXVariantGroup` in `Runner.xcodeproj/
   project.pbxproj` — ideally through Xcode's own Info panel (Project ➝
   Info ➝ Localizations ➝ +) rather than by hand, so Xcode itself
   generates and verifies the entries instead of hand-editing the pbxproj
   again.
