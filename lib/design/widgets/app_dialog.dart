import 'package:flutter/material.dart';

/// Whether a dialog is pushed on the root navigator instead of the nearest
/// enclosing one. Always `false` here, and the reason is load-bearing on
/// Android, so every dialog in the app goes through the wrappers below
/// rather than calling `showDialog`/`showDatePicker`/`showTimePicker`
/// directly with the framework's own default of `true`.
///
/// Android is told whether Flutter will handle the back gesture via
/// `SystemNavigator.setFrameworkHandlesBack`. That bool is whatever a
/// `NavigationNotification` carries by the time it reaches
/// `MaterialApp.router`: each `Navigator` it passes through upgrades a
/// `false` to `true` if that navigator itself can pop — but only for
/// notifications dispatched from *below* it.
///
/// A root-navigator dialog breaks that chain. On dismissal the root
/// navigator dispatches `canHandlePop: rootNavigator.canPop()` from its own
/// context, and under go_router's `StatefulShellRoute` the root holds only
/// the shell page, so that value is `false`. The notification starts above
/// the branch navigator, so the sheets and pages still open inside the
/// branch never get to correct it, and Android is left believing Flutter
/// has nothing to pop. The next back press runs Android's default handler
/// and finishes the activity: the app restarts on the home screen and any
/// in-progress edit is gone.
///
/// Keeping dialogs on the nearest navigator — the same one the sheet or
/// page that opened them lives on — keeps the notification originating
/// below that navigator, where it is upgraded correctly.
///
/// This only bites routes pushed imperatively (`showModalBottomSheet`,
/// `Navigator.push`); the declarative `GoRoute` screens under
/// `app_router.dart` were measured to stay correct either way. They go
/// through these wrappers too, so the next dialog added anywhere in the app
/// inherits the fix instead of having to rediscover it.
const bool kDialogUsesRootNavigator = false;

/// [showDialog] with [kDialogUsesRootNavigator] applied.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: kDialogUsesRootNavigator,
    builder: builder,
  );
}

/// [showDatePicker] with [kDialogUsesRootNavigator] applied.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    useRootNavigator: kDialogUsesRootNavigator,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
}
