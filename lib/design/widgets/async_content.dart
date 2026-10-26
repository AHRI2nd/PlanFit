import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

/// Retains available data during refresh while making failures recoverable.
class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({super.key, required this.value, required this.onRetry,
    required this.builder});
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final content = builder(value.requireValue);
      if (!value.hasError) return content;
      return LayoutBuilder(builder: (context, constraints) => Column(
        mainAxisSize: constraints.hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [AsyncStateNotice(onRetry: onRetry),
          if (constraints.hasBoundedHeight) Expanded(child: content) else content],
      ));
    }
    if (value.hasError) return AsyncStateNotice(onRetry: onRetry);
    return const Center(child: CircularProgressIndicator());
  }
}

class AsyncStateNotice extends StatelessWidget {
  const AsyncStateNotice({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l10n.errorWidgetFallback),
        TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh),
          label: Text(l10n.commonRetry)),
      ]),
    );
  }
}

/// Blocks only the initial load; callers can keep displaying previous values.
Widget? asyncGroupPlaceholder(BuildContext context,
    Iterable<AsyncValue<Object?>> values, VoidCallback retry) {
  if (values.every((value) => value.hasValue)) return null;
  if (values.any((value) => value.hasError)) {
    return AsyncStateNotice(onRetry: retry);
  }
  return const Center(child: CircularProgressIndicator());
}
