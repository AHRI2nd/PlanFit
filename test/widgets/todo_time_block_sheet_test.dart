import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/todo/presentation/todo_block_lane.dart';
import 'package:planfit/features/todo/presentation/todo_time_block_sheet.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('overnight block is clipped to day and edits in narrow large text', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await db.todoDao.upsert(TodoItemsCompanion.insert(id: 'a', title: const Value('Overnight work'),
      slotStart: DateTime(2030, 1, 1, 23), slotEnd: Value(DateTime(2030, 1, 2, 1))));
    final row = (await db.todoDao.findById('a'))!;
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs), todoDaoProvider.overrideWithValue(db.todoDao)],
      child: MaterialApp(theme: AppTheme.light(), locale: const Locale('ko'), supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: const [AppL10n.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)), child: child!),
        home: Scaffold(body: Builder(builder: (context) => Column(children: [
          SizedBox(height: 480, child: TodoBlockLane(rows: [row], day: DateTime(2030, 1, 2), hourHeight: 20, use24Hour: true)),
          TextButton(onPressed: () => showTodoTimeBlockSheet(context, row), child: const Text('Plan')),
        ]))))));
    await tester.pump();
    final block = find.byKey(ValueKey('todo-block-a-${DateTime(2030, 1, 2)}'));
    expect(tester.getSize(block).height, 20);
    await tester.tap(find.text('Plan')); await tester.pumpAndSettle();
    await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('시간에 배치'), findsOneWidget);
    await tester.ensureVisible(find.text('활동 시간과 휴식')); await tester.tap(find.text('활동 시간과 휴식'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
