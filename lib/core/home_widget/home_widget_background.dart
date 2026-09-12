import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/schedule/application/schedule_providers.dart'
    show dateOnly;
import '../../features/todo/domain/todo_notification_sync.dart';
import '../date_math.dart';
import '../db/app_database.dart';
import '../notifications/notification_id_allocator.dart';
import '../notifications/notification_service.dart';
import 'home_widget_sync.dart';

/// Runs two kinds of HomeScreen widget background work — registered once
/// via `HomeWidget.registerInteractivityCallback` in main.dart. Android
/// invokes this in a fresh, headless Flutter engine spun up specifically
/// for the occasion — it shares no state with a foreground app instance,
/// so everything it needs (the database, the widget push) is opened fresh
/// here and torn down before returning.
///
/// - `toggle-todo?id=...`: a checkbox tap (see `PlanFitWidgetProvider.kt`'s
///   `toggleTodoIntent` and `HomeWidgetBackgroundReceiver` in
///   AndroidManifest.xml).
/// - `refresh-widget`: a periodic data refresh with no user gesture behind
///   it, enqueued directly from `PlanFitWidgetProvider.kt`'s `onUpdate()`
///   (piggybacking on the system's own widget update cadence — see its
///   `maybeRefreshWidgetData` doc comment for why this exists at all: the
///   widget would otherwise only ever show data as fresh as the last time
///   the app was foregrounded or a checkbox was tapped, silently going
///   stale — still showing yesterday's to-dos, or an event that already
///   started — for however long the app stays unopened).
///
/// Both branches end the same way: recompute "today" fresh (never trust a
/// timestamp captured before this callback started) and push it, closing
/// the loop back to a redrawn widget either way.
///
/// Must be a top-level function annotated `@pragma('vm:entry-point')` so
/// the compiler doesn't strip it — home_widget looks it up by callback
/// handle from native code, not by a normal Dart call.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (uri == null) return;

  final db = AppDatabase();
  try {
    await handleHomeWidgetUri(uri, db);
  } finally {
    await db.close();
  }
}

/// The actual per-uri logic, split out from [homeWidgetBackgroundCallback]
/// so a test can drive it against an in-memory [db] (and, via
/// [notificationService], a fake notification port) — the real entry point
/// above always opens an on-disk [AppDatabase] and a real
/// [NotificationService], both of which need platform channels a plain
/// `flutter test` doesn't have.
Future<void> handleHomeWidgetUri(
  Uri uri,
  AppDatabase db, {
  NotificationService? notificationService,
}) async {
  if (uri.host == 'toggle-todo') {
    final id = uri.queryParameters['id'];
    if (id == null || id.isEmpty) return;
    final todo = await db.todoDao.findById(id);
    // Already deleted (e.g. from the app) between the widget being drawn
    // and the tap landing — nothing to toggle, but still worth falling
    // through to refresh in case the deletion itself hasn't been pushed
    // to the widget yet.
    if (todo != null) {
      await db.todoDao.setDone(id, !todo.isDone);
      // Every other place that can flip isDone (TodoController.toggle)
      // keeps the due-time reminder in step — marking done here cancels
      // it too, so a to-do checked off from the widget doesn't still fire
      // a "you forgot this" alert for something already done. Fresh
      // NotificationService (and the SharedPreferences-backed allocator it
      // needs to actually schedule/cancel anything — see
      // NotificationIdAllocator's own doc) unless a test already supplied
      // one, same as this whole callback getting its own fresh AppDatabase
      // — nothing survives between invocations of a headless background
      // isolate.
      final updated = await db.todoDao.findById(id);
      if (updated != null) {
        final notifications =
            notificationService ?? await _defaultNotificationService();
        await syncTodoNotification(notifications, updated);
      }
    }
  } else if (uri.host != 'refresh-widget') {
    return;
  }

  final today = dateOnly(DateTime.now());
  final upcoming = await db.eventDao
      .watchUpcoming(DateTime.now(), limit: 4)
      .first;
  final todayTodos = await db.todoDao
      .watchBetween(today, addCalendarDays(today, 1))
      .first;
  await HomeWidgetSync.push(upcomingEvents: upcoming, todayTodos: todayTodos);
}

/// Same construction `lib/core/di.dart`'s `notificationServiceProvider` uses
/// for every foreground call site — built fresh here since this headless
/// isolate has no Riverpod container (and thus no already-loaded
/// [SharedPreferences] instance) to read one from.
Future<NotificationService> _defaultNotificationService() async {
  final prefs = await SharedPreferences.getInstance();
  return NotificationService(
    notificationIdAllocator: NotificationIdAllocator(prefs),
  );
}
