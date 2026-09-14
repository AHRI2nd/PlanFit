import '../../../core/db/app_database.dart';
import 'todo_overdue.dart';

/// Orders a to-do list that spans several days — the home screen's 할 일
/// list and every tab of the smart list — so that what needs attention
/// first is at the top.
///
/// Three groups, each ordered by slot time ascending:
///
/// 1. pinned
/// 2. overdue
/// 3. everything else
///
/// Pinning is how a user says "keep this in front of me", and until now it
/// did nothing to where a to-do sat — it only added an icon and a smart-list
/// tab of its own, so a pinned item due next month stayed buried under
/// everything sooner. Overdue ranks next because it is the one group the
/// user did not choose and cannot see coming.
///
/// Deliberately not applied to the day view or the month panel: those are a
/// single day's list, where the timeline order *is* the information and
/// lifting one row out of it would break the correspondence with the hours
/// down the side.
///
/// Not a database `ORDER BY`: two of the three surfaces that need it
/// (the home list, which concatenates two separate queries, and the smart
/// list's tabs, which each have their own) would need the same clause
/// duplicated per query, and "overdue" depends on the current time rather
/// than on a column. One pure function over the assembled list keeps the
/// rule in one readable place.
List<TodoRow> orderCrossDayTodos(List<TodoRow> todos, {required DateTime now}) {
  int rank(TodoRow t) {
    if (t.isPinned) return 0;
    if (isTodoOverdue(t, now)) return 1;
    return 2;
  }

  // Decorated with the original index so the sort is stable: `List.sort` is
  // not, and two to-dos sharing a rank and a slot time (a whole day's
  // no-time items all sit at midnight) would otherwise be free to swap
  // places on any rebuild, which reads as the list flickering.
  final decorated = [
    for (var i = 0; i < todos.length; i++) (index: i, todo: todos[i]),
  ]..sort((a, b) {
    final byRank = rank(a.todo).compareTo(rank(b.todo));
    if (byRank != 0) return byRank;
    final byTime = a.todo.slotStart.compareTo(b.todo.slotStart);
    if (byTime != 0) return byTime;
    return a.index.compareTo(b.index);
  });
  return [for (final d in decorated) d.todo];
}
