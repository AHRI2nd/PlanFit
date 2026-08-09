import 'package:flutter/material.dart';

import '../../../design/tokens/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Maps `TodoItems.priority` (a plain 0-3 int column — see tables.dart) to a
/// type-safe value the UI can switch on.
enum TodoPriority {
  none(0),
  low(1),
  medium(2),
  high(3);

  const TodoPriority(this.value);
  final int value;

  static TodoPriority fromValue(int value) => switch (value) {
    1 => TodoPriority.low,
    2 => TodoPriority.medium,
    3 => TodoPriority.high,
    _ => TodoPriority.none,
  };

  String label(AppL10n l10n) => switch (this) {
    TodoPriority.none => l10n.todoPriorityNone,
    TodoPriority.low => l10n.todoPriorityLow,
    TodoPriority.medium => l10n.todoPriorityMedium,
    TodoPriority.high => l10n.todoPriorityHigh,
  };

  /// Null for [none] — callers treat that as "don't show an indicator" (see
  /// `_TodoTile`'s priority dot).
  Color? color(AppPalette palette) => switch (this) {
    TodoPriority.none => null,
    TodoPriority.low => palette.inkFaint,
    TodoPriority.medium => palette.accent,
    TodoPriority.high => palette.danger,
  };
}
