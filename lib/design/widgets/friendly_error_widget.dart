import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Replaces Flutter's default [ErrorWidget] — the full red diagnostic box in
/// debug builds, an unlabeled gray box in release — with a small, on-brand
/// fallback. Installed once via `ErrorWidget.builder =
/// buildFriendlyErrorWidget` in `main()`, so it only ever covers the single
/// failed subtree (e.g. one malformed list tile), not the whole screen.
///
/// [AppL10n.of] can theoretically fail to resolve if the error itself broke
/// something above the nearest `Localizations` ancestor — the fallback text
/// covers that narrow case rather than compounding one error with another.
Widget buildFriendlyErrorWidget(FlutterErrorDetails details) {
  return Builder(
    builder: (context) {
      String message;
      try {
        message = AppL10n.of(context).errorWidgetFallback;
      } catch (_) {
        message = 'Something went wrong';
      }
      final theme = Theme.of(context);
      return ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 28,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
