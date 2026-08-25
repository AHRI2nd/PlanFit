import 'package:flutter/material.dart';

import '../../../design/glass/glass_surface.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/time_gradient_background.dart';
import '../../../l10n/app_localizations.dart';

/// Placeholder for the deferred social features (friends, shared schedules).
/// The tab and route exist now so the shell is complete; the functionality
/// lands in a later phase.
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final palette = context.palette;
    final theme = Theme.of(context);

    return TimeGradientBackground(
      intensity: 0.6,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.socialTitle, style: theme.textTheme.headlineSmall),
                const Spacer(),
                GlassSurface(
                  borderRadius: AppRadius.cardLg,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppColors.timeGradient(DateTime.now()),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.group_add,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.socialComingSoonTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.socialComingSoonBody,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
