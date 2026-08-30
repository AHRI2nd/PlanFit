import 'package:flutter/material.dart';

import '../../../design/tokens/app_colors.dart';

/// The one rule every calendar-cell marker in the app (month grid, year
/// mini-months, home screen's week strip, the schedule tab's date strip and
/// week view) follows, so a given day reads the same everywhere it's shown:
///
/// - `danger` (a red/alert color) when the day has at least one overdue,
///   incomplete to-do — the one thing worth flagging as urgent across the
///   whole app.
/// - `todoAccent` when the day has at least one incomplete to-do that isn't
///   overdue (no alarm, but still something left to do).
/// - `accent` when the day merely has an event (no incomplete to-do at
///   all).
/// - `null` (nothing drawn) when it has none of the above.
///
/// A day whose only to-dos are already done shows no to-do-state dot at
/// all — only *incomplete* to-dos count (same premise `watchOverdue`
/// already bakes into "overdue"), so a day with nothing left to do reads as
/// clear, not flagged.
///
/// Priority is `danger` > `todoAccent` > `accent`: each state strictly
/// outranks the ones after it, so a day matching more than one condition
/// always reads as its single most urgent state, never a muddled
/// in-between. This is deliberately blind to a multi-day event bar's own
/// `colorTag` — that's a color the user picked for that specific event,
/// not a status indicator, and stays untouched by this rule.
Color? calendarDotColor({
  required AppPalette palette,
  required bool hasEvent,
  required bool hasTodo,
  required bool hasOverdueTodo,
}) {
  if (hasOverdueTodo) return palette.danger;
  if (hasTodo) return palette.todoAccent;
  if (hasEvent) return palette.accent;
  return null;
}
