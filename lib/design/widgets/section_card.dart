import 'package:flutter/material.dart';

import '../glass/glass_surface.dart';
import '../tokens/app_spacing.dart';

/// A glass-surfaced card that groups related rows together — pairs with
/// [SectionHeader] above it. Originally local to the settings screen;
/// promoted here so other screens with the same "flat list of fields reads
/// as one undifferentiated wall" problem (e.g. the event editor) can reuse
/// the exact same grouping instead of re-inventing it.
///
/// [GlassSurface]'s [BackdropFilter] is real per-card compositing cost, and
/// both screens that use this stack several of these at once (settings has
/// seven, the event editor four) — [RepaintBoundary] here caches each
/// card's own blur layer, the same fix `home_screen.dart`'s feed tiles got,
/// so editing a field in one card doesn't force every *other* card's blur
/// to recomposite along with it.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GlassSurface(
        borderRadius: AppRadius.cardLg,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(children: children),
      ),
    );
  }
}
