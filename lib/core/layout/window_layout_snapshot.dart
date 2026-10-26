import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum ReservedRegionKind { division, occlusion }

@immutable
class ReservedRegion {
  const ReservedRegion({
    required this.id,
    required this.kind,
    required this.bounds,
    required this.isActive,
  });

  final String id;
  final ReservedRegionKind kind;
  final Rect bounds;
  final bool isActive;

  factory ReservedRegion.fromMap(Map<Object?, Object?> map) {
    final kind = switch (map['kind']) {
      'division' => ReservedRegionKind.division,
      _ => ReservedRegionKind.occlusion,
    };
    return ReservedRegion(
      id: map['id']! as String,
      kind: kind,
      bounds: Rect.fromLTWH(
        (map['left']! as num).toDouble(),
        (map['top']! as num).toDouble(),
        (map['width']! as num).toDouble(),
        (map['height']! as num).toDouble(),
      ),
      isActive: map['active']! as bool,
    );
  }
}

@immutable
class WindowLayoutSnapshot {
  const WindowLayoutSnapshot({
    required this.viewSize,
    required this.safeArea,
    required this.horizontalSizeClass,
    required this.verticalSizeClass,
    required this.regions,
  });

  final Size viewSize;
  final EdgeInsets safeArea;
  final String horizontalSizeClass;
  final String verticalSizeClass;
  final List<ReservedRegion> regions;

  factory WindowLayoutSnapshot.fromMap(Map<Object?, Object?> map) {
    final rawRegions = map['regions'] as List<Object?>? ?? const [];
    return WindowLayoutSnapshot(
      viewSize: Size(
        (map['width']! as num).toDouble(),
        (map['height']! as num).toDouble(),
      ),
      safeArea: EdgeInsets.fromLTRB(
        (map['safeLeft']! as num).toDouble(),
        (map['safeTop']! as num).toDouble(),
        (map['safeRight']! as num).toDouble(),
        (map['safeBottom']! as num).toDouble(),
      ),
      horizontalSizeClass: map['horizontalSizeClass']! as String,
      verticalSizeClass: map['verticalSizeClass']! as String,
      regions: List.unmodifiable(
        rawRegions.map(
          (region) => ReservedRegion.fromMap(region! as Map<Object?, Object?>),
        ),
      ),
    );
  }
}
