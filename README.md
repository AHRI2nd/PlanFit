# PlanFit

A local-first personal calendar and to-do app for iOS and Android, built with Flutter. No account, no server — everything lives in a local SQLite database, with two-way sync to your device's own calendar as the only optional bridge to the outside.

## Features

- Day/week/month/year/agenda views sharing one selected date, with drag-and-drop create/move/resize
- Recurring events and to-dos (daily/weekly/monthly/yearly), color tags, templates, natural-language quick add
- Time-slotted to-dos with priority, tags, subtasks, smart lists (Today/Overdue/High priority/Pinned/by-tag)
- Local notifications with multiple reminder offsets and snooze
- Two-way sync with the device calendar, calendar subscriptions, JSON backup, ICS import/export
- Home screen widget (Android) with checkable to-dos
- Light/dark themes, iOS liquid-glass surfaces, Material 3 Expressive on Android

## Tech stack

Flutter/Dart · Riverpod 3 · drift (SQLite) · go_router · device_calendar_plus · flutter_local_notifications · home_widget

## Project structure

```
lib/
  core/            # DB, calendar sync, notifications, backup, quick-add parser
  design/          # Tokens, theme, shared widgets
  features/        # schedule, todo, settings, home, shell, onboarding, social (placeholder)
  l10n/            # ko/en ARB source strings
android/ ios/      # Native projects
test/ integration_test/
```

`EventRepository` sits behind a domain-layer interface — the one seam kept open for a future remote implementation.

## Getting started

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs  # drift/Riverpod/Freezed codegen
flutter gen-l10n   # after any .arb edit
flutter run
```

Build: `flutter build apk --debug|--release`, `flutter build ios`

Test: `flutter analyze`, `flutter test`

## Platform notes

- **iOS**: the home widget's WidgetKit Extension target has to be added once in Xcode (needs an App Group on both targets) — until then, widget calls are harmless no-ops.
- **Android**: release builds sign with the debug keystore by default — replace `signingConfig` in `android/app/build.gradle.kts` before shipping.

## Roadmap / known limitations

Out of scope for now: accounts/server backend, friend/sharing features, student/organization scheduling, business/shift scheduling, always-on background sync.

## License

[PolyForm Noncommercial 1.0.0](LICENSE) — free for any noncommercial use (personal, research, education). Commercial use requires a separate license.
