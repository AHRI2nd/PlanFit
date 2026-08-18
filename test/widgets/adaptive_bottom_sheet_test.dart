import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/design/widgets/adaptive_bottom_sheet.dart';

void main() {
  const bodyKey = Key('sheetBody');

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAdaptiveBottomSheet<void>(
              context: context,
              builder: (_) => const SizedBox(
                key: bodyKey,
                height: 200,
                width: double.infinity,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a phone-width screen gets the unconstrained, full-width sheet it '
    'always had',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openSheet(tester);

      expect(tester.getSize(find.byKey(bodyKey)).width, 375);
    },
  );

  testWidgets(
    'a tablet-width screen caps the sheet at kSheetMaxWidth instead of '
    'stretching it edge to edge',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openSheet(tester);

      expect(tester.getSize(find.byKey(bodyKey)).width, kSheetMaxWidth);
    },
  );

  testWidgets(
    'exactly at kSheetTabletBreakpoint counts as tablet-sized (>=, not >)',
    (tester) async {
      tester.view.physicalSize = const Size(kSheetTabletBreakpoint, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await openSheet(tester);

      expect(tester.getSize(find.byKey(bodyKey)).width, kSheetMaxWidth);
    },
  );
}
