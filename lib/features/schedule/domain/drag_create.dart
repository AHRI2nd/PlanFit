/// Converts a drag-to-create gesture's pixel range into a snapped
/// [start, end) time range, shared by the day and week timelines' own
/// long-press-drag-to-create gestures.
///
/// [anchorY]/[currentY] are Y positions in the timeline's own coordinate
/// space (0 = [dayStart], one hour = [hourHeight] pixels) — order doesn't
/// matter, since dragging either up or down from the anchor is valid, same
/// as most calendar apps. Both snap to the nearest [snapMinutes]; a range
/// shorter than [minDurationMinutes] (including a tap-without-drag, which
/// yields a zero-length range) is widened up to it, favoring extending the
/// end unless that would run past the visible day.
(DateTime, DateTime) snappedCreateRange(
  DateTime dayStart,
  double anchorY,
  double currentY, {
  required double hourHeight,
  int snapMinutes = 15,
  int minDurationMinutes = 30,
}) {
  const dayMinutes = 24 * 60;
  int minutesFor(double y) {
    final raw = y / hourHeight * 60;
    return ((raw / snapMinutes).round() * snapMinutes)
        .clamp(0, dayMinutes)
        .toInt();
  }

  var startMin = minutesFor(anchorY < currentY ? anchorY : currentY);
  var endMin = minutesFor(anchorY < currentY ? currentY : anchorY);
  if (endMin - startMin < minDurationMinutes) {
    endMin = (startMin + minDurationMinutes).clamp(0, dayMinutes);
    if (endMin - startMin < minDurationMinutes) {
      startMin = endMin - minDurationMinutes;
    }
  }
  return (
    dayStart.add(Duration(minutes: startMin)),
    dayStart.add(Duration(minutes: endMin)),
  );
}
