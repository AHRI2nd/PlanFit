import 'app_database.dart';

/// Small convenience extension on the generated [TodoRow], mirroring
/// [EventAlertX] (see event_row_x.dart) for to-dos.
extension TodoAlertX on TodoRow {
  /// Every reminder offset (minutes before [TodoRow.slotStart]) configured
  /// for this to-do — the implicit "at due time" alert (offset 0) plus
  /// whatever [TodoRow.additionalReminderMinutes] adds, deduped and sorted.
  /// Unlike an event, a to-do has no separate primary offset of its own —
  /// due-time is always included whenever it has any reminder at all.
  List<int> get reminderOffsets {
    final offsets = <int>{0};
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
