import 'package:flutter/material.dart';

/// Width above which the device is treated as tablet-sized for sheet
/// presentation — Material's own compact/medium window-size-class cutoff.
const double kSheetTabletBreakpoint = 600;

/// The width a bottom sheet is capped to on a tablet-sized screen, centered
/// rather than stretched edge-to-edge — a form built for a phone-width
/// column reads poorly spread across a 13" iPad.
const double kSheetMaxWidth = 480;

/// Extra bottom clearance a sheet's own content should add on top of
/// whatever margin it already uses, whenever that content's last element
/// could otherwise land at the sheet's natural bottom edge — [AppShell] runs
/// its Scaffold with `extendBody: true` so the floating Liquid-Glass tab bar
/// paints *above* body content instead of reserving space for it, and a
/// modal sheet inherits that same unreserved height. Content that reaches a
/// sheet's natural bottom edge without accounting for this renders
/// underneath the tab bar instead of above it — invisible/untappable even
/// though it's "there." First caught in the calendar legend sheet's closing
/// info box (invisible on a real device, since flutter_test's default
/// 800x600 surface never reproduced it), found again in the quick-add
/// sheet's Save button (unreachable, not just invisible, since it sat
/// directly behind the tab bar). Not applied automatically by
/// [showAdaptiveBottomSheet] itself — sheets with their own bounded-height
/// container (e.g. one capped to a fraction of the screen and internally
/// scrollable) may already sit clear of this without needing it, and
/// wrapping every sheet unconditionally would add a visible gap below ones
/// that don't. Add this to a sheet's own bottom padding whenever its last
/// element isn't already known to clear the tab bar. Sized generously
/// rather than exactly, since the tab bar's real footprint isn't something
/// a plain widget has a clean way to query.
const double kFloatingNavBarClearance = 96;

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
    isScrollControlled: true,
    backgroundColor: backgroundColor,
    showDragHandle: showDragHandle,
    constraints: isTablet
        ? const BoxConstraints(maxWidth: kSheetMaxWidth)
        : null,
    builder: builder,
  );
}
