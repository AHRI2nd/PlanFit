import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/presentation/calendar_layout_metrics.dart';

void main() {
  test('expanded cells use larger content metrics', () {
    const metrics = CalendarLayoutMetrics(
      columnWidth: 92,
      rowHeight: 150,
      textScaler: TextScaler.noScaling,
    );

    expect(metrics.isExpanded, isTrue);
    expect(metrics.dayNumberDiameter, closeTo(34.96, 0.01));
    expect(metrics.collapsedDotSize, 8);
    expect(metrics.spanningBarHeight, 6);
    expect(metrics.eventTextStyle(Colors.black).fontSize, 12);
    expect(metrics.lunarTextStyle(Colors.black).fontSize, 11);
    expect(metrics.maxVisibleEventRows(8), 5);
  });

  test('compact cells preserve the phone-sized floor', () {
    const metrics = CalendarLayoutMetrics(
      columnWidth: 52,
      rowHeight: 52,
      textScaler: TextScaler.noScaling,
    );

    expect(metrics.isExpanded, isFalse);
    expect(metrics.dayNumberDiameter, 24);
    expect(metrics.collapsedDotSize, 6);
    expect(metrics.spanningBarHeight, 4);
    expect(metrics.eventTextStyle(Colors.black).fontSize, 9);
    expect(metrics.lunarTextStyle(Colors.black).fontSize, 9);
  });
}
