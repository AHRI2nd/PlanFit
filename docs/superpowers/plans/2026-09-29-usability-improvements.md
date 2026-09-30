# PlanFit Usability Improvements Implementation Plan

> **For agentic workers:** Execute the tasks in order, checking each result before moving on. The project owner handles all commits and pushes.

**Goal:** Make core to-do lists consistently reachable and ensure permission prompts, search results, quick add, and backup messaging match what users expect.

**Architecture:** Promote the existing smart-list screen to a fourth shell branch and add a complete cross-day list. Keep the other changes within their existing presentation flows; do not change stored event, to-do, or backup formats. Update Korean and English copy together.

**Tech Stack:** Flutter, Riverpod, go_router, drift, ARB localization, flutter_test.

**Spec:** `Transfer.md`, section “2026-09-29 앱 구성·사용성 조사”; the decisions and acceptance criteria below complete that audit into an implementation brief.

## Understanding and design decisions

- Target: a personal user must be able to reach every to-do from a stable main navigation path, understand what each action will do, and know what a local backup can protect.
- Navigation options considered: (A) add a fourth `할 일` tab, (B) keep three tabs and add a permanent home link, (C) add a to-do entry inside the schedule header. Choose A: it keeps a core feature reachable on every screen and gives its badge a clear destination; B and C require first finding another screen or expanding the home sheet.
- Recommended navigation: `홈 / 시간표 / 할 일 / 설정`.
- The new `전체` smart-list filter shows every retained to-do, including completed items. Order unfinished pinned items first, then unfinished overdue items, then other unfinished items by date, and completed items last (most recently completed first). Keep the existing Today/Overdue/Priority/Pinned/Tag filters.
- Move the current “today's unfinished to-dos” badge from `시간표` to `할 일`. Do not repurpose it to count calendar events.
- Search result taps for to-dos open `showTodoDetailSheet` directly above search results. Closing the sheet returns to the query and filters. Event search behavior remains as it is.
- `건너뛰기` completes onboarding without requesting notification access. The final-page `시작하기` still requests access. A separate persisted defer flag prevents the root app's legacy first-launch fallback from immediately asking after a skip; the user can later grant access through an existing permission-triggering setting.
- Quick event add retains its selected-date/09:00/one-hour fallback, but displays the interpreted date and time before save. Show that the time is a default when no time was recognized. Preserve the single-tap Save action.
- Automatic backups stay local and run when the app starts or resumes after 24 hours have elapsed. Explain this exact behavior, show that the copies remain in app storage, and offer an explicit action to share a fresh full backup outside the app. Do not imply that the internal copies guarantee recovery after device loss or app deletion.

## Global constraints

- Work in local files. Do not commit, push, change the backup format, or add `Co-Authored-By` trailers.
- Keep `Transfer.md` ignored by Git; update it after a large change or at task completion.
- Use existing UI components, spacing, and localization patterns. Add no dependency for these changes.
- Preserve current platform differences: iOS Liquid Glass and Android GlassNavBar must both work with four items.
- Do not clear emulator/simulator data to validate navigation; test with controlled widget data or a separate test installation.

## Review focus

- Zero to-dos, only future to-dos, and more than 50 to-dos must all provide a route to the complete list.
- A selected smart-list filter and scroll state should survive switching to another main tab and back; tapping the active tab should follow the existing root-reset convention.
- A skipped onboarding must not produce a notification request on the next app start; existing users with the old preference state must retain their current behavior.
- Parsed dates near midnight, locale-specific time formats, and unrecognized time phrases must produce a truthful quick-add preview.
- A backup run that failed or an app left unopened for days must never be described as a successful daily backup.

---

### Task 1: Stable to-do destination and truthful badge

**Files:** `lib/core/routing/app_router.dart`, `lib/features/shell/app_shell.dart`, `lib/features/home/presentation/home_screen.dart`, `lib/features/todo/presentation/todo_smart_list_screen.dart`, `lib/core/db/daos/todo_dao.dart`, `lib/features/todo/application/todo_providers.dart`, `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb`, generated localization files, and related DAO/widget tests.

- [ ] Add a `/todos` `StatefulShellBranch` between schedule and settings, using `TodoSmartListScreen` as its root. Give the fourth nav item a to-do icon and localized `할 일` / `To-dos` label; put `undoneToday` on that item only.
- [ ] Add `TodoDao.watchAll()` and `allTodosProvider`, then add the `전체` / `All` filter to the smart-list screen. Include completed records at the end and use lazy list rendering already present in `_TodoListView`.
- [ ] Make `전체` the default filter for the main to-do tab. Change home’s conditional “view all” and “more” links to open `/todos` at `전체`; make a persistent `모아보기` entry visible even when today and home’s abbreviated list are empty. Avoid a second pushed copy of the smart-list screen.
- [ ] Add widget/DAO tests for zero items, only future items, more than 50 items, completed ordering, all four tab labels and badge destination, and reselecting the current branch.
- [ ] Verify iOS/Android navigation bar layout at narrow phone width, 2× text scale, and iPad width. If four items cannot remain legible, tighten bar spacing or labels without shrinking tap targets below 44×44.

### Task 2: Search result takes the user to the item

**Files:** `lib/features/schedule/presentation/search/event_search_screen.dart`, `test/widgets/event_search_screen_test.dart`.

- [ ] Change the to-do result callback to open `showTodoDetailSheet(context, todo)` while retaining the search screen, query, and filters underneath.
- [ ] Test opening a to-do result, dismissing its sheet, and finding the same query/results still visible. Check completed and no-time results too.

### Task 3: Onboarding skip respects the skipped explanation

**Files:** `lib/core/onboarding_prefs.dart`, `lib/features/onboarding/presentation/onboarding_screen.dart`, `lib/app.dart`, onboarding/root widget tests.

- [ ] Add a persisted `notificationDeferred` flag. Use distinct skip and get-started completion paths; skip sets completed and deferred without calling `requestPermission`, while get-started preserves the guarded request and prompted flag.
- [ ] Make `_maybeRequestNotificationPermission` return when either prompted or deferred. Keep migration behavior for previously completed installs with neither flag.
- [ ] Test first-page and second-page skip with a counting notification fake, final-page Get Started, and a simulated app restart after skip.

### Task 4: Quick event add exposes its interpreted schedule

**Files:** `lib/features/schedule/presentation/event_edit/quick_add_sheet.dart`, `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb`, generated localization files, quick-add widget tests.

- [ ] Derive the preview from the same parsed input, anchor day, and fallback values used by `_submit`; avoid two independently maintained parsers or defaults.
- [ ] Show `date · start–end` as soon as the input is nonempty, with a localized “default 09:00” note only when no time was recognized. Recompute as text changes and format using the user's display-time preference.
- [ ] Test explicit date/time, date-only, time-only, and plain-title cases; confirm the saved `EventInput` matches the visible preview.

### Task 5: Automatic backup explains its real protection

**Files:** `lib/features/settings/presentation/auto_backup_screen.dart`, `lib/features/settings/presentation/settings_screen.dart` or a small shared export helper, `lib/l10n/app_ko.arb`, `lib/l10n/app_en.arb`, generated localization files, auto-backup/settings widget tests.

- [ ] Replace the “every 24 hours” claim with “when the app opens or resumes, if 24 hours have passed since the last successful backup”; state that the last seven internal copies remain in app storage. Explain that users should export a copy to external storage for device-loss recovery.
- [ ] Add an `외부에 백업 저장` / `Save a copy elsewhere` action on the auto-backup screen using the existing full-backup export and share-sheet path. Keep a shared implementation so the settings action and new action have the same cleanup/error behavior.
- [ ] Test the revised empty and populated states, the external-export action, share cancellation, and export failure. Do not report a new backup as successful solely because 24 hours have passed.

### Task 6: Integrated verification and handoff

- [ ] Run focused tests for Tasks 1–5, then `flutter analyze`, `flutter test`, and `git diff --check`. Regenerate localization output with `flutter gen-l10n` after ARB edits.
- [ ] Build and install current iOS Simulator Debug and Android Debug artifacts, following `Transfer.md` UI verification policy. Check onboarding, four-tab navigation, empty/future/backlog to-dos, search, quick add, backup copy, Korean/English, dark mode, narrow width, and 2× text scale. Record unavailable simulators/devices explicitly rather than claiming visual verification.
- [ ] Update `Transfer.md` with results, remaining limitations, branch/HEAD, and working-tree state. Leave commits and pushes for the user.

## Order and variables

1. Implement Task 1 first because it defines the final to-do destination and badge meaning. Tasks 2–5 can then be completed independently; finish with Task 6.
2. If the existing smart-list screen's AppBar or FAB collides with the floating bar as a shell root, adjust only that screen's clearance and test both platforms.
3. If the full-list stream is slow with a large retained history, add DAO-level pagination or a completed-item filter before shipping; do not silently cap the list as home does.
4. If platform backup inclusion cannot be verified, keep copy explicit about app-local storage and avoid any guarantee about OS cloud restore.
