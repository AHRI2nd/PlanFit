import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/notifications/notification_id_allocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [NotificationIdAllocator] replaced the old scheme — `'$id#$offset'
/// .hashCode & 0x7fffffff`, a ~2.1 billion-value space — of hashing a
/// reminder's owner key down to a 31-bit int.
///
/// That old scheme was fixed by round-4's audit as a real, not just
/// theoretical, collision risk: with enough distinct owner keys in play
/// (every event/to-do a long-lived install has *ever* held an id for, since
/// ids are never reused and the hash is a pure function of the string), the
/// ordinary birthday bound made a collision a near-certainty at a realistic
/// scale — this file used to prove that with a 60,000-id simulation that
/// found an actual collision on its first run. Critically, that math meant
/// no hash-quality improvement could have fixed it: for ~360,000 keys
/// hashed into a 31-bit space, even a perfectly uniform random hash still
/// predicts ~30 collisions on average — the fix had to replace hashing
/// with an actual collision-free assignment instead (see
/// [NotificationIdAllocator]'s own doc for the full reasoning).
///
/// This file now proves the *replacement* has no such ceiling: allocating
/// a large population of owner keys through the real
/// [NotificationIdAllocator.allocate] never produces two different keys
/// mapped to the same id — not probabilistically unlikely, but structurally
/// impossible, since each id is assigned once from a running counter
/// rather than derived from a lossy hash.
void main() {
  late NotificationIdAllocator allocator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    allocator = NotificationIdAllocator(await SharedPreferences.getInstance());
  });

  String uuidV4(Random rnd) {
    // Same shape as package:uuid's v4 output (hex, dashes, version/variant
    // nibbles fixed) — good enough to be representative.
    String hex(int n) =>
        List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + rnd.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }

  test(
    'allocate() never maps two different owner keys to the same id, even '
    'across a large, realistic population of ids — unlike the old hash-'
    'based scheme, this holds structurally, not just probabilistically',
    () {
      const offsets = [0, 5, 10, 30, 60, 1440];
      final rnd = Random(1234);
      final idToOwner = <int, String>{};

      // 60,000 distinct ids x 6 offsets = 360,000 allocations — the same
      // scale the old hash-based test used to demonstrate a real collision
      // at. Cheap here since allocate() is a synchronous in-memory map
      // lookup, unlike the old test's DB-backed equivalent.
      for (var i = 0; i < 60000; i++) {
        final id = uuidV4(rnd);
        for (final offset in offsets) {
          final ownerKey = '$id#$offset';
          final allocated = allocator.allocate(ownerKey);
          final existingOwner = idToOwner[allocated];
          if (existingOwner != null) {
            fail(
              'notification id $allocated was allocated to both '
              '$existingOwner and $ownerKey',
            );
          }
          idToOwner[allocated] = ownerKey;
        }
      }

      // 60,000 x 6 = 360,000 allocations, every single one distinct.
      expect(idToOwner, hasLength(360000));
    },
  );

  test(
    'asking for the same owner key again always returns the same id — a '
    're-schedule, a cancel, or a later refill pass all need to keep '
    'hitting the exact same OS notification slot',
    () {
      final first = allocator.allocate('e1#30');
      final second = allocator.allocate('e1#30');
      final different = allocator.allocate('e1#60');

      expect(second, first);
      expect(different, isNot(first));
    },
  );

  test(
    'a fresh allocator reading the same persisted prefs resolves an '
    'already-allocated owner key back to its same id — the mapping '
    'survives an app restart, not just this one in-memory instance',
    () async {
      final id = allocator.allocate('e1#30');

      final reloaded = NotificationIdAllocator(
        await SharedPreferences.getInstance(),
      );

      expect(reloaded.allocate('e1#30'), id);
    },
  );
}
