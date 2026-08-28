import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/share_origin.dart';

void main() {
  group('shareOriginOf', () {
    testWidgets(
      'resolves a non-zero rect from a real widget context — the exact '
      'thing share_plus rejects a share() call for omitting on iOS',
      (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox(width: 300, height: 500);
              },
            ),
          ),
        );

        final origin = shareOriginOf(capturedContext);

        expect(origin, isNotNull);
        expect(origin!.width, greaterThan(0));
        expect(origin.height, greaterThan(0));
      },
    );
  });
}
