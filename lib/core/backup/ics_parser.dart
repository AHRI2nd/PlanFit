/// One parsed RFC 5545 `VEVENT` block — the shared building block behind
/// both [IcsExportService.importFromFile]'s "add as a brand-new editable
/// event" flow and `HolidayCalendarService`'s "mirror as a read-only row"
/// flow, so the actual parsing (folded lines, escaping, the handful of
/// DTSTART/DTEND date-time shapes real-world `.ics` files use) lives in
/// exactly one place rather than being duplicated per caller.
class IcsVevent {
  const IcsVevent({
    required this.uid,
    required this.title,
    this.memo,
    this.location,
    required this.start,
    required this.end,
    required this.isAllDay,
  });

  /// The VEVENT's own `UID` if it had one, otherwise a stable id
  /// synthesized from title+start — good enough to recognize "the same
  /// event" across two parses of the same feed (a periodic re-sync of a
  /// subscription, in particular) even when the source never set one.
  final String uid;
  final String title;
  final String? memo;
  final String? location;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
}

/// What one [IcsParser.parse] call found.
class IcsParseResult {
  const IcsParseResult({required this.vevents, required this.skipped});

  final List<IcsVevent> vevents;

  /// `VEVENT`s that couldn't be parsed (missing `SUMMARY`/`DTSTART`, or an
  /// unrecognized date format) — counted separately so a partially-garbled
  /// feed still visibly yields what it can rather than failing outright.
  final int skipped;
}

/// Parses raw RFC 5545 (`.ics`) text into [IcsVevent]s. Stateless and
/// side-effect-free — what happens to a parsed VEVENT (saved as an
/// editable event, upserted as a read-only mirror row, …) is entirely the
/// caller's concern.
class IcsParser {
  const IcsParser();

  IcsParseResult parse(String raw) {
    final blocks = _splitVevents(_unfold(raw));
    final vevents = <IcsVevent>[];
    var skipped = 0;
    for (final block in blocks) {
      final v = _parseVevent(block);
      if (v == null) {
        skipped++;
      } else {
        vevents.add(v);
      }
    }
    return IcsParseResult(vevents: vevents, skipped: skipped);
  }

  /// RFC 5545 continuation lines start with a single space or tab and mean
  /// "glue this onto the previous line" — the inverse of
  /// `IcsExportService._fold`. Must run before any other line-based
  /// parsing, since a folded line can split in the middle of a property
  /// value.
  List<String> _unfold(String raw) {
    final rawLines = raw.split(RegExp(r'\r\n|\r|\n'));
    final lines = <String>[];
    for (final line in rawLines) {
      if (line.isNotEmpty &&
          (line.startsWith(' ') || line.startsWith('\t')) &&
          lines.isNotEmpty) {
        lines[lines.length - 1] += line.substring(1);
      } else {
        lines.add(line);
      }
    }
    return lines;
  }

  /// Every `BEGIN:VEVENT`..`END:VEVENT` block's inner lines, as a list of
  /// blocks — deliberately tolerant of anything outside those markers
  /// (`VCALENDAR` headers, `VTIMEZONE` blocks, other component types), since
  /// this only ever looks for `VEVENT`.
  List<List<String>> _splitVevents(List<String> lines) {
    final blocks = <List<String>>[];
    List<String>? current;
    for (final line in lines) {
      if (line == 'BEGIN:VEVENT') {
        current = [];
      } else if (line == 'END:VEVENT') {
        if (current != null) blocks.add(current);
        current = null;
      } else if (current != null) {
        current.add(line);
      }
    }
    return blocks;
  }

  /// Null when the block is missing a title or a usable start time.
  IcsVevent? _parseVevent(List<String> lines) {
    String? uid;
    String? summary;
    String? description;
    String? location;
    DateTime? start;
    DateTime? end;
    var isAllDay = false;

    for (final line in lines) {
      final colon = line.indexOf(':');
      if (colon == -1) continue;
      final rawKey = line.substring(0, colon);
      final value = line.substring(colon + 1);
      // Strip parameters (e.g. `DTSTART;VALUE=DATE` / `DTSTART;TZID=...`) —
      // the parameters themselves are inspected separately below only for
      // the DTSTART/DTEND all-day check.
      final key = rawKey.split(';').first;

      switch (key) {
        case 'UID':
          uid = _unescape(value);
        case 'SUMMARY':
          summary = _unescape(value);
        case 'DESCRIPTION':
          description = _unescape(value);
        case 'LOCATION':
          location = _unescape(value);
        case 'DTSTART':
          isAllDay =
              rawKey.contains('VALUE=DATE') && !rawKey.contains('DATE-TIME');
          start = _parseIcsDateTime(value, isAllDay: isAllDay);
        case 'DTEND':
          end = _parseIcsDateTime(
            value,
            isAllDay:
                rawKey.contains('VALUE=DATE') && !rawKey.contains('DATE-TIME'),
          );
      }
    }

    if (summary == null || summary.isEmpty || start == null) return null;
    // A VEVENT with no DTEND is valid RFC 5545 (a zero-duration point in
    // time) — give it a sensible fallback duration rather than rejecting it
    // outright, same "never worse than not importing at all" spirit as
    // quick_add_parser's unrecognized-phrase handling.
    end ??= start.add(
      isAllDay ? const Duration(days: 1) : const Duration(hours: 1),
    );

    final resolvedUid = (uid != null && uid.isNotEmpty)
        ? uid
        : '${summary.hashCode}-${start.millisecondsSinceEpoch}';

    return IcsVevent(
      uid: resolvedUid,
      title: summary,
      memo: description,
      location: location,
      start: start,
      end: end,
      isAllDay: isAllDay,
    );
  }

  /// Handles the three DTSTART/DTEND shapes real-world `.ics` files use:
  /// a bare `VALUE=DATE` (all-day, no zone), a trailing `Z` (UTC, converted
  /// to local), or a naive local timestamp (`TZID=...` or no qualifier at
  /// all — taken at face value, since resolving an arbitrary `TZID` would
  /// need the file's own `VTIMEZONE` block parsed too; close enough for
  /// same-timezone personal imports, which is the overwhelmingly common
  /// case for this app).
  DateTime? _parseIcsDateTime(String value, {required bool isAllDay}) {
    if (isAllDay) {
      final m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(value);
      if (m == null) return null;
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    final m = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$',
    ).firstMatch(value);
    if (m == null) return null;
    final naive = DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
    final isUtc = m.group(7) == 'Z';
    return isUtc
        ? DateTime.utc(
            naive.year,
            naive.month,
            naive.day,
            naive.hour,
            naive.minute,
            naive.second,
          ).toLocal()
        : naive;
  }

  /// The inverse of `IcsExportService._escape` — a single left-to-right
  /// pass rather than sequential global replaces, since replace order
  /// matters here: undoing `\\` before `\n`/`\,`/`\;` would eat the
  /// backslash those still need to match.
  String _unescape(String text) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < text.length) {
      final c = text[i];
      if (c == r'\' && i + 1 < text.length) {
        final next = text[i + 1];
        switch (next) {
          case 'n' || 'N':
            buffer.write('\n');
            i += 2;
          case ',':
            buffer.write(',');
            i += 2;
          case ';':
            buffer.write(';');
            i += 2;
          case r'\':
            buffer.write(r'\');
            i += 2;
          default:
            buffer.write(c);
            i++;
        }
      } else {
        buffer.write(c);
        i++;
      }
    }
    return buffer.toString();
  }
}
