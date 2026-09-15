import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/features/schedule/presentation/month_view/month_view.dart';

void main() {
  /// Height the schedule screen's own header and view-segment chrome takes
  /// out of the window before [MonthView] ever sees it — measured off the
  /// live screen, so the viewport figures below are what a given device
  /// really hands the month grid.
  const chrome = 148.0;

  test('a phone in portrait seats the split layout at every row count', () {
    for (var rows = 4; rows <= 6; rows++) {
      expect(
        monthLayoutMode(availableHeight: 852 - chrome, rowCount: rows),
        MonthLayoutMode.split,
        reason: '$rows rows should still split on a portrait phone',
      );
    }
  });

  test('every iPhone in landscape falls back to tabs rather than losing the '
      'timeline and the handle off the bottom edge', () {
    // Landscape height equals portrait width: the smallest phone still sold
    // through to the largest Pro Max.
    for (final height in [375.0, 390.0, 393.0, 430.0, 440.0]) {
      expect(
        monthLayoutMode(availableHeight: height - chrome, rowCount: 6),
        MonthLayoutMode.tabbed,
        reason: 'a six-row month cannot split at ${height}pt of window',
      );
    }
  });

  test('a tablet keeps the split in landscape, where the phones cannot', () {
    expect(
      monthLayoutMode(availableHeight: 768 - chrome, rowCount: 6),
      MonthLayoutMode.split,
    );
  });

  test('the threshold moves by exactly one row height per row, so a month '
      'that gains a sixth week can cross it on its own', () {
    expect(
      minSplitLayoutHeight(6) - minSplitLayoutHeight(5),
      MonthCalendarRowHeight.min,
    );
  });

  test('the boundary is inclusive — a viewport of exactly the minimum still '
      'splits, and one pixel under does not', () {
    final minimum = minSplitLayoutHeight(6);
    expect(
      monthLayoutMode(availableHeight: minimum, rowCount: 6),
      MonthLayoutMode.split,
    );
    expect(
      monthLayoutMode(availableHeight: minimum - 1, rowCount: 6),
      MonthLayoutMode.tabbed,
    );
  });

  test('the minimum leaves the day view its own floor rather than merely '
      'fitting the grid and the handle', () {
    // The bug this replaces: the grid + handle fit, Expanded gave the
    // timeline zero, and the handle went off-screen with it.
    final gridAndHandleOnly =
        minSplitLayoutHeight(6) - MonthCalendarRowHeight.min;
    expect(
      monthLayoutMode(availableHeight: gridAndHandleOnly, rowCount: 6),
      MonthLayoutMode.tabbed,
    );
  });

  test('rowCount <= 0 splits rather than dividing by zero, matching '
      'maxMonthRowHeight s own guard', () {
    expect(
      monthLayoutMode(availableHeight: 100, rowCount: 0),
      MonthLayoutMode.split,
    );
  });
}
