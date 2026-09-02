import 'package:flutter/material.dart';

import '../glass/glass_surface.dart';
import '../tokens/app_spacing.dart';

/// A glass-surfaced card that groups related rows together — pairs with
/// [SectionHeader] above it. Originally local to the settings screen;
/// promoted here so other screens with the same "flat list of fields reads
/// as one undifferentiated wall" problem (e.g. the event editor) can reuse
/// the exact same grouping instead of re-inventing it.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: AppRadius.cardLg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(children: children),
    );
  }
}
