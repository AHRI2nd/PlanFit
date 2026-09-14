import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:planfit/core/db/app_database.dart';
import 'package:planfit/core/di.dart';
import 'package:planfit/design/theme/app_theme.dart';
import 'package:planfit/features/todo/application/todo_providers.dart';
import 'package:planfit/features/todo/presentation/todo_selection.dart';
import 'package:planfit/l10n/app_localizations.dart';

import '../todo_controller_test.mocks.dart';

/// `TodoSelectionMixin` carries the long-press multi-select state and the
/// two bulk actions behind it, shared by `HourlyTodoList` and
/// `TodoSmartListScreen` so both behave identically. Nothing tested it, which
/// left bulk delete — the only way to remove several to-dos at once, and one
/// the user confirms without seeing a list of what goes — uncovered along
/// with the undo that is its sole safety net.
///
/// Driven through a minimal host widget, calling the mixin's own methods
/// rather than tapping a button whose async callback nothing awaits.
///
/// The bulk actions run inside `tester.runAsync`, which is not optional
/// here: `TodoController.remove` reaches `dao.watchSubtasks(id).first` to
/// capture what undo will need, and a Drift `.watch()` stream never emits
/// inside `testWidgets`' fake-async zone — the call simply hangs, past even
/// the framework's own per-test timeout, which is driven by the same fake
/// clock. `runAsync` steps outside that zone so the stream can deliver.
class _Host extends ConsumerStatefulWidget {
  const _Host({super.key});
  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> with TodoSelectionMixin<_Host> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  late AppDatabase db;
  late MockNotificationPort notifications;
  late MockRemindersPort reminders;
  final hostKey = GlobalKey<_HostState>();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notifications = MockNotificationPort();
    reminders = MockRemindersPort();
    when(notifications.scheduleForTodo(any)).thenAnswer((_) async {});
    when(notifications.cancelForTodo(any)).thenAnswer((_) async {});
    when(reminders.isEnabled).thenReturn(false);
    when(reminders.deleteTodo(any)).thenAnswer((_) async {});
  });

  tearDown(() => db.close());

  // Return type left to inference: riverpod's `Override` is sealed and not
  // exported under that name, so it can't be written out here.
  overrides() => [
    appDatabaseProvider.overrideWithValue(db),
    notificationPortProvider.overrideWithValue(notifications),
    remindersPortProvider.overrideWithValue(reminders),
  ];

  Future<List<TodoRow>> pumpHost(WidgetTester tester, {int todos = 0}) async {
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    for (var i = 0; i < todos; i++) {
      await container
          .read(todoControllerProvider)
          .add(title: 'todo-$i', slotStart: DateTime(2026, 3, 10, 9 + i));
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
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
          home: Scaffold(body: _Host(key: hostKey)),
        ),
      ),
    );
    final rows = await db.todoDao.all();
    rows.sort((a, b) => a.slotStart.compareTo(b.slotStart));
    return rows;
  }

  _HostState host() => hostKey.currentState!;

  group('selection state', () {
    testWidgets('a long press enters selection mode with that one row picked', (
      tester,
    ) async {
      await pumpHost(tester);
      expect(host().selectionMode, isFalse);

      host().enterSelection('a');
      await tester.pump();

      expect(host().selectionMode, isTrue);
      expect(host().selectedIds, {'a'});
    });

    testWidgets('entering again replaces the selection rather than adding to '
        'it — a long press is a fresh start, not another tap', (tester) async {
      await pumpHost(tester);
      host().enterSelection('a');
      host().toggleSelected('b');
      await tester.pump();
      expect(host().selectedIds, {'a', 'b'});

      host().enterSelection('c');
      await tester.pump();

      expect(host().selectedIds, {'c'});
    });

    testWidgets('deselecting the last row leaves selection mode on its own, '
        'so the toolbar cannot sit there with nothing selected', (
      tester,
    ) async {
      await pumpHost(tester);
      host().enterSelection('a');
      host().toggleSelected('b');
      await tester.pump();

      host().toggleSelected('a');
      await tester.pump();
      expect(host().selectionMode, isTrue, reason: 'one still selected');

      host().toggleSelected('b');
      await tester.pump();

      expect(host().selectionMode, isFalse);
      expect(host().selectedIds, isEmpty);
    });

    testWidgets('exitSelection clears both the flag and the set', (
      tester,
    ) async {
      await pumpHost(tester);
      host().enterSelection('a');
      host().toggleSelected('b');
      await tester.pump();

      host().exitSelection();
      await tester.pump();

      expect(host().selectionMode, isFalse);
      expect(host().selectedIds, isEmpty);
    });
  });

  group('bulk actions', () {
    testWidgets('bulkComplete marks exactly the selected to-dos done and '
        'leaves the rest alone', (tester) async {
      final rows = await pumpHost(tester, todos: 3);
      host().enterSelection(rows[0].id);
      host().toggleSelected(rows[2].id);
      await tester.pump();

      await tester.runAsync(() => host().bulkComplete());
      await tester.pump();

      final after = {for (final t in await db.todoDao.all()) t.id: t.isDone};
      expect(after[rows[0].id], isTrue);
      expect(after[rows[1].id], isFalse);
      expect(after[rows[2].id], isTrue);
      expect(host().selectionMode, isFalse, reason: 'the toolbar closes after');
    });

    testWidgets('bulkDelete removes exactly the selected to-dos', (
      tester,
    ) async {
      final rows = await pumpHost(tester, todos: 3);
      host().enterSelection(rows[0].id);
      host().toggleSelected(rows[2].id);
      await tester.pump();

      await tester.runAsync(() => host().bulkDelete());
      await tester.pump();

      expect((await db.todoDao.all()).map((t) => t.id), [rows[1].id]);
      expect(host().selectionMode, isFalse);
      // showAutoDismissSnackBar arms its own Timer (see snackbar_x.dart) and
      // flutter_test fails a test that ends with one pending.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('offers an undo naming how many went, so the count is '
        'visible even though the rows themselves are already gone', (
      tester,
    ) async {
      final rows = await pumpHost(tester, todos: 3);
      host().enterSelection(rows[0].id);
      host().toggleSelected(rows[1].id);
      await tester.pump();

      await tester.runAsync(() => host().bulkDelete());
      await tester.pump();

      expect(find.text('2개를 삭제했어요'), findsOneWidget);
      expect(find.text('실행 취소'), findsOneWidget);
      // What that action does per row — reinstating the to-do and its
      // subtasks under their original ids — is TodoController.restore, which
      // has its own tests. Driving it from here would mean tapping a
      // SnackBarAction whose async database writes nothing in the test can
      // await, which is exactly the race these tests avoid by calling the
      // mixin's own futures directly.
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
