import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// A labeled row of [ChoiceChip]s where any number of [options] can be
/// selected at once — used by the event editor's additional-reminders picker
/// and the to-do detail sheet's reminder picker, wherever a single-select
/// chip row (e.g. an event's primary reminder) isn't the right shape.
class MultiChipRow<T> extends StatelessWidget {
  const MultiChipRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final List<T> options;
  final Set<T> selected;
  final String Function(T value) labelFor;
  final Color accent;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(color: palette.inkSoft),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final value in options)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    label: Text(labelFor(value)),
                    selected: selected.contains(value),
                    onSelected: (_) => onChanged(value),
                    showCheckmark: false,
                    backgroundColor: palette.surface,
                    selectedColor: accent,
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: selected.contains(value)
                          ? Colors.white
                          : palette.inkSoft,
                    ),
                    side: BorderSide(
                      color: selected.contains(value)
                          ? accent
                          : palette.hairline,
                    ),
                    shape: const StadiumBorder(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
