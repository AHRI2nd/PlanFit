import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PlanningPreferences {
  const PlanningPreferences({
    this.startMinute = 540,
    this.endMinute = 1080,
    this.breakStart = 720,
    this.breakEnd = 780,
    this.hasBreak = false,
    this.weekdays = const {1, 2, 3, 4, 5},
    this.blockAllDay = false,
  });
  final int startMinute, endMinute, breakStart, breakEnd;
  final bool hasBreak, blockAllDay;
  final Set<int> weekdays;
  factory PlanningPreferences.load(SharedPreferences prefs) {
    try {
      final data =
          jsonDecode(prefs.getString('todo.planning') ?? '{}')
              as Map<String, dynamic>;
      final start = data['start'] as int? ?? 540,
          end = data['end'] as int? ?? 1080;
      final bs = data['breakStart'] as int? ?? 720,
          be = data['breakEnd'] as int? ?? 780;
      final days =
          (data['days'] as List?)?.cast<int>().toSet() ?? {1, 2, 3, 4, 5};
      if (start < 0 ||
          end > 1440 ||
          end <= start ||
          bs < 0 ||
          be > 1440 ||
          be <= bs ||
          days.any((d) => d < 1 || d > 7)) {
        return const PlanningPreferences();
      }
      return PlanningPreferences(
        startMinute: start,
        endMinute: end,
        breakStart: bs,
        breakEnd: be,
        hasBreak: data['hasBreak'] as bool? ?? false,
        weekdays: days,
        blockAllDay: data['allDay'] as bool? ?? false,
      );
    } catch (_) {
      return const PlanningPreferences();
    }
  }
  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString(
      'todo.planning',
      jsonEncode({
        'start': startMinute,
        'end': endMinute,
        'breakStart': breakStart,
        'breakEnd': breakEnd,
        'hasBreak': hasBreak,
        'days': weekdays.toList()..sort(),
        'allDay': blockAllDay,
      }),
    );
  }
}
