import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/db/sync_status.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> addAt(DateTime at, String title) => db.syncLogDao.add(
    SyncLogsCompanion.insert(
      at: Value(at),
      eventTitle: Value(title),
      resolution: SyncResolution.pulled,
    ),
  );

  test('a normal add shows up in watchRecent', () async {
    await addAt(DateTime(2026, 1, 1), 'e1');

    final rows = await db.syncLogDao.watchRecent().first;

    expect(rows, hasLength(1));
    expect(rows.single.eventTitle, 'e1');
  });

  test("growing past the retention cap drops the oldest entries, not the "
      'newest — regression test: nothing was pruning this table at all, so '
      "a long-lived install's sync-log history (every conflict/pull/push "
      'resolution ever logged, forever) grew without bound', () async {
    // Comfortably past whatever the cap is — the exact number is this
    // DAO's own private concern, not something a test outside it should
    // hard-code and have to keep in sync.
    const total = 520;
    for (var i = 0; i < total; i++) {
      await addAt(DateTime(2026, 1, 1).add(Duration(minutes: i)), 'e$i');
    }

    final rows = await db.select(db.syncLogs).get();

    expect(rows.length, lessThan(total));
    expect(rows.any((r) => r.eventTitle == 'e0'), isFalse);
    expect(rows.any((r) => r.eventTitle == 'e${total - 1}'), isTrue);
  });
}
