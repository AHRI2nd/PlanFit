/// Where a local event stands relative to the device calendar.
enum SyncStatus {
  /// Lives only in PlanFit; never written to the OS calendar (sync off or no
  /// writable calendar).
  localOnly,

  /// Created/edited locally and waiting to be pushed to the OS calendar.
  pendingPush,

  /// In agreement with the OS calendar as of the last reconciliation.
  synced,

  /// Both sides changed since the last sync; resolved by last-write-wins but
  /// logged for the user.
  conflict,
}

/// How a single reconciliation decision came out, for the sync activity log.
enum SyncResolution {
  pushed,
  pulled,
  conflictLocalWon,
  conflictRemoteWon,
  deletedRemotely,
}
