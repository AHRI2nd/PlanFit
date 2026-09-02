import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_math.dart';
import '../../../core/db/app_database.dart';
import '../../../core/di.dart';
import '../../settings/application/settings_controller.dart';

/// Which calendar granularity the schedule tab is showing.
enum ScheduleView { day, week, month, year, agenda }

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The first day of the week containing [day], per [startWeekday]
/// (`DateTime.monday`..`DateTime.sunday`) — used by the week-stats card and
/// the month/year grids so they all agree on where a week begins.
DateTime startOfWeek(DateTime day, {int startWeekday = DateTime.monday}) {
  final d = dateOnly(day);
  final diff = (d.weekday - startWeekday) % 7;
  return addCalendarDays(d, -diff);
}

/// `DateTime.monday` or `DateTime.sunday`, per the user's week-start setting.
final weekStartWeekdayProvider = Provider<int>((ref) {
  final monday = ref.watch(
    settingsControllerProvider.select((s) => s.weekStartsMonday),
  );
  return monday ? DateTime.monday : DateTime.sunday;
});

/// The single source of truth for "which day is in focus", shared by the day,
/// month and year views so switching granularity keeps the user's place.
class SelectedDate extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void select(DateTime day) => state = dateOnly(day);
  void jumpToToday() => state = dateOnly(DateTime.now());
}

final selectedDateProvider = NotifierProvider<SelectedDate, DateTime>(
  SelectedDate.new,
);

class ScheduleViewMode extends Notifier<ScheduleView> {
  @override
  ScheduleView build() => ScheduleView.day;
  void set(ScheduleView view) => state = view;
}

final scheduleViewProvider = NotifierProvider<ScheduleViewMode, ScheduleView>(
  ScheduleViewMode.new,
);

/// The agenda (목록) tab's last scroll offset, remembered only for the
/// life of this app session — `null` means "hasn't been visited yet this
/// session", which is what lets [AgendaView] tell a genuinely fresh app
/// launch apart from the user having just switched to another tab (or
/// opened an editor) and come back to it. Deliberately never persisted to
/// SharedPreferences: a real app relaunch should always land back on
/// "today first", the same as it always has — only navigating *within* a
/// running session should keep the user's own scroll position instead.
class AgendaScrollMemory extends Notifier<double?> {
  @override
  double? build() => null;

  void save(double offset) => state = offset;

  /// Forgets the remembered offset, so the next open re-anchors to today
  /// exactly like a fresh app launch would — used when the calendar day
  /// itself rolls over (midnight) while the tab happens to still be open,
  /// which deserves the same "today first" treatment a real relaunch gets.
  void clear() => state = null;
}

final agendaScrollMemoryProvider = NotifierProvider<AgendaScrollMemory, double?>(
  AgendaScrollMemory.new,
);

/// Height (in logical pixels) of a single week row in [MonthView]'s
/// calendar grid — dragging the handle between the grid and the day
/// timeline below it changes this, trading grid space for timeline space.
/// [MonthView] doesn't have a "total height" knob to give the grid directly
/// (`TableCalendar` sizes itself from `rowHeight`, not the other way
/// around), so this is the actual lever: taller rows grow the whole grid,
/// shorter rows shrink it. Persisted so the user's choice survives restarts,
/// same as `weekStartsMonday` and the app's other display prefs.
class MonthCalendarRowHeight extends Notifier<double> {
  static const _key = 'schedule.monthCalendarRowHeight';

  /// The day-number circle is a fixed size regardless of this drag range
  /// (see monthDayNumberDiameter's doc) — below this floor, there's no
  /// longer room for that fixed circle *and* the dot/bar marker sitting
  /// just under it without the two overlapping. Above [max], a short month
  /// leaves little room for the day timeline underneath.
  static const min = 44.0;
  static const max = 96.0;

  /// table_calendar's own built-in default — unadjusted rows match today's
  /// look exactly.
  static const defaultHeight = 52.0;

  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return (prefs.getDouble(_key) ?? defaultHeight).clamp(min, max);
  }

  /// Live-updates while dragging; call [persist] once the drag ends rather
  /// than writing to disk on every frame of movement.
  void set(double value) => state = value.clamp(min, max);

  Future<void> persist() =>
      ref.read(sharedPreferencesProvider).setDouble(_key, state);
}

final monthCalendarRowHeightProvider =
    NotifierProvider<MonthCalendarRowHeight, double>(
      MonthCalendarRowHeight.new,
    );

/// The day view's two layouts: the default vertical hour-by-hour
/// [_Timeline] (`day_view.dart`), or the 24-hour circular [DayClockView]
/// (`day_clock_view.dart`).
enum DayViewLayoutMode { timeline, clock }

/// Persisted like [MonthCalendarRowHeight] and the app's other display
/// prefs — a full-screen `DayView` remembers the user's chosen layout
/// across restarts, but `DayView(compact: true)` (the one embedded under
/// `MonthView`'s calendar grid) always forces timeline regardless of this,
/// since that cramped a space suits neither a legible dial nor its ring
/// labels — see `DayView`'s own doc for that override.
class DayViewLayoutModeNotifier extends Notifier<DayViewLayoutMode> {
  static const _key = 'schedule.dayViewLayoutMode';

  @override
  DayViewLayoutMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) == DayViewLayoutMode.clock.name
        ? DayViewLayoutMode.clock
        : DayViewLayoutMode.timeline;
  }

  Future<void> set(DayViewLayoutMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final dayViewLayoutModeProvider =
    NotifierProvider<DayViewLayoutModeNotifier, DayViewLayoutMode>(
      DayViewLayoutModeNotifier.new,
    );

/// Events overlapping the given day.
final eventsForDayProvider = StreamProvider.family<List<EventRow>, DateTime>((
  ref,
  day,
) {
  final start = dateOnly(day);
  final end = addCalendarDays(start, 1);
  return ref.watch(eventRepositoryProvider).watchBetween(start, end);
});

/// Events overlapping the month that contains [monthAnchor] — used for the
/// month grid's day markers.
final eventsForMonthProvider = StreamProvider.family<List<EventRow>, DateTime>((
  ref,
  monthAnchor,
) {
  final start = DateTime(monthAnchor.year, monthAnchor.month, 1);
  final end = DateTime(monthAnchor.year, monthAnchor.month + 1, 1);
  return ref.watch(eventRepositoryProvider).watchBetween(start, end);
});

/// Events across the year of [yearAnchor] — used for the year heat view.
final eventsForYearProvider = StreamProvider.family<List<EventRow>, int>((
  ref,
  year,
) {
  final start = DateTime(year, 1, 1);
  final end = DateTime(year + 1, 1, 1);
  return ref.watch(eventRepositoryProvider).watchBetween(start, end);
});

/// Next few upcoming events from now, for the home screen.
final upcomingEventsProvider = StreamProvider<List<EventRow>>((ref) {
  return ref
      .watch(eventRepositoryProvider)
      .watchUpcoming(DateTime.now(), limit: 4);
});

/// Events in the week containing [anyDayInWeek] (per the week-start setting)
/// — the home screen's weekly stats card.
final eventsForWeekProvider = StreamProvider.family<List<EventRow>, DateTime>((
  ref,
  anyDayInWeek,
) {
  final start = startOfWeek(
    anyDayInWeek,
    startWeekday: ref.watch(weekStartWeekdayProvider),
  );
  final end = addCalendarDays(start, 7);
  return ref.watch(eventRepositoryProvider).watchBetween(start, end);
});

/// Events for the agenda view's flat chronological list — a window anchored
/// at [anchor]: a week back (so a just-passed event doesn't vanish the
/// instant it starts) through 6 months forward.
final eventsForAgendaProvider = StreamProvider.family<List<EventRow>, DateTime>(
  (ref, anchor) {
    final start = addCalendarDays(dateOnly(anchor), -7);
    final end = addCalendarDays(dateOnly(anchor), 180);
    return ref.watch(eventRepositoryProvider).watchBetween(start, end);
  },
);

/// Saved event templates ("자주 쓰는 일정"), oldest first.
final eventTemplatesProvider = StreamProvider<List<EventTemplateRow>>((ref) {
  return ref.watch(eventTemplateDaoProvider).watchAll();
});
