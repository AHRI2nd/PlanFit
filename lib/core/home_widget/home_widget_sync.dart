import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';

import '../db/app_database.dart';

/// Builds the field map [HomeWidgetSync.push] JSON-encodes and writes in one
/// shot — pulled out as its own pure, top-level function (no platform
/// channel, no `Platform.isAndroid`/`isIOS` gate) purely so it's directly
/// unit-testable: `push` itself can't be driven from `flutter test` on a
/// non-Android/iOS host, since that gate short-circuits before doing
/// anything. [now] defaults to [DateTime.now] and only exists so a test can
/// pin `todos_uri`'s date deterministically.
Map<String, Object> buildWidgetSnapshot({
  required List<EventRow> upcomingEvents,
  required List<TodoRow> todayTodos,
  DateTime? now,
}) {
  final snapshot = <String, Object>{};

  for (var i = 0; i < HomeWidgetSync.maxEvents; i++) {
    final event = i < upcomingEvents.length ? upcomingEvents[i] : null;
    snapshot['event${i}_title'] = event?.title ?? '';
    snapshot['event${i}_time'] = event == null
        ? ''
        : HomeWidgetSync._time(event.startAt);
    // Deep-link read by PlanFitWidgetProvider.kt (and, once the iOS
    // extension exists, PlanFitWidget.swift) so tapping an event opens its
    // day in the schedule tab instead of just launching the app.
    snapshot['event${i}_uri'] = event == null
        ? ''
        : HomeWidgetSync.scheduleUri(event.startAt).toString();
  }

  final ordered = [
    ...todayTodos.where((t) => !t.isDone),
    ...todayTodos.where((t) => t.isDone),
  ];
  for (var i = 0; i < HomeWidgetSync.maxWidgetTodos; i++) {
    final todo = i < ordered.length ? ordered[i] : null;
    snapshot['todo${i}_id'] = todo?.id ?? '';
    snapshot['todo${i}_title'] = todo?.title ?? '';
    snapshot['todo${i}_done'] = todo?.isDone ?? false;
    snapshot['todo${i}_priority'] = todo?.priority ?? 0;
  }

  snapshot['todos_progress'] =
      '${todayTodos.where((t) => t.isDone).length}/${todayTodos.length}';
  snapshot['todos_uri'] = HomeWidgetSync.scheduleUri(
    now ?? DateTime.now(),
  ).toString();

  return snapshot;
}

/// Pushes a compact "next event + today's to-do progress" snapshot to the
/// native HomeScreen widget.
///
/// The Android side is fully wired (`PlanFitWidgetProvider.kt` +
/// `res/xml/home_widget_info.xml`). The iOS side needs a one-time WidgetKit
/// Extension target added in Xcode (App Groups can't be wired up from plain
/// file edits) — see docs/PROGRESS.md for the exact steps and the ready-made
/// Swift source. Until that target exists, calls here are harmless no-ops on
/// iOS: `HomeWidget` methods fail quietly and are swallowed by the caller.
///
/// [push] writes the entire snapshot as a single JSON blob under
/// [_snapshotKey], rather than one `saveWidgetData` call per field. Each
/// `saveWidgetData` call is its own platform-channel round trip, and the
/// Android side commits it as its own independent SharedPreferences write —
/// with ~20 separate calls for 3 events + 3 to-dos + the progress line,
/// there was no atomicity across them at all. [push] can run from the
/// to-do-checkbox-tap background callback (see home_widget_background.dart),
/// where Android's background execution budget can kill the process at any
/// point — a kill partway through used to leave the widget's storage with a
/// mix of some already-updated fields and some still-stale ones (e.g.
/// event0 updated but event1/event2 not yet, or a to-do's `_done` flag
/// updated but not its `_priority`), rendered as a visibly inconsistent
/// widget until the next successful full push. Writing one JSON string is
/// one platform-channel call and one underlying write, so a kill either
/// happens before it (old snapshot, self-consistent) or after it (new
/// snapshot, self-consistent) — never a torn mix of both. See
/// PlanFitWidgetProvider.kt's matching read-side change.
class HomeWidgetSync {
  const HomeWidgetSync._();

  static const String androidProviderName = 'PlanFitWidgetProvider';
  static const String iosWidgetKind = 'PlanFitWidget';

  /// Must match the App Group configured on both the Runner and the
  /// (Xcode-added) PlanFitWidget extension targets — see
  /// ios/PlanFitWidget/PlanFitWidget.swift.
  static const String iosAppGroupId = 'group.com.arisair.planfit';

  /// How many upcoming events are pushed as `event0_*`.. `event{n-1}_*` —
  /// the Android side's expanded (large) layout shows all of them; the
  /// compact layout and the iOS widget only ever look at `event0_*`.
  static const int maxEvents = 3;

  /// How many of today's to-dos are pushed as `todo0_*`.. `todo{n-1}_*`,
  /// each individually checkable right from the widget (see
  /// `PlanFitWidgetProvider.kt`'s `bindTodos` and, once the iOS extension
  /// exists, its Swift counterpart) — undone ones sorted first so whichever
  /// prefix of them fits on screen is the actionable set, not whatever
  /// happened to be marked done already.
  static const int maxWidgetTodos = 3;

  /// The single key the whole snapshot is written under — see [push]'s doc
  /// for why this replaced one key per field.
  static const String _snapshotKey = 'widget_snapshot';

  /// App Group queue written by the iOS interactive widget intent. The
  /// Flutter app consumes it on launch/resume because a WidgetKit extension
  /// cannot link Flutter's headless engine without pulling every plugin into
  /// the app extension.
  static const String pendingActionKey = 'widget_pending_action';

  static bool _appGroupSet = false;

  static Future<void> push({
    required List<EventRow> upcomingEvents,
    required List<TodoRow> todayTodos,
  }) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    if (Platform.isIOS && !_appGroupSet) {
      await HomeWidget.setAppGroupId(iosAppGroupId);
      _appGroupSet = true;
    }

    final snapshot = buildWidgetSnapshot(
      upcomingEvents: upcomingEvents,
      todayTodos: todayTodos,
    );

    // One platform-channel call, one underlying write — see [push]'s doc.
    await HomeWidget.saveWidgetData<String>(_snapshotKey, jsonEncode(snapshot));

    await HomeWidget.updateWidget(
      androidName: androidProviderName,
      iOSName: iosWidgetKind,
    );
  }

  /// Reads and atomically clears the pending action left by an iOS widget row.
  /// Returns null on non-iOS platforms or when no action is queued.
  static Future<Uri?> consumePendingAction() async {
    if (kIsWeb || !Platform.isIOS) return null;
    if (!_appGroupSet) {
      await HomeWidget.setAppGroupId(iosAppGroupId);
      _appGroupSet = true;
    }
    final raw = await HomeWidget.getWidgetData<String>(
      pendingActionKey,
      appGroupId: iosAppGroupId,
    );
    if (raw == null || raw.isEmpty) return null;
    await HomeWidget.saveWidgetData<String>(
      pendingActionKey,
      null,
      appGroupId: iosAppGroupId,
    );
    return Uri.tryParse(raw);
  }

  /// The deep link opened for a given day — parsed by [parseScheduleDate] on
  /// the receiving end (see app.dart's widget-tap handling).
  static Uri scheduleUri(DateTime day) => Uri(
    scheme: 'planfit',
    host: 'schedule',
    queryParameters: {'date': _isoDate(day)},
  );

  /// The inverse of [scheduleUri] — returns null for anything else (e.g. a
  /// plain launch with no attached uri, or an unrecognized link).
  static DateTime? parseScheduleDate(Uri? uri) {
    if (uri == null || uri.scheme != 'planfit' || uri.host != 'schedule') {
      return null;
    }
    return DateTime.tryParse(uri.queryParameters['date'] ?? '');
  }

  static String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _isoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
