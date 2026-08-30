import 'package:flutter/material.dart';

import '../../../design/tokens/app_colors.dart';

/// The one rule every calendar-cell marker in the app (month grid, year
/// mini-months, home screen's week strip, the schedule tab's date strip)
/// follows, so a given day reads the same everywhere it's shown:
///
/// - `danger` (a red/alert color) when the day has at least one overdue,
///   incomplete to-do — the one thing worth flagging as urgent across the
///   whole app.
/// - `accent` when the day merely has an event (no overdue to-do).
/// - `null` (nothing drawn) when it has neither.
///
/// `danger` always wins over `accent`: a day that both has an event and an
/// overdue to-do reads as the more urgent state, not a muddled in-between.
/// This is deliberately blind to a multi-day event bar's own `colorTag` —
/// that's a color the user picked for that specific event, not a status
/// indicator, and stays untouched by this rule.
Color? calendarDotColor({
  required AppPalette palette,
  required bool hasEvent,
  required bool hasOverdueTodo,
}) {
  if (hasOverdueTodo) return palette.danger;
  if (hasEvent) return palette.accent;
  return null;
}
