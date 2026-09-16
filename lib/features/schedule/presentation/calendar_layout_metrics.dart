import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Geometry-derived display values shared by the schedule calendars.
///
/// Calendar cells become much taller and wider on iPad, but fixed 24pt dates
/// and 9sp event rows made that extra space look empty. Keeping the values in
/// one object makes the marker position, text measurement and capacity math
/// respond to the same layout inputs.
@immutable
class CalendarLayoutMetrics {
  const CalendarLayoutMetrics({
    required this.columnWidth,
    required this.rowHeight,
    required this.textScaler,
  });

  final double columnWidth;
  final double rowHeight;
  final TextScaler textScaler;

  bool get isExpanded => columnWidth >= 80 && rowHeight >= 72;

  double get dayNumberDiameter => math.min(
    36,
    math.max(24, math.min(columnWidth * 0.38, rowHeight * 0.34)),
  );

  double get numberTopMargin => isExpanded ? 10 : 10;

  double get markerTopGap => isExpanded ? 5 : 1;

  double get markerBottomPadding => isExpanded ? 6 : 2;

  double get collapsedDotSize => isExpanded ? 8 : 6;

  double get spanningBarHeight => isExpanded ? 6 : 4;

  TextStyle eventTextStyle(Color color) => TextStyle(
    fontSize: isExpanded ? 12 : 9,
    height: 1.15,
    color: color,
    fontWeight: isExpanded ? FontWeight.w500 : FontWeight.w400,
  );

  TextStyle lunarTextStyle(Color color) =>
      TextStyle(fontSize: isExpanded ? 11 : 9, height: 1.1, color: color);

  int maxVisibleEventRows(int availableRows) => math.min(availableRows, 5);
}
