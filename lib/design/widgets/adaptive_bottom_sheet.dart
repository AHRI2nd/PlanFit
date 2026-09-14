import 'package:flutter/material.dart';

/// Width above which the device is treated as tablet-sized for sheet
/// presentation — Material's own compact/medium window-size-class cutoff.
const double kSheetTabletBreakpoint = 600;

/// The width a bottom sheet is capped to on a tablet-sized screen, centered
/// rather than stretched edge-to-edge — a form built for a phone-width
/// column reads poorly spread across a 13" iPad.
const double kSheetMaxWidth = 480;

/// [showModalBottomSheet] wrapper used by every bottom sheet in the app
/// (quick add, the event-template picker, the to-do detail sheet). Below
/// [kSheetTabletBreakpoint] this passes no `constraints` at all, so phones
/// keep the exact full-width sheet they always had; at or above it, the
/// sheet is capped to [kSheetMaxWidth] and centered (Flutter's own
/// `showModalBottomSheet` already centers a constrained sheet via an
/// `Align(alignment: Alignment.bottomCenter)` wrapper once `constraints` is
/// non-null — this just decides when to supply one).
Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool showDragHandle = true,
}) {
  final isTablet = MediaQuery.sizeOf(context).width >= kSheetTabletBreakpoint;
  return showModalBottomSheet<T>(
    context: context,
    // Above the floating tab bar, not under it. AppShell draws that bar
    // over its body, so a sheet pushed on the branch navigator came out
    // underneath: the bar stayed on top of the sheet, tinting itself off
    // whatever was behind it — reported as the bar turning grey the moment
    // a sheet opened — and intercepting touches meant for whatever sat in
    // the sheet's last rows. Every sheet here is a modal the rest of the
    // app is inert behind anyway, so covering the bar is also what the
    // platform's own sheets do.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: backgroundColor,
    showDragHandle: showDragHandle,
    constraints: isTablet
        ? const BoxConstraints(maxWidth: kSheetMaxWidth)
        : null,
    builder: builder,
  );
}
