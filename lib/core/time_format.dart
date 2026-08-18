import 'package:flutter/material.dart';

import '../features/settings/application/app_settings.dart';

/// Drop-in replacement for [showTimePicker] that applies
/// [AppSettings.dialTimeFormatPreference] — scoped to just this dialog via
/// [showTimePicker]'s own `builder:` hook, rather than overriding
/// `MediaQuery` for the whole app. That scoping is deliberate: it's what
/// keeps this setting fully independent of
/// [AppSettings.displayTimeFormatPreference] (every other hour-minute label
/// in the app, via `Fmt.time`/`Fmt.hour`) — a blanket app-wide override
/// would otherwise leak into `MediaQuery.alwaysUse24HourFormat` reads
/// elsewhere and silently couple the two settings together.
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required TimeFormatPreference dialFormat,
}) {
  if (dialFormat == TimeFormatPreference.system) {
    return showTimePicker(context: context, initialTime: initialTime);
  }
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(alwaysUse24HourFormat: dialFormat == TimeFormatPreference.h24),
      child: child!,
    ),
  );
}

/// Resolves [preference] to the concrete `use24Hour` bool `Fmt.time`/
/// `Fmt.hour` expect — `system` reads the OS's own setting via the ambient
/// `MediaQuery`, exactly like [showAppTimePicker] does for `system`, but
/// resolved independently here so the two settings never contaminate one
/// another (see this file's top doc).
bool resolveUse24Hour(TimeFormatPreference preference, BuildContext context) {
  return switch (preference) {
    TimeFormatPreference.h24 => true,
    TimeFormatPreference.h12 => false,
    TimeFormatPreference.system =>
      MediaQuery.of(context).alwaysUse24HourFormat,
  };
}
