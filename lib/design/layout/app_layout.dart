import 'package:flutter/material.dart';

import '../../core/layout/window_layout_snapshot.dart';

enum NavigationPlacement { bottom, leading, trailing }

@immutable
class AppLayout {
  const AppLayout({
    required this.size,
    required this.safeBounds,
    required this.keyboardBounds,
    required this.navigationPlacement,
    required this.availableRegions,
    required this.occlusions,
  });

  final Size size;
  final Rect safeBounds;
  final Rect keyboardBounds;
  final NavigationPlacement navigationPlacement;
  final List<Rect> availableRegions;
  final List<Rect> occlusions;

  bool get usesSideNavigation =>
      navigationPlacement != NavigationPlacement.bottom;

  static AppLayout of(BuildContext context) {
    final media = MediaQuery.of(context);
    final scope = context.dependOnInheritedWidgetOfExactType<AppLayoutScope>();
    final snapshot = scope?.snapshot;
    final windowSize = scope?.windowSize;
    final origin = _viewOrigin(context);
    final snapshotMatches = snapshot != null &&
        windowSize != null &&
        (snapshot.viewSize.width - windowSize.width).abs() <= 2 &&
        (snapshot.viewSize.height - windowSize.height).abs() <= 2;
    final regions = snapshotMatches
        ? snapshot.regions
            .map((region) => region.bounds.shift(-origin))
            .where((rect) => rect.overlaps(Offset.zero & media.size))
            .toList(growable: false)
        : const <ReservedRegion>[];

    final safeBounds = Rect.fromLTRB(
      media.padding.left,
      media.padding.top,
      media.size.width - media.padding.right,
      media.size.height - media.padding.bottom,
    );
    final keyboardBounds = Rect.fromLTRB(
      0,
      0,
      media.size.width,
      media.size.height - media.viewInsets.bottom,
    );
    final contentBounds = safeBounds.intersect(keyboardBounds);
    final divisions = regions
        .where((region) =>
            region.kind == ReservedRegionKind.division && region.isActive)
        .map((region) => region.bounds)
        .toList(growable: false);
    final availableRegions = _divide(contentBounds, divisions);
    final occlusions = regions
        .where((region) =>
            region.kind == ReservedRegionKind.occlusion && region.isActive)
        .map((region) => region.bounds)
        .toList(growable: false);

    final horizontalClass = snapshotMatches
        ? snapshot.horizontalSizeClass
        : 'unspecified';
    final rootWindowSize = windowSize ?? media.size;
    final rootPadding = scope?.windowPadding ?? media.padding;
    final wideLandscape = rootWindowSize.width >= 960 &&
        rootWindowSize.width / rootWindowSize.height >= 1.5;
    final useRail = horizontalClass == 'regular' && wideLandscape;
    final placement = !useRail
        ? NavigationPlacement.bottom
        : rootPadding.left > rootPadding.right
        ? NavigationPlacement.trailing
        : NavigationPlacement.leading;

    return AppLayout(
      size: media.size,
      safeBounds: contentBounds,
      keyboardBounds: keyboardBounds,
      navigationPlacement: placement,
      availableRegions: availableRegions,
      occlusions: occlusions,
    );
  }

  static Offset _viewOrigin(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return Offset.zero;
    }
    return renderObject.localToGlobal(Offset.zero);
  }

  static List<Rect> _divide(Rect bounds, List<Rect> divisions) {
    var regions = <Rect>[bounds];
    for (final division in divisions) {
      final next = <Rect>[];
      for (final region in regions) {
        if (!region.overlaps(division)) {
          next.add(region);
          continue;
        }
        if (division.height >= division.width) {
          final left = Rect.fromLTRB(
            region.left,
            region.top,
            division.left.clamp(region.left, region.right),
            region.bottom,
          );
          final right = Rect.fromLTRB(
            division.right.clamp(region.left, region.right),
            region.top,
            region.right,
            region.bottom,
          );
          if (left.width > 0) next.add(left);
          if (right.width > 0) next.add(right);
        } else {
          final top = Rect.fromLTRB(
            region.left,
            region.top,
            region.right,
            division.top.clamp(region.top, region.bottom),
          );
          final bottom = Rect.fromLTRB(
            region.left,
            division.bottom.clamp(region.top, region.bottom),
            region.right,
            region.bottom,
          );
          if (top.height > 0) next.add(top);
          if (bottom.height > 0) next.add(bottom);
        }
      }
      regions = next;
    }
    return List.unmodifiable(regions);
  }
}

class AppLayoutScope extends InheritedWidget {
  const AppLayoutScope({
    super.key,
    required this.snapshot,
    required this.windowSize,
    required this.windowPadding,
    required super.child,
  });

  final WindowLayoutSnapshot? snapshot;
  final Size windowSize;
  final EdgeInsets windowPadding;

  @override
  bool updateShouldNotify(AppLayoutScope oldWidget) =>
      snapshot != oldWidget.snapshot ||
      windowSize != oldWidget.windowSize ||
      windowPadding != oldWidget.windowPadding;
}
