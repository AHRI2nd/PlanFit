import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';
import 'package:planfit/features/todo/domain/todo_tag_match.dart';

void main() {
  TodoRow todo({String? tags}) {
    return TodoRow(
      id: 't1',
      eventId: null,
      title: 't1',
      slotStart: DateTime(2026, 3, 10),
      slotEnd: null,
      hasTime: false,
      isDone: false,
      sortOrder: 0,
      priority: 0,
      tags: tags,
      notify: false,
      isPinned: false,
      recurrenceRule: null,
      recurrenceGroupId: null,
      reminderSyncStatus: SyncStatus.pendingPush,
      createdAt: DateTime(2020),
    );
  }

  group('todoHasTag', () {
    test('matches a tag among several comma-separated segments', () {
      final t = todo(tags: '업무,개인,급함');
      expect(todoHasTag(t, '개인'), isTrue);
    });

    test('does not match a substring of another tag', () {
      final t = todo(tags: '영업무');
      expect(todoHasTag(t, '업무'), isFalse);
    });

    test('tolerates surrounding whitespace around segments', () {
      final t = todo(tags: '업무, 개인 , 급함');
      expect(todoHasTag(t, '개인'), isTrue);
    });

    test('a to-do with no tags matches nothing', () {
      final t = todo(tags: null);
      expect(todoHasTag(t, '업무'), isFalse);
    });
  });
}
