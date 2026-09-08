import 'package:shared_preferences/shared_preferences.dart';

/// Persistent, collision-free mapping from a reminder's owner key (an
/// event/to-do id plus which reminder offset, e.g. `'e1#30'` or
/// `'todo#t1#0'` — see `NotificationService.notificationId`/
/// `todoNotificationId`'s doc) to the plain integer id
/// `flutter_local_notifications` actually schedules under.
///
/// Replaced hashing the owner key string down to a 31-bit int
/// (`hashCode & 0x7fffffff`, a ~2.1 billion-value space): with enough
/// distinct ids in play — every event/to-do a long-lived install has *ever*
/// held, since ids are never reused and the hash is a pure function of the
/// string — the ordinary birthday bound makes an actual collision a real,
/// not just theoretical, event. Two different reminders landing on the same
/// numeric id means whichever schedules second silently overwrites the
/// other's pending alert (same id = same OS notification slot), and
/// cancelling/rescheduling either one affects both. No hash-quality
/// improvement fixes this — the birthday bound applies to any hash of a
/// fixed bit width — so this needs an actual collision-free assignment
/// instead: the first time an owner key is seen, it's assigned the next
/// unused integer and that mapping is kept forever, so every distinct owner
/// key really does get its own distinct id, and asking for the same key
/// again (a re-schedule, a cancel, a refill pass) always resolves back to
/// the one already assigned.
///
/// Backed by [SharedPreferences], not the main Drift database: this is a
/// small string-key-to-int map with no relational structure, and
/// [NotificationService] is reached from almost every write path in the
/// app (`EventRepositoryImpl`, `TodoController`, `CalendarReconciler`,
/// `SettingsController`) — giving it a dependency on the full `AppDatabase`
/// just for this would mean every one of those (and every test exercising
/// them) has to be able to stand up a real database. `SharedPreferences` is
/// already a dependency every one of those paths already carries
/// (`AppSettings` itself lives there), synchronous once loaded, and needs
/// no `path_provider`/platform-channel machinery a plain unit test doesn't
/// already set up.
///
/// Each owner key gets its own flat preference key (`$_keyPrefix$ownerKey`)
/// rather than all of them living together in one combined JSON blob — a
/// single blob would mean re-decoding *and* re-encoding the whole,
/// ever-growing map on every single lookup/insert, silently turning a
/// long-lived install's history of ids into an O(n²) cost. One flat key per
/// owner is O(1) either way, the same as [SharedPreferences]' own
/// underlying storage already is.
class NotificationIdAllocator {
  NotificationIdAllocator(this._prefs);

  final SharedPreferences _prefs;

  static const _keyPrefix = 'notifications.idAllocation.';
  static const _nextIdKey = 'notifications.idAllocationCounter';

  /// Returns [ownerKey]'s already-assigned id, or assigns and persists the
  /// next unused one if this is the first time it's been asked for. Always
  /// returns the same id for the same [ownerKey] on every later call.
  ///
  /// Synchronous, deliberately: two "concurrent" callers (e.g. a direct
  /// `scheduleForEvent` racing `refillEvents`' own batch) can't actually
  /// interleave a function body with no `await` inside it — Dart's
  /// single-threaded event loop only switches tasks at a suspension point,
  /// and this one has none between reading the current value and writing
  /// the updated one back. The actual persistence (`setInt`) is
  /// fire-and-forget: [SharedPreferences] already updates its own in-memory
  /// cache synchronously, so a second `allocate` call immediately after
  /// sees the new value regardless of whether the write has physically
  /// landed on disk yet.
  int allocate(String ownerKey) {
    final key = '$_keyPrefix$ownerKey';
    final existing = _prefs.getInt(key);
    if (existing != null) return existing;

    final next = (_prefs.getInt(_nextIdKey) ?? 0) + 1;
    // Fire-and-forget, in this order: if the process dies between these two
    // writes, the counter having already moved past `next` just means
    // `next` itself is skipped forever (never reused) rather than handed
    // out to two different owner keys — the failure mode that actually
    // matters here.
    _prefs.setInt(_nextIdKey, next).ignore();
    _prefs.setInt(key, next).ignore();
    return next;
  }
}
