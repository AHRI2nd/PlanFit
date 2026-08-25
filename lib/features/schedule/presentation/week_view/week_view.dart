import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date_math.dart';
import '../../../../core/db/app_database.dart';
import '../../../../core/format.dart';
import '../../../../core/time_format.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../settings/application/settings_controller.dart';
import '../../application/schedule_providers.dart';
import '../../domain/drag_create.dart';
import '../../domain/event_span.dart';
import '../event_edit/event_editor_sheet.dart';

/// A 7-day grid: hours down the rail, one column per day, events positioned
/// by day + time-of-day — the zoomed-out counterpart to [DayView]'s single
/// column. No existing-event drag/resize (unlike the day view): tapping an
/// event opens it for editing, tapping a day's header jumps into that day's
/// own [DayView] for finer-grained interactions, and a long-press-drag on
/// empty grid space creates a new event spanning the dragged range.
class WeekView extends ConsumerWidget {
  const WeekView({super.key, required this.anchor});

  final DateTime anchor;

  static const double _hourHeight = 48;
  static const double _railInset = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final startWeekday = ref.watch(weekStartWeekdayProvider);
    final weekStart = startOfWeek(anchor, startWeekday: startWeekday);
    final weekEnd = addCalendarDays(weekStart, 7);
    final days = [
      for (var i = 0; i < 7; i++) addCalendarDays(weekStart, i),
    ];
    final eventsAsync = ref.watch(eventsForWeekProvider(anchor));
    final now = DateTime.now();
    final today = dateOnly(now);
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );

    void openDay(DateTime day) {
      ref.read(selectedDateProvider.notifier).select(day);
      ref.read(scheduleViewProvider.notifier).set(ScheduleView.day);
    }

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (events) {
        final allDay = events.where((e) => e.isAllDay).toList();
        final timed = events.where((e) => !e.isAllDay).toList();
        final byDay = <DateTime, List<EventRow>>{for (final d in days) d: []};
        for (final e in timed) {
          final d = dateOnly(e.startAt);
          byDay[d]?.add(e);
        }

        return Column(
          children: [
            _WeekHeader(
              days: days,
              today: today,
              locale: locale,
              accent: palette.accent,
              onTapDay: openDay,
            ),
            if (allDay.isNotEmpty)
              _AllDayStrip(
                days: days,
                weekStart: weekStart,
                weekEnd: weekEnd,
                events: allDay,
                railInset: _railInset,
              ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: SizedBox(
                  height: _hourHeight * 24,
                  child: _WeekGrid(
                    days: days,
                    today: today,
                    now: now,
                    byDay: byDay,
                    locale: locale,
                    hourHeight: _hourHeight,
                    railInset: _railInset,
                    accent: palette.accent,
                    onTapDay: openDay,
                    use24Hour: use24,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.days,
    required this.today,
    required this.locale,
    required this.accent,
    required this.onTapDay,
  });

  final List<DateTime> days;
  final DateTime today;
  final String locale;
  final Color accent;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          const SizedBox(width: WeekView._railInset),
          for (final day in days)
            Expanded(
              child: GestureDetector(
                onTap: () => onTapDay(day),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Text(
                      Fmt.weekdayShort(day, locale),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.inkFaint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: day == today ? accent : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: day == today ? Colors.white : null,
                          fontWeight: day == today ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small colored bars for all-day events, spanning every day column they
/// touch within the visible week — rounded only on the true start/end of
/// the event's own span (via [eventDaysInRange]) so an event that runs past
/// this week's edges reads as continuing off-screen rather than ending here.
class _AllDayStrip extends StatelessWidget {
  const _AllDayStrip({
    required this.days,
    required this.weekStart,
    required this.weekEnd,
    required this.events,
    required this.railInset,
  });

  final List<DateTime> days;
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<EventRow> events;
  final double railInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: railInset),
          for (final day in days)
            Expanded(
              child: Column(
                children: [
                  for (final e in events)
                    if (eventDaysInRange(e, weekStart, weekEnd).contains(day))
                      Builder(
                        builder: (context) {
                          final span = eventDaysInRange(e, weekStart, weekEnd);
                          final isFirst = span.first == day;
                          final isLast = span.last == day;
                          final accent = EventColorTag.resolve(
                            e.colorTag,
                            e.startAt,
                          );
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 1),
                            height: 16,
                            padding: EdgeInsets.only(
                              left: isFirst ? AppSpacing.xxs : 0,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.horizontal(
                                left: isFirst
                                    ? const Radius.circular(4)
                                    : Radius.zero,
                                right: isLast
                                    ? const Radius.circular(4)
                                    : Radius.zero,
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: isFirst
                                ? Text(
                                    e.title.isEmpty ? '—' : e.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: accent),
                                  )
                                : null,
                          );
                        },
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatefulWidget {
  const _WeekGrid({
    required this.days,
    required this.today,
    required this.now,
    required this.byDay,
    required this.locale,
    required this.hourHeight,
    required this.railInset,
    required this.accent,
    required this.onTapDay,
    required this.use24Hour,
  });

  final List<DateTime> days;
  final DateTime today;
  final DateTime now;
  final Map<DateTime, List<EventRow>> byDay;
  final String locale;
  final double hourHeight;
  final double railInset;
  final Color accent;
  final ValueChanged<DateTime> onTapDay;
  final bool use24Hour;

  @override
  State<_WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<_WeekGrid> {
  /// Long-press-drag-to-create state, mirroring DayView's own — see its doc
  /// comment. [_createDayIndex] pins the drag to whichever column it started
  /// in even if the finger wanders sideways into a neighboring one.
  int? _createDayIndex;
  double? _createAnchorY;
  double? _createCurrentY;

  double _offsetFor(DateTime dayStart, DateTime t) =>
      t.difference(dayStart).inMinutes / 60.0 * widget.hourHeight;

  void _startCreate(int dayIndex, double y) {
    HapticFeedback.mediumImpact();
    setState(() {
      _createDayIndex = dayIndex;
      _createAnchorY = y;
      _createCurrentY = y;
    });
  }

  void _updateCreate(double y) {
    setState(() => _createCurrentY = y);
  }

  (DateTime, DateTime)? get _pendingCreateRange {
    final dayIndex = _createDayIndex;
    final anchor = _createAnchorY;
    final current = _createCurrentY;
    if (dayIndex == null || anchor == null || current == null) return null;
    final day = widget.days[dayIndex];
    final dayStart = DateTime(day.year, day.month, day.day);
    return snappedCreateRange(
      dayStart,
      anchor,
      current,
      hourHeight: widget.hourHeight,
    );
  }

  Future<void> _endCreate() async {
    final dayIndex = _createDayIndex;
    final range = _pendingCreateRange;
    setState(() {
      _createDayIndex = null;
      _createAnchorY = null;
      _createCurrentY = null;
    });
    if (dayIndex == null || range == null) return;
    await showEventEditor(
      context,
      initialDay: widget.days[dayIndex],
      initialStart: range.$1,
      initialEnd: range.$2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final days = widget.days;
    final hourHeight = widget.hourHeight;
    final railInset = widget.railInset;
    final locale = widget.locale;
    final accent = widget.accent;
    final today = widget.today;
    final now = widget.now;
    final byDay = widget.byDay;
    final onTapDay = widget.onTapDay;
    final use24 = widget.use24Hour;
    final pendingCreate = _pendingCreateRange;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = (constraints.maxWidth - railInset) / days.length;
          return Stack(
            children: [
              // Hour gridlines + rail labels.
              for (int h = 0; h < 24; h++)
                Positioned(
                  top: h * hourHeight,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: hourHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: railInset - AppSpacing.xxs,
                          child: Text(
                            Fmt.hour(h, locale, use24Hour: use24),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: palette.inkFaint),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(top: 6),
                            height: 1,
                            color: palette.hairline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // One tap target per day column, behind the events. A plain tap
              // jumps into that day (the precise-editing surface); a
              // long-press-drag instead creates an event right here, spanning
              // the dragged range — same gesture DayView's own timeline uses,
              // so the two views behave consistently.
              for (var i = 0; i < days.length; i++)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: railInset + i * columnWidth,
                  width: columnWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => onTapDay(days[i]),
                    onLongPressStart: (d) =>
                        _startCreate(i, d.localPosition.dy),
                    onLongPressMoveUpdate: (d) =>
                        _updateCreate(d.localPosition.dy),
                    onLongPressEnd: (_) => _endCreate(),
                  ),
                ),

              // Live preview of the event being drag-created — see DayView's
              // own for why this (rather than opening the editor live) is the
              // feedback shown while the finger is still down.
              if (pendingCreate != null && _createDayIndex != null)
                Positioned(
                  top: _offsetFor(days[_createDayIndex!], pendingCreate.$1) + 1,
                  left: railInset + _createDayIndex! * columnWidth + 1,
                  width: (columnWidth - 2).clamp(0, columnWidth),
                  height:
                      (_offsetFor(days[_createDayIndex!], pendingCreate.$2) -
                              _offsetFor(
                                days[_createDayIndex!],
                                pendingCreate.$1,
                              ))
                          .clamp(0, hourHeight * 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22),
                      border: Border.all(color: accent, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

              // Events, positioned by day column + time.
              for (var i = 0; i < days.length; i++)
                for (final e in byDay[days[i]] ?? const <EventRow>[])
                  Positioned(
                    top: _offsetFor(days[i], e.startAt) + 1,
                    left: railInset + i * columnWidth + 1,
                    width: (columnWidth - 2).clamp(0, columnWidth),
                    child: IgnorePointer(
                      ignoring: false,
                      child: GestureDetector(
                        onTap: () => showEventEditor(context, existing: e),
                        child: Container(
                          constraints: BoxConstraints(
                            minHeight:
                                (_offsetFor(days[i], e.endAt) -
                                        _offsetFor(days[i], e.startAt))
                                    .clamp(14, hourHeight * 24),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: EventColorTag.resolve(
                              e.colorTag,
                              e.startAt,
                            ).withValues(alpha: palette.isDark ? 0.32 : 0.22),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            e.title.isEmpty ? '—' : e.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                  ),

              // "Now" indicator, only in today's column when today is in view.
              if (days.contains(today))
                Positioned(
                  top: _offsetFor(today, now) - 1,
                  left: railInset + days.indexOf(today) * columnWidth,
                  width: columnWidth,
                  child: Container(height: 2, color: accent),
                ),
            ],
          );
        },
      ),
    );
  }
}
