import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';

import '../db/app_database.dart';

/// Pushes a compact "next event + today's to-do progress" snapshot to the
/// native HomeScreen widget.
///
/// The Android side is fully wired (`PlanFitWidgetProvider.kt` +
/// `res/xml/home_widget_info.xml`). The iOS side needs a one-time WidgetKit
/// Extension target added in Xcode (App Groups can't be wired up from plain
/// file edits) — see docs/PROGRESS.md for the exact steps and the ready-made
/// Swift source. Until that target exists, calls here are harmless no-ops on
/// iOS: `HomeWidget` methods fail quietly and are swallowed by the caller.
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

    for (var i = 0; i < maxEvents; i++) {
      final event = i < upcomingEvents.length ? upcomingEvents[i] : null;
      await HomeWidget.saveWidgetData<String>(
        'event${i}_title',
        event?.title ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'event${i}_time',
        event == null ? '' : _time(event.startAt),
      );
      // Deep-link read by PlanFitWidgetProvider.kt (and, once the iOS
      // extension exists, PlanFitWidget.swift) so tapping an event opens
      // its day in the schedule tab instead of just launching the app.
      await HomeWidget.saveWidgetData<String>(
        'event${i}_uri',
        event == null ? '' : scheduleUri(event.startAt).toString(),
      );
    }

    final ordered = [
      ...todayTodos.where((t) => !t.isDone),
      ...todayTodos.where((t) => t.isDone),
    ];
    for (var i = 0; i < maxWidgetTodos; i++) {
      final todo = i < ordered.length ? ordered[i] : null;
      await HomeWidget.saveWidgetData<String>('todo${i}_id', todo?.id ?? '');
      await HomeWidget.saveWidgetData<String>(
        'todo${i}_title',
        todo?.title ?? '',
      );
      await HomeWidget.saveWidgetData<bool>(
        'todo${i}_done',
        todo?.isDone ?? false,
      );
      await HomeWidget.saveWidgetData<int>(
        'todo${i}_priority',
        todo?.priority ?? 0,
      );
    }

    await HomeWidget.saveWidgetData<String>(
      'todos_progress',
      '${todayTodos.where((t) => t.isDone).length}/${todayTodos.length}',
    );
    await HomeWidget.saveWidgetData<String>(
      'todos_uri',
      scheduleUri(DateTime.now()).toString(),
    );

    await HomeWidget.updateWidget(
      androidName: androidProviderName,
      iOSName: iosWidgetKind,
    );
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
