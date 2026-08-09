import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';

/// Rolling, automatic local backups — PlanFit is fully local-only with no
/// cloud account, so the only copy of a user's schedule is on this one
/// device. A manual "내보내기" (share-sheet export) exists, but relies on the
/// user remembering to run it; losing/resetting the phone between exports
/// means losing everything since. This writes a fresh backup on its own,
/// on a rolling schedule, to a location the OS won't sweep as cache (unlike
/// [BackupService.exportToFile]'s temp-dir target, which is only ever meant
/// to live long enough to hand off to a share sheet).
class AutoBackupService {
  AutoBackupService({required this.backupService, required this.prefs});

  final BackupService backupService;
  final SharedPreferences prefs;

  static const String _kLastRunAt = 'backup.lastAutoBackupAt';

  /// How often a new automatic backup gets written — frequent enough that a
  /// lost phone rarely costs more than a day's changes, infrequent enough
  /// to not matter for storage or battery.
  static const Duration minInterval = Duration(hours: 24);

  /// How many rolling backups to keep around at once.
  static const int maxRetained = 7;

  DateTime? get lastRunAt {
    final iso = prefs.getString(_kLastRunAt);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/auto_backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes a new backup if [minInterval] has passed since the last one,
  /// then prunes anything beyond [maxRetained]. Best-effort, same as
  /// app.dart's other foreground-resume tasks (calendar reconcile, widget
  /// sync, ...) — a failure here must never surface to the user or block
  /// anything else.
  Future<void> runIfDue({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final last = lastRunAt;
    if (last != null && at.difference(last) < minInterval) return;

    try {
      final dir = await _dir();
      final stamp = at.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${dir.path}/backup-$stamp.json');
      await file.writeAsString(await backupService.buildJson());
      await prefs.setString(_kLastRunAt, at.toIso8601String());
      await _prune();
    } catch (_) {
      // Best-effort — see doc comment above.
    }
  }

  /// Every retained auto-backup, newest first. The filename's ISO-8601
  /// timestamp sorts lexically the same as chronologically, so a plain
  /// reverse string sort is enough — no need to parse each name back out.
  Future<List<File>> listBackups() async {
    final dir = await _dir();
    if (!await dir.exists()) return [];
    final files = (await dir.list().toList()).whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> _prune() async {
    final files = await listBackups();
    for (final f in files.skip(maxRetained)) {
      await f.delete();
    }
  }
}
