import 'app_database.dart';

/// Small convenience extension on the generated [EventRow].
extension EventAlertX on EventRow {
  /// The moment the primary local notification should fire: [startAt] minus
  /// the primary lead time ([EventRow.reminderMinutesBefore]).
  DateTime get alertAt =>
      startAt.subtract(Duration(minutes: reminderMinutesBefore));

  /// Every reminder offset (minutes before [startAt]) configured for this
  /// event — [reminderMinutesBefore] plus whatever
  /// [EventRow.additionalReminderMinutes] adds, deduped and sorted.
  List<int> get reminderOffsets {
    final offsets = <int>{reminderMinutesBefore};
    final extra = additionalReminderMinutes;
    if (extra != null && extra.isNotEmpty) {
      for (final part in extra.split(',')) {
        final v = int.tryParse(part.trim());
        if (v != null) offsets.add(v);
      }
    }
    return offsets.toList()..sort();
  }
}
