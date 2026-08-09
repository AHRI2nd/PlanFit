import 'package:uuid/uuid.dart';

import 'recurrence.dart';

/// A write request for an event, independent of how it is stored. Passing this
/// (rather than a drift row) through [EventRepository.save] keeps the UI and
/// the storage/calendar details decoupled.
class EventInput {
  EventInput({
    String? id,
    required this.title,
    this.memo,
    this.location,
    required this.startAt,
    required this.endAt,
    this.isAllDay = false,
    this.notify = true,
    this.reminderMinutesBefore = 0,
    this.additionalReminderMinutes = const [],
    this.colorTag,
    this.recurrenceFrequency = RecurrenceFrequency.none,
    this.recurrenceUntil,
    this.recurrenceCount,
    this.recurrenceByWeekdays,
  }) : id = id ?? const Uuid().v4(),
       assert(
         recurrenceFrequency == RecurrenceFrequency.none ||
             (recurrenceUntil != null) != (recurrenceCount != null),
         'exactly one of recurrenceUntil or recurrenceCount is required '
         'when recurrenceFrequency is not none',
       );

  final String id;
  final String title;
  final String? memo;
  final String? location;
  final DateTime startAt;
  final DateTime endAt;
  final bool isAllDay;
  final bool notify;

  /// Minutes before [startAt] the primary notification fires. 0 = at start
  /// time.
  final int reminderMinutesBefore;

  /// Extra reminder offsets (minutes before [startAt]) on top of
  /// [reminderMinutesBefore] — see `EventAlertX.reminderOffsets` for how
  /// they're combined and stored.
  final List<int> additionalReminderMinutes;
  final String? colorTag;

  /// How often this event repeats. Only meaningful — and only ever applied —
  /// when creating a brand-new event; editing an existing occurrence always
  /// edits just that occurrence, never regenerates the series.
  final RecurrenceFrequency recurrenceFrequency;

  /// Last occurrence date, inclusive. Exactly one of this and
  /// [recurrenceCount] is required when [recurrenceFrequency] is not
  /// [RecurrenceFrequency.none].
  final DateTime? recurrenceUntil;

  /// Ends the series after this many occurrences instead of on a date — the
  /// alternative to [recurrenceUntil]. See `RecurrenceExpansion.occurrences`.
  final int? recurrenceCount;

  /// Which weekdays a [RecurrenceFrequency.weekly] series repeats on
  /// (`DateTime.weekday` numbering) — null/empty means just [startAt]'s own
  /// weekday, the original behavior. Ignored for every other frequency. See
  /// `RecurrenceExpansion.occurrences`.
  final Set<int>? recurrenceByWeekdays;
}
