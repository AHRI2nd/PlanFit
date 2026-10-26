import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/home/presentation/weekly_review_screen.dart';
import 'package:planfit/features/schedule/application/schedule_providers.dart';
import 'package:planfit/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedToday extends TodayDate {
  @override
  DateTime build() => DateTime(2030, 1, 7);
}

void main() {
  testWidgets(
    'planned count includes inspectable rows completed in a later week',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.todoDao.upsert(
        TodoItemsCompanion.insert(
          id: 'a',
          title: const Value('Completed later'),
          slotStart: DateTime(2030, 1, 7),
          isDone: const Value(true),
          completedAt: Value(DateTime(2030, 1, 14)),
        ),
      );
      final row = (await db.todoDao.findById('a'))!;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayProvider.overrideWith(_FixedToday.new),
            weeklyPlannedProvider.overrideWith(
              (ref, day) => Stream.value([row]),
            ),
            weeklyCompletedProvider.overrideWith(
              (ref, day) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('ko'),
            localizationsDelegates: const [
              AppL10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppL10n.supportedLocales,
            home: const WeeklyReviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('이 주에 배치된 할 일 · 1'), findsOneWidget);
      expect(find.text('Completed later'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    },
  );
}
