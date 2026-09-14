import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/glass/glass_nav_bar.dart' show navBarControlClearance;
import '../../../design/tokens/app_motion.dart';
import '../../../design/tokens/app_spacing.dart';
import '../application/schedule_fab_position.dart';

/// The schedule tab's add button, draggable by long press and magnetically
/// parked against whichever side it was let go nearest.
///
/// Lives in a [Stack] over the view content rather than in
/// `Scaffold.floatingActionButton`, because that slot owns its child's
/// position outright — there is nowhere in it to put a button the user
/// moves. The Stack it sits in is exactly the region the button may be
/// dragged within: it spans the view content, below the header and the
/// day/week/month switcher, so a dragged button can never cover the
/// controls used to get back to wherever it came from.
///
/// Long press to pick up, not plain drag: the views underneath all consume
/// horizontal drags of their own (swiping between days/weeks/months), and a
/// button that moved on a bare pan would trade an everyday gesture for a
/// rare one. A tap still opens the editor, unchanged.
class DraggableAddButton extends ConsumerStatefulWidget {
  const DraggableAddButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  /// Material's own FAB diameter — the size this reserves when working out
  /// where the button may be placed without hanging off an edge.
  static const double size = 56;

  /// Gap kept between the button and the region's edges, so a parked button
  /// reads as floating over the content rather than jammed into a corner.
  static const double edgeInset = AppSpacing.md;

  /// How long the button has to be held before it can be dragged.
  ///
  /// Shorter than the platform's own `kLongPressTimeout` (500ms), which is
  /// what a plain [GestureDetector] would use and what every other long
  /// press in the app runs at. Moving a button the user has already decided
  /// to move is not a destructive action the way the others behind a long
  /// press are (multi-select, delete), so it can afford to feel quicker;
  /// the cost is a slightly narrower window in which a press that was meant
  /// to become a tap is read as a pick-up instead.
  ///
  /// Requires [RawGestureDetector] below: [GestureDetector] constructs its
  /// [LongPressGestureRecognizer] without a `duration` and so is fixed at
  /// the platform default.
  static const Duration pickUpDelay = Duration(milliseconds: 300);

  @override
  ConsumerState<DraggableAddButton> createState() => _DraggableAddButtonState();
}

class _DraggableAddButtonState extends ConsumerState<DraggableAddButton> {
  /// Live pixel offset while a drag is in flight; null whenever the button
  /// is parked, in which case the stored position is what places it.
  Offset? _dragTopLeft;

  /// Where the button's top-left sat when the long press began.
  /// `onLongPressMoveUpdate` reports its offset cumulatively from the press
  /// origin rather than per-event, so every move is this plus that offset —
  /// accumulating the deltas instead would drift.
  Offset _pressOrigin = Offset.zero;

  bool get _dragging => _dragTopLeft != null;

  /// The rectangle of top-left corners the button may occupy inside a
  /// region of [regionSize] — the parked button's own footprint and the
  /// nav bar it must stay clear of, taken out of the region up front so
  /// every calculation below can treat this as a plain rectangle.
  Rect _placeableArea(Size regionSize) {
    const inset = DraggableAddButton.edgeInset;
    final left = inset;
    final top = inset;
    final right = regionSize.width - DraggableAddButton.size - inset;
    // The region runs to the bottom of the screen (AppShell draws its bar
    // over the body rather than reserving space for it), so the bar's own
    // height comes off here or a button parked at the bottom would sit
    // behind it — visible through the glass but not tappable.
    final bottom =
        regionSize.height -
        DraggableAddButton.size -
        navBarControlClearance(context);
    return Rect.fromLTRB(
      left,
      top,
      right < left ? left : right,
      bottom < top ? top : bottom,
    );
  }

  Offset _parkedTopLeft(ScheduleFabPosition position, Size regionSize) {
    final area = _placeableArea(regionSize);
    return Offset(
      position.side == ScheduleFabSide.left ? area.left : area.right,
      area.top + (area.bottom - area.top) * position.verticalFraction,
    );
  }

  void _onLongPressStart(Offset topLeft) {
    HapticFeedback.mediumImpact();
    setState(() {
      _pressOrigin = topLeft;
      _dragTopLeft = topLeft;
    });
  }

  void _onLongPressMove(Offset offsetFromOrigin, Size regionSize) {
    final area = _placeableArea(regionSize);
    final next = _pressOrigin + offsetFromOrigin;
    setState(() {
      _dragTopLeft = Offset(
        next.dx.clamp(area.left, area.right),
        next.dy.clamp(area.top, area.bottom),
      );
    });
  }

  void _onLongPressEnd(Size regionSize) {
    final dropped = _dragTopLeft;
    if (dropped == null) return;
    final area = _placeableArea(regionSize);

    // Nearest side by the button's own centre, so the halfway line is the
    // middle of the region rather than the middle minus half a button.
    final centreX = dropped.dx + DraggableAddButton.size / 2;
    final side = centreX < regionSize.width / 2
        ? ScheduleFabSide.left
        : ScheduleFabSide.right;

    final span = area.bottom - area.top;
    final fraction = span <= 0 ? 0.0 : (dropped.dy - area.top) / span;

    HapticFeedback.selectionClick();
    setState(() => _dragTopLeft = null);
    ref
        .read(scheduleFabPositionProvider.notifier)
        .set(ScheduleFabPosition(side: side, verticalFraction: fraction));
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(scheduleFabPositionProvider);

    // Positioned.fill first so this stays a direct child of the caller's
    // Stack: a LayoutBuilder between a Stack and a Positioned breaks the
    // parent-data relationship outright (Positioned must be an immediate
    // Stack child), so the region size is measured *inside* the fill and
    // the button placed in a Stack of its own. The fill hit-tests only
    // where the button actually is, leaving the view underneath reachable
    // everywhere else.
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final regionSize = constraints.biggest;
          final topLeft = _dragTopLeft ?? _parkedTopLeft(position, regionSize);

          return Stack(
            children: [
              AnimatedPositioned(
                // Instant while the finger is down — an easing curve on every
                // move event would leave the button lagging behind the touch —
                // and eased only for the snap home on release.
                duration: _dragging
                    ? Duration.zero
                    : context.motionDuration(const Duration(milliseconds: 260)),
                curve: Curves.easeOutBack,
                left: topLeft.dx,
                top: topLeft.dy,
                width: DraggableAddButton.size,
                height: DraggableAddButton.size,
                child: RawGestureDetector(
                  gestures: {
                    LongPressGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          LongPressGestureRecognizer
                        >(
                          () => LongPressGestureRecognizer(
                            duration: DraggableAddButton.pickUpDelay,
                            debugOwner: this,
                          ),
                          (instance) {
                            instance.onLongPressStart = (_) =>
                                _onLongPressStart(topLeft);
                            instance.onLongPressMoveUpdate = (details) =>
                                _onLongPressMove(
                                  details.offsetFromOrigin,
                                  regionSize,
                                );
                            instance.onLongPressEnd = (_) =>
                                _onLongPressEnd(regionSize);
                            instance.onLongPressCancel = () =>
                                setState(() => _dragTopLeft = null);
                          },
                        ),
                  },
                  child: AnimatedScale(
                    scale: _dragging ? 1.1 : 1,
                    duration: context.motionDuration(
                      const Duration(milliseconds: 140),
                    ),
                    child: FloatingActionButton(
                      onPressed: widget.onPressed,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
