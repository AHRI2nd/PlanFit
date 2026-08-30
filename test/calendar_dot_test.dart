import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/design/tokens/app_colors.dart';
import 'package:planfit/features/schedule/domain/calendar_dot.dart';

void main() {
  final palette = AppTheme.light().extension<AppPalette>()!;

  test('danger wins when a day has both an event and an overdue to-do', () {
    final color = calendarDotColor(
      palette: palette,
      hasEvent: true,
      hasTodo: false,
      hasOverdueTodo: true,
    );
    expect(color, palette.danger);
  });

  test('accent when a day has only an event', () {
    final color = calendarDotColor(
      palette: palette,
      hasEvent: true,
      hasTodo: false,
      hasOverdueTodo: false,
    );
    expect(color, palette.accent);
  });

  test('danger when a day has only an overdue to-do, no event', () {
    final color = calendarDotColor(
      palette: palette,
      hasEvent: false,
      hasTodo: false,
      hasOverdueTodo: true,
    );
    expect(color, palette.danger);
  });

  test('nothing when a day has neither', () {
    final color = calendarDotColor(
      palette: palette,
      hasEvent: false,
      hasTodo: false,
      hasOverdueTodo: false,
    );
    expect(color, isNull);
  });

  test('todoAccent when a day has only a non-overdue to-do, no event', () {
    final color = calendarDotColor(
      palette: palette,
      hasEvent: false,
      hasTodo: true,
      hasOverdueTodo: false,
    );
    expect(color, palette.todoAccent);
  });

  test(
    'todoAccent wins over accent when a day has both an event and a '
    'non-overdue to-do',
    () {
      final color = calendarDotColor(
        palette: palette,
        hasEvent: true,
        hasTodo: true,
        hasOverdueTodo: false,
      );
      expect(color, palette.todoAccent);
    },
  );

  test(
    'danger still wins over todoAccent when a day has both an overdue and '
    'a non-overdue to-do',
    () {
      final color = calendarDotColor(
        palette: palette,
        hasEvent: false,
        hasTodo: true,
        hasOverdueTodo: true,
      );
      expect(color, palette.danger);
    },
  );
}
