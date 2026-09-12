import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/notifications/notification_id_allocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'the same owner key always resolves back to the id it was first '
    'assigned, and different keys never collide',
    () async {
      SharedPreferences.setMockInitialValues({});
      final allocator = NotificationIdAllocator(
        await SharedPreferences.getInstance(),
      );

      final first = allocator.allocate('e1#30');
      expect(allocator.allocate('e1#30'), first);

      final second = allocator.allocate('todo#t1#0');
      expect(second, isNot(first));
      expect(allocator.allocate('todo#t1#0'), second);
    },
  );

  test(
    'once the tracked mapping count passes its cap, the oldest entries are '
    'pruned — and asking for a pruned key again allocates a brand new id '
    'rather than colliding with whatever now holds a fresher one',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final allocator = NotificationIdAllocator(prefs);

      // One past the 5000 cap so exactly the single oldest key is pruned.
      for (var i = 0; i < 5001; i++) {
        allocator.allocate('owner-$i');
      }

      // owner-0 was the oldest — its mapping is gone, so asking again mints
      // a new id instead of returning its original one.
      final reallocated = allocator.allocate('owner-0');
      expect(reallocated, isNot(1));

      // owner-2500, comfortably clear of the single pruned entry, still
      // resolves back to its original mapping — reading it back here is a
      // plain lookup (not a new allocation), so it doesn't itself trigger
      // another prune the way the owner-0 re-allocation above did.
      expect(allocator.allocate('owner-2500'), 2501);
    },
  );
}
