import 'dart:async';

import 'package:flutter/material.dart';

/// [ScaffoldMessengerState.showSnackBar], but with our own auto-dismiss
/// timer instead of relying on the framework's.
///
/// `ScaffoldMessengerState.build()` only arms its built-in auto-dismiss
/// timer when `ModalRoute.of(context)` is null or `.isCurrent` — see
/// `scaffold.dart`. PlanFit's 4-tab shell uses `StatefulShellRoute
/// .indexedStack` (nested per-branch Navigators), and under that
/// architecture the route ScaffoldMessenger resolves is never considered
/// current, so that timer is never created — every SnackBar in the app
/// would otherwise sit on screen forever, dismissible only by manually
/// tapping its action (which goes through `hideCurrentSnackBar()` directly,
/// bypassing the same check, which is why that half kept working). See
/// https://github.com/flutter/flutter/issues/155746 for the same class of
/// StatefulShellRoute nested-Navigator/"route never current" interaction.
extension AutoDismissSnackBar on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  showAutoDismissSnackBar(SnackBar snackBar) {
    // Replace, don't queue behind, anything still showing — see the same
    // reasoning at each call site this replaced.
    hideCurrentSnackBar();
    final controller = showSnackBar(snackBar);
    var closed = false;
    controller.closed.then((_) => closed = true);
    Timer(snackBar.duration, () {
      // Only this exact SnackBar — if it already closed some other way
      // (action tap, another showAutoDismissSnackBar call replacing it),
      // don't cut short whatever replaced it.
      if (!closed) hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
    });
    return controller;
  }
}
