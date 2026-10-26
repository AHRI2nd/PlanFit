import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackupImportActivity extends Notifier<bool> {
  @override
  bool build() => false;
  bool begin() {
    if (state) return false;
    state = true;
    return true;
  }
  void finish() => state = false;
}

final backupImportActivityProvider = NotifierProvider<BackupImportActivity, bool>(
  BackupImportActivity.new);
