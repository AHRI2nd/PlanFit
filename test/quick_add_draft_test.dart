import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/features/schedule/domain/quick_add_draft.dart';

void main() {
  test(
    'manual placement survives rephrasing and preserves overnight duration',
    () {
      final now = DateTime(2030, 1, 1);
      final draft = QuickAddDraft.parse(
        '내일 오후 3시 회의',
        anchorDay: now,
        now: now,
        id: 'draft',
      );
      final edited = draft
          .withDay(DateTime(2030, 3, 2))
          .withTime(const TimeOfDay(hour: 23, minute: 30))
          .withDuration(90)
          .withText('내일 오전 10시 변경', now: now);
      expect(edited.startAt, DateTime(2030, 3, 2, 23, 30));
      expect(edited.endAt, DateTime(2030, 3, 3, 1));
      expect(edited.title, '변경');
      expect(edited.id, 'draft');
      expect(edited.withoutOverrides().startAt, DateTime(2030, 1, 2, 10));
    },
  );
  test('duration must be positive', () {
    final draft = QuickAddDraft.parse(
      '회의',
      anchorDay: DateTime(2030),
      now: DateTime(2030),
    );
    expect(() => draft.withDuration(0), throwsArgumentError);
    expect(draft.usedDefaultTime, isTrue);
  });
}
