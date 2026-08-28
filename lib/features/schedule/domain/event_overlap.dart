import '../../../core/db/app_database.dart';

/// One event's position within a cluster of same-time-window events, for
/// fanning overlapping cards out in a cascade instead of stacking them
/// exactly on top of each other (where every card past the first would be
/// completely hidden behind it).
class CascadedEvent {
  const CascadedEvent({
    required this.event,
    required this.index,
    required this.siblingCount,
  });

  final EventRow event;

  /// 0-based position within the cluster, ordered by start time (ties
  /// broken by id) — a higher index starts later (or ties and sorts later
  /// by id) and should be painted on top of lower indices.
  final int index;

  /// How many events share this cluster, including this one. 1 means
  /// [event] doesn't overlap anything and needs no cascade offset at all.
  final int siblingCount;
}

/// Groups [events] into overlap clusters — a connected component of the
/// "starts before the other ends" relation, so a chain like A↔B, B↔C but
/// not A↔C still fans all three out together, since a cascade needs to
/// clear space from every card that's *transitively* in the way, not just
/// the ones it directly overlaps.
///
/// Returns every event annotated with its cluster [CascadedEvent.index] and
/// [CascadedEvent.siblingCount], **in the order they should be painted** —
/// ascending by start time (ties by id), so a caller that renders them in a
/// [Stack] in this order automatically puts each later-starting card in
/// front of the ones it partially covers, without needing to separately
/// sort by index.
///
/// [events] is assumed to already be scoped to whatever a single cascade
/// should apply within (one day's timeline, one week-view day column) —
/// this doesn't group by day itself.
List<CascadedEvent> cascadeEvents(List<EventRow> events) {
  final sorted = [...events]..sort((a, b) {
    final byStart = a.startAt.compareTo(b.startAt);
    return byStart != 0 ? byStart : a.id.compareTo(b.id);
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
  final count = end - start;
  for (var i = start; i < end; i++) {
    result.add(
      CascadedEvent(event: sorted[i], index: i - start, siblingCount: count),
    );
  }
}
