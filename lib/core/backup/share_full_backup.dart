import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/widgets/snackbar_x.dart';
import '../../l10n/app_localizations.dart';
import '../share_origin.dart';
import 'backup_service.dart';

/// Exports the complete PlanFit backup and hands the temporary file to the
/// platform share sheet. The file stays available until the share sheet has
/// finished reading it, then is removed.
Future<void> shareFullBackup(
  BuildContext context,
  BackupService backupService,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppL10n.of(context);
  final shareOrigin = shareOriginOf(context);
  File? file;
  try {
    file = await backupService.exportToFile();
    final params = ShareParams(
      files: [XFile(file.path)],
      subject: 'PlanFit backup',
      sharePositionOrigin: shareOrigin,
    );
    await SharePlus.instance.share(params);
  } catch (_) {
    messenger.showAutoDismissSnackBar(
      SnackBar(content: Text(l10n.backupExportFailed)),
    );
  } finally {
    if (file != null && await file.exists()) await file.delete();
  }
}
