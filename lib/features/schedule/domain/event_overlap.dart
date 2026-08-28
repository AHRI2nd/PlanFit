import '../../../core/db/app_database.dart';

/// One event's non-overlapping column slot within a cluster of same-time-
/// window events — the day/week views lay each event out at
/// `column/columnCount` of the available width so two events sharing a
/// moment in time never paint over each other at all (a plain diagonal
/// cascade can't guarantee that in general: whichever card is on top hides
/// part of whatever is underneath it, which for two cards of different
/// lengths reads as the *shorter* one's edge silently truncating the
/// longer one's — see this file's own history for a version that got that
/// wrong).
class CascadedEvent {
  const CascadedEvent({
    required this.event,
    required this.column,
    required this.columnCount,
  });

  final EventRow event;

  /// 0-based column index within the cluster — column 0 renders furthest
  /// left.
  final int column;

  /// How many side-by-side columns this event's cluster needs, i.e. the
  /// most events that are ever simultaneously in progress at once within
  /// it. 1 means [event] doesn't overlap anything and needs no split at
  /// all.
  final int columnCount;
}

/// Groups [events] into overlap clusters — a connected component of the
/// "starts before the other ends" relation, so a chain like A↔B, B↔C but
/// not A↔C still gets laid out together, since a column assignment needs
/// to account for everything *transitively* in the way, not just events
/// that directly overlap [event] itself — and assigns each a non-
/// overlapping [CascadedEvent.column] via the same greedy "first free
/// room" placement real calendar apps use (Google Calendar, Outlook, …):
/// process events earliest-start first (ties broken by longest-duration
/// first, so of two events starting together the one that runs longer —
/// and so is more likely to still be in progress when a third event
/// starts — claims the leftmost column), and place each into the
/// leftmost column whose most recent occupant has already ended by the
/// time this one starts; only open a new column when none does.
///
/// Returns every event annotated with its [CascadedEvent.column] and
/// [CascadedEvent.columnCount] — in no particular paint order, since
/// columns never overlap so painting order doesn't matter for visibility.
///
/// [events] is assumed to already be scoped to whatever a single layout
/// pass should apply within (one day's timeline, one week-view day
/// column) — this doesn't group by day itself.
List<CascadedEvent> cascadeEvents(List<EventRow> events) {
  final sorted = [...events]..sort((a, b) {
    final byStart = a.startAt.compareTo(b.startAt);
    if (byStart != 0) return byStart;
    final aDuration = a.endAt.difference(a.startAt);
    final bDuration = b.endAt.difference(b.startAt);
    final byDuration = bDuration.compareTo(aDuration); // longer first
    return byDuration != 0 ? byDuration : a.id.compareTo(b.id);
  });

  final result = <CascadedEvent>[];
  var clusterStart = 0;
  DateTime? clusterEnd;
  for (var i = 0; i < sorted.length; i++) {
    final e = sorted[i];
    if (clusterEnd != null && !e.startAt.isBefore(clusterEnd)) {
      _appendCluster(sorted, clusterStart, i, result);
      clusterStart = i;
      clusterEnd = e.endAt;
    } else {
      clusterEnd = clusterEnd == null || e.endAt.isAfter(clusterEnd)
          ? e.endAt
          : clusterEnd;
    }
  }
  _appendCluster(sorted, clusterStart, sorted.length, result);
  return result;
}

void _appendCluster(
  List<EventRow> sorted,
  int start,
  int end,
  List<CascadedEvent> result,
) {
  if (start >= end) return;
  // columnEnds[c] is the end time of the last event so far placed in
  // column c — an event can reuse column c once its own start reaches
  // that, per the half-open [start, end) convention the rest of this
  // codebase's overlap checks already use (event_dao.dart's _overlaps,
  // event_span.dart's eventDaysInRange).
  final columnEnds = <DateTime>[];
  final columns = <int>[];
  for (var i = start; i < end; i++) {
    final e = sorted[i];
    var placed = -1;
    for (var c = 0; c < columnEnds.length; c++) {
      if (!e.startAt.isBefore(columnEnds[c])) {
        placed = c;
        break;
      }
    }
    if (placed == -1) {
      placed = columnEnds.length;
      columnEnds.add(e.endAt);
    } else {
      columnEnds[placed] = e.endAt;
    }
    columns.add(placed);
  }
  final columnCount = columnEnds.length;
  for (var i = start; i < end; i++) {
    result.add(
      CascadedEvent(
        event: sorted[i],
        column: columns[i - start],
        columnCount: columnCount,
      ),
    );
  }
}
