import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/widgets/app_dialog.dart';

/// Guards the Android back gesture against dialogs pushed on the root
/// navigator (see [kDialogUsesRootNavigator] for the full mechanism).
///
/// What broke in the real app: opening a date/time picker or a confirm
/// dialog from the to-do edit sheet or the event editor, closing it, then
/// pressing back — the activity finished and the app restarted on the home
/// screen with the in-progress edit gone. The framework had told Android it
/// had nothing to pop, even though the sheet that opened the dialog was
/// still on screen.
///
/// These tests assert on the exact bool the framework hands the platform,
/// `SystemNavigator.setFrameworkHandlesBack`, over a two-navigator tree
/// that stands in for `StatefulShellRoute`'s root + branch pair.
void main() {
  /// `setFrameworkHandlesBack` is an Android-only platform call, and the
  /// override has to be cleared before the test body returns — the test
  /// binding checks for leaked debug variables at that point, not in
  /// `tearDown`.
  Future<void> onAndroid(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Every value passed to `SystemNavigator.setFrameworkHandlesBack`, in
  /// order. The last one is what Android is acting on.
  List<bool> recordHandlesBack(WidgetTester tester) {
    final recorded = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
          recorded.add(call.arguments as bool);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return recorded;
  }

  /// A root navigator holding one page, that page holding a nested
  /// navigator — the shape `StatefulShellRoute` builds, and the shape that
  /// makes a root-navigator dialog's pop notification skip the navigator
  /// that actually has something to pop.
  ///
  /// Pumps with a second route already pushed on the nested navigator,
  /// standing in for an open bottom sheet or editor page.
  Future<BuildContext> pumpShell(WidgetTester tester) async {
    late BuildContext inner;
    final nestedKey = GlobalKey<NavigatorState>();

    // WidgetsApp only forwards navigation notifications to the platform
    // once it has a lifecycle state, so give it one before the first pump.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: nestedKey,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('branch root')),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    unawaitedPush(nestedKey, (context) {
      inner = context;
      return const Scaffold(body: Text('open sheet'));
    });
    await tester.pumpAndSettle();

    return inner;
  }

  testWidgets(
    'a dialog opened from a nested-navigator route leaves the framework '
    'still handling back once it closes',
    (tester) async => onAndroid(() async {
      final handlesBack = recordHandlesBack(tester);
      final context = await pumpShell(tester);

      expect(
        handlesBack.last,
        isTrue,
        reason: 'the pushed route is poppable, so back is ours to handle',
      );

      final future = showAppDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('close'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      await future;

      expect(
        handlesBack.last,
        isTrue,
        reason:
            'the route that opened the dialog is still on screen, so back '
            'must still pop it rather than finish the activity',
      );
    }),
  );

  testWidgets(
    'the same flow through the framework default of useRootNavigator: true '
    'is what regresses — the guard above is not vacuous',
    (tester) async => onAndroid(() async {
      final handlesBack = recordHandlesBack(tester);
      final context = await pumpShell(tester);
      expect(handlesBack.last, isTrue);

      final future = showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('close'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      await future;

      expect(
        handlesBack.last,
        isFalse,
        reason:
            'reproduces the bug: the root navigator reports its own empty '
            'back stack from above the nested navigator, so nothing gets to '
            'correct it',
      );
    }),
  );

  testWidgets('showAppDatePicker is on the nested navigator too', (
    tester,
  ) async => onAndroid(() async {
    final handlesBack = recordHandlesBack(tester);
    final context = await pumpShell(tester);
    expect(handlesBack.last, isTrue);

    final future = showAppDatePicker(
      context: context,
      initialDate: DateTime(2026, 9, 15),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await future;

    expect(handlesBack.last, isTrue);
  }));
}

/// Pushes [builder] onto [key]'s navigator without awaiting the route's
/// result — the tests only care that the route is on the stack.
void unawaitedPush(
  GlobalKey<NavigatorState> key,
  Widget Function(BuildContext) builder,
) {
  key.currentState!.push(
    MaterialPageRoute<void>(builder: (context) => builder(context)),
  );
}
