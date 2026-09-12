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

  /// A single item's own step of a reconcile pass (one event's push/pull,
  /// one auto-import calendar's scan) threw — logged and skipped rather
  /// than letting the exception abort the rest of that pass, which used to
  /// mean one stuck event silently blocked every other event's sync (and
  /// auto-import entirely) until whatever caused it resolved on its own.
  failed,
}
