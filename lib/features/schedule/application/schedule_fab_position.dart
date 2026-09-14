import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';

/// Which side of the schedule view the add button is parked against.
///
/// Only ever left or right: the button snaps horizontally on release and
/// keeps whatever height it was let go at, so the vertical axis is a free
/// coordinate rather than a second enum.
enum ScheduleFabSide { left, right }

/// Where the schedule tab's add button sits, as the user last dragged it.
///
/// The vertical half is stored as a *fraction* of the draggable region's
/// height rather than a pixel offset, so the button lands in the same
/// visual spot across a rotation, a split-screen resize, or a restore onto
/// a differently-sized phone — a stored pixel offset would put it somewhere
/// arbitrary (or clamped hard against an edge) on any of those.
@immutable
class ScheduleFabPosition {
  const ScheduleFabPosition({
    this.side = ScheduleFabSide.right,
    this.verticalFraction = 1,
  });

  final ScheduleFabSide side;

  /// 0 puts the button at the top of the draggable region, 1 at the bottom.
  final double verticalFraction;

  /// Bottom-right, where a [FloatingActionButton] has always sat — what a
  /// user who never drags it sees, and what a reset returns to.
  static const initial = ScheduleFabPosition();

  ScheduleFabPosition copyWith({
    ScheduleFabSide? side,
    double? verticalFraction,
  }) => ScheduleFabPosition(
    side: side ?? this.side,
    verticalFraction: verticalFraction ?? this.verticalFraction,
  );

  @override
  bool operator ==(Object other) =>
      other is ScheduleFabPosition &&
      other.side == side &&
      other.verticalFraction == verticalFraction;

  @override
  int get hashCode => Object.hash(side, verticalFraction);
}

/// Reads and persists [ScheduleFabPosition].
///
/// Kept out of `AppSettings` for the same reason as `OnboardingPrefs` and
/// `SyncPrefs`: that class is for settings the user toggles on the Settings
/// screen, and this is state they set by direct manipulation and never see
/// a control for.
class ScheduleFabPositionController extends Notifier<ScheduleFabPosition> {
  static const _kSide = 'schedule.fabSide';
  static const _kVertical = 'schedule.fabVerticalFraction';

  @override
  ScheduleFabPosition build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final storedSide = prefs.getString(_kSide);
    final storedVertical = prefs.getDouble(_kVertical);
    return ScheduleFabPosition(
      side: ScheduleFabSide.values
              .where((s) => s.name == storedSide)
              .firstOrNull ??
          ScheduleFabPosition.initial.side,
      // Clamped on read as well as on write: a hand-edited or corrupted
      // preferences value must not be able to park the button off-screen
      // where nothing can drag it back.
      verticalFraction:
          storedVertical?.clamp(0.0, 1.0) ??
          ScheduleFabPosition.initial.verticalFraction,
    );
  }

  Future<void> set(ScheduleFabPosition position) async {
    final clamped = position.copyWith(
      verticalFraction: position.verticalFraction.clamp(0.0, 1.0),
    );
    if (clamped == state) return;
    state = clamped;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kSide, clamped.side.name);
    await prefs.setDouble(_kVertical, clamped.verticalFraction);
  }
}

final scheduleFabPositionProvider =
    NotifierProvider<ScheduleFabPositionController, ScheduleFabPosition>(
      ScheduleFabPositionController.new,
    );
