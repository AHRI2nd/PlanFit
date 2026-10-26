import 'package:flutter/material.dart' show TimeOfDay;
import 'package:uuid/uuid.dart';
import '../../../core/quick_add/quick_add_parser.dart';

class QuickAddDraft {
  QuickAddDraft._(
    this.id,
    this.anchorDay,
    this.text,
    this.parsed, {
    this._day,
    this._time,
    this.durationMinutes = 60,
  });
  factory QuickAddDraft.parse(
    String text, {
    required DateTime anchorDay,
    required DateTime now,
    String? id,
  }) => QuickAddDraft._(
    id ?? const Uuid().v4(),
    anchorDay,
    text,
    parseQuickAdd(text, now: now),
  );
  final String id;
  final DateTime anchorDay;
  final String text;
  final QuickAddResult parsed;
  final DateTime? _day;
  final TimeOfDay? _time;
  final int durationMinutes;
  String get title => parsed.title.isEmpty ? text.trim() : parsed.title;
  bool get usedDefaultTime => _time == null && parsed.time == null;
  bool get hasOverrides =>
      _day != null || _time != null || durationMinutes != 60;
  DateTime get startAt {
    final day = _day ?? parsed.date ?? anchorDay;
    final time = _time ?? parsed.time ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));
  QuickAddDraft withText(String value, {required DateTime now}) =>
      QuickAddDraft._(
        id,
        anchorDay,
        value,
        parseQuickAdd(value, now: now),
        day: _day,
        time: _time,
        durationMinutes: durationMinutes,
      );
  QuickAddDraft withDay(DateTime day) => QuickAddDraft._(
    id,
    anchorDay,
    text,
    parsed,
    day: DateTime(day.year, day.month, day.day),
    time: _time,
    durationMinutes: durationMinutes,
  );
  QuickAddDraft withTime(TimeOfDay time) => QuickAddDraft._(
    id,
    anchorDay,
    text,
    parsed,
    day: _day,
    time: time,
    durationMinutes: durationMinutes,
  );
  QuickAddDraft withDuration(int minutes) {
    if (minutes <= 0) throw ArgumentError.value(minutes, 'minutes');
    return QuickAddDraft._(
      id,
      anchorDay,
      text,
      parsed,
      day: _day,
      time: _time,
      durationMinutes: minutes,
    );
  }

  QuickAddDraft withoutOverrides() =>
      QuickAddDraft._(id, anchorDay, text, parsed);
}
