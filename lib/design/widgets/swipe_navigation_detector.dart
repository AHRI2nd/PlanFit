import 'package:flutter/material.dart';

/// Recognizes a decisive horizontal swipe as either of two independent
/// signals — whichever fires first wins:
///
/// - a fast flick, using the same ±300 px/s `primaryVelocity` threshold
///   this app's other swipe gestures already use (see `_EventCard`'s
///   swipe-to-delete in `day_view.dart`), or
/// - a slower but clearly-intentional drag past [distanceThreshold]
///   logical pixels.
///
/// Velocity alone isn't enough for a *navigation* gesture the way it is for
/// a destructive one: a short/narrow swipe target (a bare year label like
/// "2026", or a week header's single row) doesn't give a quick flick much
/// horizontal room to build up 300px/s before the finger lifts, so a
/// perfectly deliberate — just not especially fast — swipe would otherwise
/// silently do nothing. The distance fallback catches that case without
/// weakening the flick path, and unlike a destructive gesture, navigating
/// has no real accidental-trigger cost worth guarding against.
class SwipeNavigationDetector extends StatefulWidget {
  const SwipeNavigationDetector({
    super.key,
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;

  /// Finger moving right-to-left — the "next" direction by this app's
  /// convention (matching `table_calendar`'s own swipe-to-next-month).
  final VoidCallback onSwipeLeft;

  /// Finger moving left-to-right — "previous".
  final VoidCallback onSwipeRight;

  final HitTestBehavior behavior;

  static const double velocityThreshold = 300;
  static const double distanceThreshold = 48;

  @override
  State<SwipeNavigationDetector> createState() =>
      _SwipeNavigationDetectorState();
}

class _SwipeNavigationDetectorState extends State<SwipeNavigationDetector> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final isLeft =
            velocity < -SwipeNavigationDetector.velocityThreshold ||
            _dragDistance < -SwipeNavigationDetector.distanceThreshold;
        final isRight =
            velocity > SwipeNavigationDetector.velocityThreshold ||
            _dragDistance > SwipeNavigationDetector.distanceThreshold;
        if (isLeft) {
          widget.onSwipeLeft();
        } else if (isRight) {
          widget.onSwipeRight();
        }
      },
      child: widget.child,
    );
  }
}
