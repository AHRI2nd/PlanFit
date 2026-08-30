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
      hasOverdueTodo: true,
    );
    expect(color, palette.danger);
  });

  test('accent when a day has only an event', () {
    final color = calendarDotColor(
      palette: palette,
      hasEvent: true,
      hasOverdueTodo: false,
    );
    expect(color, palette.accent);
  });

  test('danger when a day has only an overdue to-do, no event', () {
    final color = calendarDotColor(
      palette: palette,
      hasEvent: false,
      hasOverdueTodo: true,
    );
    expect(color, palette.danger);
  });

  test('nothing when a day has neither', () {
    final color = calendarDotColor(
      palette: palette,
      hasEvent: false,
      hasOverdueTodo: false,
    );
    expect(color, isNull);
  });
}
