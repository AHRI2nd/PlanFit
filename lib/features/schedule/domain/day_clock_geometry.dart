import 'dart:math' as math;

import '../../../core/db/app_database.dart';
import 'event_overlap.dart';

/// One event's placement on the 24-hour dial: an angular span (radians, 0 =
/// midnight at the top, increasing clockwise — the same convention every
/// analog clock face already uses, just scaled to 1440 minutes instead of
/// 720) plus a ring band expressed as *fractions* of the shared band
/// between the dial's inner hub and its outer edge — [DayClockView] scales
/// those fractions into actual pixels, this file stays free of any Flutter/
/// dart:ui dependency so its angle math and hit-testing are plain-Dart
/// unit-testable, same as [cascadeEvents] itself.
class ClockArc {
  const ClockArc({
    required this.event,
    required this.startAngle,
    required this.sweepAngle,
    required this.ringStart,
    required this.ringEnd,
  });

  final EventRow event;

  /// Radians, per [angleForMinutes]'s convention.
  final double startAngle;

  /// Always > 0 — see [layoutClockArcs], which drops any event clamped to
  /// zero width.
  final double sweepAngle;

  /// 0..1 fraction of the ring band, inner edge.
  final double ringStart;

  /// 0..1 fraction of the ring band, outer edge. Always > [ringStart].
  final double ringEnd;
}

/// Minutes since [day]'s own midnight for [t], clamped to `[0, 1440]`.
/// [DayClockView]'s events (like [_Timeline]'s) come from
/// `eventsForDayProvider`, which returns anything merely *overlapping* the
/// day — not just events fully contained in it — so an event that starts
/// the evening before or runs past midnight into the next day still needs
/// to map to a well-defined slice of *this* day's dial rather than an
/// angle outside `[0, 2π)` or a sweep that wraps the whole circle twice.
int clampedMinutesOfDay(DateTime day, DateTime t) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final minutes = t.difference(dayStart).inMinutes;
  return minutes.clamp(0, 1440);
}

/// Radians for [minutes] since midnight, 0 at the top, clockwise.
double angleForMinutes(int minutes) =>
    -math.pi / 2 + (minutes / 1440.0) * 2 * math.pi;

/// Normalizes an angle into `[0, 2π)`. Dart's `%` on `double` already
/// returns a non-negative result for a positive divisor (unlike C's `%`),
/// so this is just that — named for readability at each call site rather
/// than relying on every caller to remember it.
double normalizeAngle(double angle) => angle % (2 * math.pi);

/// Lays every event in [events] out onto the dial for [day]. Angular span
/// comes from each event's own (clamped) start/end; ring band comes
/// straight from [cascadeEvents]'s `column`/`columnCount` — reused
/// verbatim, not recomputed, exactly as the plan for this view requires.
/// Two clusters [cascadeEvents] assigns never overlap in time, and so never
/// overlap in angle either, meaning every cluster can safely reuse the same
/// `[0, 1]` ring-band fraction independently of any other cluster's own
/// `columnCount`.
List<ClockArc> layoutClockArcs(DateTime day, List<EventRow> events) {
  final arcs = <ClockArc>[];
  for (final c in cascadeEvents(events)) {
    final startMin = clampedMinutesOfDay(day, c.event.startAt);
    final endMin = clampedMinutesOfDay(day, c.event.endAt);
    if (endMin <= startMin) continue; // clamped away entirely from this day
    final sweep = angleForMinutes(endMin) - angleForMinutes(startMin);
    arcs.add(
      ClockArc(
        event: c.event,
        startAngle: angleForMinutes(startMin),
        sweepAngle: sweep,
        ringStart: c.column / c.columnCount,
        ringEnd: (c.column + 1) / c.columnCount,
      ),
    );
  }
  return arcs;
}

/// Which (if any) event in [arcs] a tap at polar coordinates [angle]
/// (radians, [angleForMinutes]'s convention) and [ringFraction] (0 = the
/// ring band's inner edge, 1 = its outer edge) landed on. Iterates in
/// [arcs] order and keeps the last match, though ring bands within one
/// cluster are disjoint by construction so a genuine tie shouldn't occur.
EventRow? hitTestClockArcs(
  List<ClockArc> arcs,
  double angle,
  double ringFraction,
) {
  final normalizedAngle = normalizeAngle(angle);
  EventRow? hit;
  for (final arc in arcs) {
    if (ringFraction < arc.ringStart || ringFraction > arc.ringEnd) continue;
    final rel = normalizeAngle(
      normalizedAngle - normalizeAngle(arc.startAngle),
    );
    if (rel <= arc.sweepAngle) hit = arc.event;
  }
  return hit;
}
