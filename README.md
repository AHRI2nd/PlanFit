# PlanFit

**PlanFit** is a local-first personal calendar and to-do app for iOS and Android, built with Flutter. It focuses on a single idea: your day, seen as a flow of time. There's no account, no server, and no cloud sync of your data by default — everything lives in a local SQLite database on your device, with two-way sync to your device's own calendar app as the only optional bridge to the outside.

> Personal-use MVP scope: account/login, friend graphs, schedule sharing, and student/organization features are explicitly out of scope for now (see [Roadmap](#roadmap--known-limitations)).

## Features

### Calendar
- Day, week, month, year, and agenda (flat list) views, all sharing one selected-date context
- Drag-and-drop event creation, moving, and resizing in the day/week timeline
- Recurring events (daily/weekly/monthly/yearly), including:
  - Multiple weekdays for a weekly repeat (e.g. every Mon/Wed/Fri)
  - Ending a series either on a date or after a fixed number of occurrences
  - "Apply to this and future occurrences" editing, alongside single-occurrence edits
- Color tags (presets or a full custom color picker), event location, multi-day all-day bars on the month view
- Event templates for frequently-created events, and one-tap duplication
- Multi-select (long-press) bulk delete with undo, in the agenda view
- Natural-language quick add ("내일 오후 3시 회의" → date/time/title parsed automatically)

### To-dos
- Time-slotted to-dos per day, with an explicit "no specific time" bucket
- Priority levels, free-form tags, and a checkable subtask list per to-do
- Recurring to-dos, manual drag-to-reorder (for the no-time bucket), and pinning important items
- Multi-select bulk complete/delete with undo
- Smart lists: Today, Overdue, High priority, Pinned, and by-tag views
- Optional auto-archive of completed to-dos after a configurable retention period

### Notifications
- Local notifications for events and to-dos, with multiple reminder offsets per item (e.g. "at start" + "10 min before" + "1 day before")
- Snooze action directly from the notification, no need to open the app
- Graceful fallback from exact to inexact alarm scheduling when Android's exact-alarm permission is denied
- Works around iOS's ~64 pending-notification cap by scheduling only the near-term window and refilling on each foreground resume

### Sync & Backup
- Two-way sync with the device's own calendar (iOS EventKit / Android CalendarProvider) via a dedicated "PlanFit" calendar, reconciled on every foreground resume
- Subscribe to other calendars on the device as a read-only, continuously mirrored source (distinct from a one-time import)
- Local JSON export/import for full backups, plus scheduled automatic local backups with retention
- Standard iCalendar (`.ics`) export/import for interoperating with other calendar apps, and single-event sharing via the OS share sheet

### Home screen widget (Android)
- Shows the next upcoming event and today's to-do progress, with to-dos checkable directly from the widget
- Compact and expanded (resizable) layouts, with a priority indicator per to-do
- Refreshes its data on a periodic background cadence, not just when the app is opened

### Search & organization
- Unified search across events and to-dos, with color-tag/date-range filters for events and tag/priority filters for to-dos
- Adjustable week-start day (Monday or Sunday), applied consistently across the month grid, year view, and weekly stats

### Design
- A "time as the hero" visual language: a time-of-day gradient (dawn → day → night) that moves across the home and day views
- iOS: liquid-glass bottom tab bar and surfaces where supported
- Android: Material 3 Expressive-leaning theme
- Light and dark themes, WCAG AA contrast checked, reduced-motion support, home screen widget dark-mode variants

## Tech stack

| | |
|---|---|
| Framework | Flutter (Dart SDK `^3.12.2`) |
| State management | [Riverpod](https://riverpod.dev) 3 (`flutter_riverpod`, `riverpod_annotation`) |
| Local database | [drift](https://drift.simonbinder.eu) (SQLite ORM) via `drift_flutter` |
| Routing | [go_router](https://pub.dev/packages/go_router) with `StatefulShellRoute` for the tab shell |
| Calendar integration | [device_calendar_plus](https://pub.dev/packages/device_calendar_plus) (EventKit / CalendarProvider) |
| Notifications | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) + `timezone`/`flutter_timezone` |
| Home screen widget | [home_widget](https://pub.dev/packages/home_widget) |
| Sharing / files | `share_plus`, `file_selector` |
| Localization | `flutter_localizations` + ARB files (Korean default, English included) |
| Codegen | `build_runner`, `drift_dev`, `riverpod_generator`, `freezed`, `json_serializable` |
| Testing | `flutter_test`, `integration_test`, `mockito` |

## Project structure

```
lib/
  app.dart                 # Root widget: theme, localization, router, foreground-resume hooks
  main.dart                # Entry point: ProviderScope, timezone init
  core/
    db/                     # drift Database, tables, DAOs, migrations
    calendar_sync/          # OS calendar service + reconciliation engine
    notifications/          # Local notification scheduling
    backup/                 # JSON backup/restore, auto-backup, ICS import/export
    home_widget/            # HomeScreen widget data sync + background callback
    quick_add/              # Natural-language quick-add parser
    routing/                # go_router configuration
  design/                   # Design tokens, theme, glass widgets, shared components
  features/
    shell/                  # 4-tab shell (Home / Schedule / Social / Settings)
    home/                   # Home tab: today summary, upcoming events, to-do progress
    schedule/                # Day/week/month/year/agenda views, event CRUD, recurrence
    todo/                    # Time-slotted to-dos, subtasks, smart lists
    settings/                # Notification/sync settings, backup, permissions
    social/                  # Placeholder shell — friend/sharing features are out of MVP scope
    onboarding/              # First-run intro + permission requests
  l10n/                      # app_ko.arb / app_en.arb source strings
android/                    # Native Android project (widget provider, manifest, Gradle config)
ios/                        # Native iOS project (Xcode project, Info.plist)
test/                       # Unit and widget tests
integration_test/           # End-to-end test scaffold
```

Architecturally, `EventRepository` sits behind an interface in the domain layer; the UI, the calendar sync engine, and the notification scheduler all go through it. That's the one seam deliberately kept open for a future remote/shared implementation, should account-based features ever be added.

## Getting started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (a recent stable release; developed against Flutter 3.44.x / Dart 3.12+)
- Xcode (for iOS) and/or Android Studio + an Android SDK (for Android)
- A connected device or simulator/emulator

### Setup

```bash
flutter pub get
```

Generate code for drift (database), Riverpod, Freezed, and JSON serialization:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Generate localization classes from the ARB files (needed after any `.arb` edit):

```bash
flutter gen-l10n
```

### Run

```bash
flutter run
```

### Build

```bash
flutter build apk --debug      # Android debug APK
flutter build apk --release    # Android release APK (see Platform notes below)
flutter build ios              # iOS (requires the Xcode widget extension setup below)
```

## Testing

```bash
flutter analyze   # Static analysis
flutter test      # Unit + widget tests
```

If a widget test's `@GenerateMocks(...)` annotations change, mocks need regenerating the same way as the database/codegen step above (`flutter pub run build_runner build --delete-conflicting-outputs`) — this project's bundled Dart SDK must be used for that, not a system-installed `dart`, due to a version mismatch.

## Platform notes

### iOS
The home screen widget's data-sync code is in place, but the WidgetKit Extension target itself has to be added once in Xcode — this can't be done via plain file edits (it needs an App Group configured on both the Runner and the extension target). Until that's set up, widget calls on iOS are harmless no-ops.

### Android
- The release build currently signs with the debug keystore (Flutter's default template state) — replace `signingConfig` in `android/app/build.gradle.kts` with your own keystore before shipping to the Play Store.
- `flutter build apk --debug` is the way to validate native Android changes (widget provider, manifest, Gradle config) — `flutter analyze` only covers the Dart side.
- The app currently prints a build-time warning about five plugins applying their own Kotlin Gradle Plugin (KGP) rather than Flutter's "built-in Kotlin" mechanism. This is upstream-blocked as of this writing (confirmed: none of the affected plugins have a version that's migrated yet) — it doesn't fail the build today, just something to re-check after upgrading Flutter or those plugins.

## Roadmap / known limitations

Deliberately out of scope for the current MVP (interfaces are kept extensible where relevant, but nothing here is implemented):
- Accounts, sign-in, or any server backend
- Friend/social graph and schedule sharing (the Social tab is a placeholder shell)
- Student/organization group scheduling and announcements
- Business/shift scheduling and wage calculation
- RRULE authoring beyond what's described above (no BYMONTHDAY, BYSETPOS, etc.)
- Always-on background sync (sync happens on foreground resume, not continuously)
