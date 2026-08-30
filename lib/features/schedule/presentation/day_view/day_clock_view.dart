import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/format.dart';
import '../../../../core/time_format.dart';
import '../../../../design/tokens/app_colors.dart';
import '../../../../design/tokens/app_spacing.dart';
import '../../../../design/tokens/event_color_tag.dart';
import '../../../settings/application/settings_controller.dart';
import '../../domain/day_clock_geometry.dart';
import '../event_edit/event_editor_sheet.dart';

/// The day view's alternate layout: every timed event laid out as a colored
/// arc on a 24-hour dial (0/24:00 at the top, clockwise) instead of a
/// vertical hour-by-hour timeline. All-day events are deliberately not
/// drawn here — `DayView` keeps showing those in its own strip above this
/// widget, same as it does above [_Timeline] — a dial has no natural place
/// for a thing with no time-of-day at all.
///
/// Overlap is resolved by [layoutClockArcs], which reuses [cascadeEvents]
/// unmodified and maps its column/columnCount onto concentric ring bands
/// instead of side-by-side pixel columns — no new overlap logic here, per
/// this feature's own plan.
///
/// Deliberately carries no title text on the dial itself — curved or
/// rotated labels are exactly the kind of thing that reads fine against one
/// platform's font metrics and clips or overlaps against the other's (see
/// the RenderFlex-overflow history the linear timeline's own event cards
/// already have). [DayClockLegend], a plain upright list, is where a title
/// actually gets read; `DayView` renders it directly below this widget.
class DayClockView extends ConsumerWidget {
  const DayClockView({
    super.key,
    required this.day,
    required this.events,
    required this.isToday,
    required this.now,
    required this.locale,
  });

  final DateTime day;

  /// Timed (non-all-day) events only — see this class's own doc.
  final List<EventRow> events;
  final bool isToday;
  final DateTime now;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );
    final arcs = layoutClockArcs(day, events);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final metrics = _DialMetrics(size);
        final center = Offset(size / 2, size / 2);

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _handleTap(
                context,
                details.localPosition,
                center,
                metrics,
                arcs,
              ),
              child: CustomPaint(
                painter: _ClockPainter(
                  metrics: metrics,
                  arcs: arcs,
                  isToday: isToday,
                  now: now,
                  day: day,
                  locale: locale,
                  use24: use24,
                  palette: palette,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(
    BuildContext context,
    Offset local,
    Offset center,
    _DialMetrics metrics,
    List<ClockArc> arcs,
  ) {
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final r = math.sqrt(dx * dx + dy * dy);
    if (metrics.ringBandWidth <= 0) return;
    final ringFraction = (r - metrics.ringInnerRadius) / metrics.ringBandWidth;
    if (ringFraction < 0 || ringFraction > 1) return;
    final angle = math.atan2(dy, dx);
    final hit = hitTestClockArcs(arcs, angle, ringFraction);
    if (hit != null) showEventEditor(context, existing: hit);
  }
}

/// Every radius this view needs, derived once from the dial's pixel [size]
/// so [DayClockView]'s gesture handler and [_ClockPainter] agree exactly
/// on where the ring band (and so every arc within it) actually sits —
/// computing this independently in two places risks the same drift bugs
/// `_offsetFor`/gridline alignment in the linear timeline had to be fixed
/// for.
class _DialMetrics {
  _DialMetrics(double size)
    : dialRadius = size / 2 - size * 0.02,
      majorTickLength = size * 0.035,
      minorTickLength = size * 0.018,
      labelRadius = size / 2 - size * 0.02 - size * 0.035 - size * 0.05,
      ringOuterRadius = size / 2 - size * 0.02 - size * 0.035 - size * 0.12,
      ringInnerRadius = size * 0.16;

  final double dialRadius;
  final double majorTickLength;
  final double minorTickLength;
  final double labelRadius;
  final double ringOuterRadius;
  final double ringInnerRadius;

  double get ringBandWidth => ringOuterRadius - ringInnerRadius;
}

class _ClockPainter extends CustomPainter {
  _ClockPainter({
    required this.metrics,
    required this.arcs,
    required this.isToday,
    required this.now,
    required this.day,
    required this.locale,
    required this.use24,
    required this.palette,
  });

  final _DialMetrics metrics;
  final List<ClockArc> arcs;
  final bool isToday;
  final DateTime now;
  final DateTime day;
  final String locale;
  final bool use24;
  final AppPalette palette;

  /// Hour marks get a text label only every 3 hours (8 labels total, 45°
  /// apart) — labeling all 24 crowds them into overlapping or clipped text
  /// on a phone-width dial, and on two different platforms' font metrics
  /// at that (the exact failure mode this feature's own plan calls out).
  static const _majorHourStep = 3;
  static const double _ringGap = 1.5;
  static const double _minArcWidth = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    _paintTicks(canvas, center);
    _paintArcs(canvas, center);
    if (isToday) _paintNowNeedle(canvas, center);
  }

  void _paintTicks(Canvas canvas, Offset center) {
    final tickPaint = Paint()..color = palette.hairline;
    final majorTickPaint = Paint()
      ..color = palette.inkFaint
      ..strokeWidth = 1.5;
    final labelStyle = TextStyle(color: palette.inkFaint, fontSize: 11);

    for (var h = 0; h < 24; h++) {
      final angle = angleForMinutes(h * 60);
      final dir = Offset(math.cos(angle), math.sin(angle));
      final isMajor = h % _majorHourStep == 0;
      final tickLen = isMajor
          ? metrics.majorTickLength
          : metrics.minorTickLength;
      canvas.drawLine(
        center + dir * (metrics.dialRadius - tickLen),
        center + dir * metrics.dialRadius,
        isMajor ? majorTickPaint : tickPaint,
      );
      if (isMajor) {
        _drawCenteredText(
          canvas,
          Fmt.hour(h, locale, use24Hour: use24),
          center + dir * metrics.labelRadius,
          labelStyle,
        );
      }
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(at.dx - painter.width / 2, at.dy - painter.height / 2),
    );
  }

  void _paintArcs(Canvas canvas, Offset center) {
    if (metrics.ringBandWidth <= 0) return;
    for (final arc in arcs) {
      final midFraction = (arc.ringStart + arc.ringEnd) / 2;
      final midRadius =
          metrics.ringInnerRadius + midFraction * metrics.ringBandWidth;
      final rawWidth =
          (arc.ringEnd - arc.ringStart) * metrics.ringBandWidth - _ringGap;
      final strokeWidth = rawWidth < _minArcWidth ? _minArcWidth : rawWidth;
      final paint = Paint()
        ..color = EventColorTag.resolve(arc.event.colorTag, arc.event.startAt)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: midRadius),
        arc.startAngle,
        arc.sweepAngle,
        false,
        paint,
      );
    }
  }

  void _paintNowNeedle(Canvas canvas, Offset center) {
    final minutes = clampedMinutesOfDay(day, now);
    final angle = angleForMinutes(minutes);
    final dir = Offset(math.cos(angle), math.sin(angle));
    final needlePaint = Paint()
      ..color = palette.accent
      ..strokeWidth = 2;
    final innerEnd = center + dir * (metrics.ringInnerRadius * 0.5);
    canvas.drawLine(
      innerEnd,
      center + dir * metrics.ringOuterRadius,
      needlePaint,
    );
    canvas.drawCircle(center, 3, Paint()..color = palette.accent);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) {
    return oldDelegate.arcs != arcs ||
        oldDelegate.isToday != isToday ||
        oldDelegate.now != now ||
        oldDelegate.use24 != use24 ||
        oldDelegate.palette != palette;
  }
}

/// A plain, upright, always-legible list of every timed event on
/// [DayClockView]'s dial — see that class's own doc for why the arcs
/// themselves carry no title text at all. Sorted by start time; tapping a
/// row opens the same [showEventEditor] an arc tap does.
class DayClockLegend extends ConsumerWidget {
  const DayClockLegend({super.key, required this.events, required this.locale});

  /// Timed (non-all-day) events only — same scope as [DayClockView.events].
  final List<EventRow> events;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final use24 = resolveUse24Hour(
      ref.watch(
        settingsControllerProvider.select((s) => s.displayTimeFormatPreference),
      ),
      context,
    );
    final sorted = [...events]..sort((a, b) => a.startAt.compareTo(b.startAt));

    return Column(
      children: [
        for (final e in sorted)
          _LegendRow(event: e, locale: locale, use24: use24),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.event,
    required this.locale,
    required this.use24,
  });

  final EventRow event;
  final String locale;
  final bool use24;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final accent = EventColorTag.resolve(event.colorTag, event.startAt);

    return InkWell(
      borderRadius: AppRadius.cardMd,
      onTap: () => showEventEditor(context, existing: event),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 88,
              child: Text(
                '${Fmt.time(event.startAt, locale, use24Hour: use24)} – '
                '${Fmt.time(event.endAt, locale, use24Hour: use24)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkSoft,
                ),
              ),
            ),
            Expanded(
              child: Text(
                event.title.isEmpty ? '—' : event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
