import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di.dart';
import '../../../core/onboarding_prefs.dart';
import '../../../design/glass/glass_surface.dart';
import '../../../design/tokens/app_colors.dart';
import '../../../design/tokens/app_motion.dart';
import '../../../design/tokens/app_spacing.dart';
import '../../../design/widgets/time_gradient_background.dart';
import '../../../l10n/app_localizations.dart';

class _OnboardingPage {
  const _OnboardingPage(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}

/// First-launch introduction: three swipeable cards ending in a "get
/// started" CTA that also fires the (one-time, guarded) notification
/// permission request — explaining why before the OS prompt lands reads
/// far better than a bare system dialog on a blank first screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(OnboardingPrefs.completed, true);
    if (!(prefs.getBool(OnboardingPrefs.notificationPrompted) ?? false)) {
      try {
        await ref.read(notificationServiceProvider).requestPermission();
      } finally {
        await prefs.setBool(OnboardingPrefs.notificationPrompted, true);
      }
    }
    if (mounted) context.go('/home');
  }

  void _next(int pageCount) {
    if (_page == pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: context.motionDuration(const Duration(milliseconds: 320)),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final palette = context.palette;

    final pages = [
      _OnboardingPage(
        icon: Icons.wb_twilight,
        title: l10n.onboardingPage1Title,
        body: l10n.onboardingPage1Body,
      ),
      _OnboardingPage(
        icon: Icons.calendar_today,
        title: l10n.onboardingPage2Title,
        body: l10n.onboardingPage2Body,
      ),
      _OnboardingPage(
        icon: Icons.notifications_active,
        title: l10n.onboardingPage3Title,
        body: l10n.onboardingPage3Body,
      ),
    ];
    final isLast = _page == pages.length - 1;

    return TimeGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter, vertical: AppSpacing.xs),
                  child: isLast
                      ? const SizedBox(height: 40)
                      : TextButton(
                          onPressed: _finish,
                          child: Text(l10n.onboardingSkip,
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(color: palette.inkFaint)),
                        ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    for (final p in pages)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                        child: Center(
                          child: GlassSurface(
                            borderRadius: AppRadius.cardLg,
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: AppColors.timeGradient(DateTime.now()),
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Icon(p.icon, color: Colors.white, size: 34),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Text(p.title,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleLarge),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  p.body,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: palette.inkSoft),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: context.motionDuration(const Duration(milliseconds: 200)),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.allPill,
                        color: i == _page ? palette.accent : palette.hairline,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _next(pages.length),
                    child: Text(
                        isLast ? l10n.onboardingGetStarted : l10n.onboardingNext),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
