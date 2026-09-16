import 'package:flutter/material.dart';

/// Width above which the device is treated as tablet-sized for sheet
/// presentation — Material's own compact/medium window-size-class cutoff.
const double kSheetTabletBreakpoint = 600;

/// A width-only tablet check misclassifies short landscape phone windows (for
/// example a folded/outer display) as iPad-sized. Requiring a modest height
/// as well keeps those windows full-width while retaining the existing iPad
/// behavior.
const double kSheetTabletMinHeight = 500;

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
  final size = MediaQuery.sizeOf(context);
  final isTablet =
      size.width >= kSheetTabletBreakpoint &&
      size.height >= kSheetTabletMinHeight;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: backgroundColor,
    showDragHandle: showDragHandle,
    constraints: isTablet
        ? const BoxConstraints(maxWidth: kSheetMaxWidth)
        : null,
    builder: builder,
  );
}
