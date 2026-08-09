import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/domain/event_input.dart';
import 'package:planfit/features/schedule/domain/recurrence.dart';

void main() {
  group('EventInput', () {
    test('allows a recurring input that supplies recurrenceUntil', () {
      expect(
        () => EventInput(
          title: 'Standup',
          startAt: DateTime(2026, 1, 1),
          endAt: DateTime(2026, 1, 1, 1),
          recurrenceFrequency: RecurrenceFrequency.weekly,
          recurrenceUntil: DateTime(2026, 12, 31),
        ),
        returnsNormally,
      );
    });

    test('allows a one-off input with no recurrenceUntil', () {
      expect(
        () => EventInput(
          title: 'One-off',
          startAt: DateTime(2026, 1, 1),
          endAt: DateTime(2026, 1, 1, 1),
        ),
        returnsNormally,
      );
    });

    test('allows a recurring input that supplies recurrenceCount', () {
      expect(
        () => EventInput(
          title: 'Standup',
          startAt: DateTime(2026, 1, 1),
          endAt: DateTime(2026, 1, 1, 1),
          recurrenceFrequency: RecurrenceFrequency.weekly,
          recurrenceCount: 10,
        ),
        returnsNormally,
      );
    });

    test(
      'rejects a recurring input with neither recurrenceUntil nor recurrenceCount',
      () {
        expect(
          () => EventInput(
            title: 'Standup',
            startAt: DateTime(2026, 1, 1),
            endAt: DateTime(2026, 1, 1, 1),
            recurrenceFrequency: RecurrenceFrequency.weekly,
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test(
      'rejects a recurring input that supplies both recurrenceUntil and recurrenceCount',
      () {
        expect(
          () => EventInput(
            title: 'Standup',
            startAt: DateTime(2026, 1, 1),
            endAt: DateTime(2026, 1, 1, 1),
            recurrenceFrequency: RecurrenceFrequency.weekly,
            recurrenceUntil: DateTime(2026, 12, 31),
            recurrenceCount: 10,
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );
  });
}
