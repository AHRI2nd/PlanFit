import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../../features/schedule/domain/event_input.dart';
import '../../features/schedule/domain/event_repository.dart';

/// What [IcsExportService.importFromFile] found and did — surfaced to the
/// user so an import never feels like it silently did (or didn't do)
/// something, same reasoning as [BackupImportSummary].
class IcsImportSummary {
  const IcsImportSummary({
    required this.eventCount,
    required this.skippedCount,
  });

  final int eventCount;

  /// `VEVENT`s that couldn't be parsed (missing `SUMMARY`/`DTSTART`, or an
  /// unrecognized date format) — counted separately so a partially-garbled
  /// file still visibly imports what it can rather than failing outright.
  final int skippedCount;
}

/// Exports every event as a standard iCalendar (.ics) file, and imports one
/// back in — unlike [BackupService]'s JSON format (PlanFit-only, round-trips
/// every field for a same-app restore), this is for moving events *between*
/// PlanFit and any other calendar app that understands RFC 5545.
///
/// Each materialized occurrence of a recurring series is written as its own
/// plain `VEVENT` (no `RRULE`), mirroring how PlanFit already stores and
/// pushes them to the device calendar — see `EventRepositoryImpl`'s doc
/// comment on why recurrence is materialized instead of expressed as an
/// RRULE. Importing follows the same convention in reverse: a `VEVENT`
/// carrying an `RRULE` is imported as a single occurrence at its own
/// `DTSTART` — expanding an arbitrary external RRULE (FREQ/INTERVAL/COUNT/
/// BYDAY/…) isn't attempted, so a recurring series from another app lands
/// as just its first written occurrence, not the whole series.
class IcsExportService {
  IcsExportService({required this.eventRepository});

  final EventRepository eventRepository;

  Future<File> exportToFile() async {
    final events = await eventRepository.allEvents();
    final ics = _buildIcs(events);

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final file = File('${dir.path}/planfit-$stamp.ics');
    await file.writeAsString(ics);
    return file;
  }

  /// Same as [exportToFile] but for just one event — the event editor's
  /// "share" action, for sending a single invite/appointment to someone
  /// rather than the whole calendar.
  Future<File> exportEventToFile(EventRow event) async {
    final ics = _buildIcs([event]);

    final dir = await getTemporaryDirectory();
    final safeTitle = event.title.isEmpty
        ? 'event'
        : event.title.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final file = File('${dir.path}/$safeTitle.ics');
    await file.writeAsString(ics);
    return file;
  }

  /// Reads a `.ics` file and adds every `VEVENT` it can parse as a brand-new
  /// local event (through [EventRepository.save], so it behaves exactly
  /// like manually creating one — pushed to the device calendar if sync is
  /// on, notifications off by default since the source file carries none).
  /// Never overwrites existing events: every import gets a fresh id, so
  /// re-importing the same file creates duplicates rather than silently
  /// merging (unlike [BackupService.importFromFile], which is designed
  /// around re-importing the same PlanFit-originated backup safely).
  Future<IcsImportSummary> importFromFile(String path) async {
    final raw = await File(path).readAsString();
    final veventBlocks = _splitVevents(_unfold(raw));

    var imported = 0;
    var skipped = 0;
    for (final block in veventBlocks) {
      final input = _parseVevent(block);
      if (input == null) {
        skipped++;
        continue;
      }
      await eventRepository.save(input);
      imported++;
    }
    return IcsImportSummary(eventCount: imported, skippedCount: skipped);
  }

  /// RFC 5545 continuation lines start with a single space or tab and mean
  /// "glue this onto the previous line" — the inverse of [_fold]. Must run
  /// before any other line-based parsing, since a folded line can split in
  /// the middle of a property value.
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

  /// Null when the block is missing a title or a usable start time — the
  /// two fields [EventInput] can't do without.
  EventInput? _parseVevent(List<String> lines) {
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

    return EventInput(
      title: summary,
      memo: description,
      location: location,
      startAt: start,
      endAt: end,
      isAllDay: isAllDay,
      notify: false,
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

  /// The inverse of [_escape] — a single left-to-right pass rather than
  /// sequential global replaces, since replace order matters here: undoing
  /// `\\` before `\n`/`\,`/`\;` would eat the backslash those still need to
  /// match.
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

  String _buildIcs(List<EventRow> events) {
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//PlanFit//PlanFit Calendar//KO',
      'CALSCALE:GREGORIAN',
    ];
    for (final e in events) {
      lines.addAll(_vevent(e));
    }
    lines.add('END:VCALENDAR');
    // RFC 5545 requires CRLF line endings.
    return lines.join('\r\n');
  }

  List<String> _vevent(EventRow e) {
    final lines = <String>[
      'BEGIN:VEVENT',
      _fold('UID:${e.id}@planfit.app'),
      _fold('DTSTAMP:${_utcStamp(DateTime.now())}'),
    ];
    if (e.isAllDay) {
      // DTEND is already exclusive (the day after the last day) in both
      // RFC 5545's all-day convention and PlanFit's own EventRow.endAt
      // (see event_editor_sheet.dart's all-day normalization) — no
      // conversion needed between the two.
      lines.add('DTSTART;VALUE=DATE:${_dateStamp(e.startAt)}');
      lines.add('DTEND;VALUE=DATE:${_dateStamp(e.endAt)}');
    } else {
      lines.add('DTSTART:${_utcStamp(e.startAt)}');
      lines.add('DTEND:${_utcStamp(e.endAt)}');
    }
    lines.add(_fold('SUMMARY:${_escape(e.title)}'));
    if (e.memo != null && e.memo!.isNotEmpty) {
      lines.add(_fold('DESCRIPTION:${_escape(e.memo!)}'));
    }
    if (e.location != null && e.location!.isNotEmpty) {
      lines.add(_fold('LOCATION:${_escape(e.location!)}'));
    }
    lines.add('END:VEVENT');
    return lines;
  }

  String _escape(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  String _utcStamp(DateTime dt) {
    final u = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}'
        'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  String _dateStamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}';
  }

  /// RFC 5545 caps a content line at 75 octets, continued on the next line
  /// with a leading space. A simplified char-based fold (rather than exact
  /// UTF-8 octet counting) — plenty for personal event titles/memos, and
  /// every mainstream calendar app tolerates it.
  String _fold(String line) {
    const maxLen = 75;
    if (line.length <= maxLen) return line;
    final buffer = StringBuffer();
    var start = 0;
    var first = true;
    while (start < line.length) {
      final take = first ? maxLen : maxLen - 1;
      final end = (start + take).clamp(0, line.length);
      if (!first) buffer.write('\r\n ');
      buffer.write(line.substring(start, end));
      start = end;
      first = false;
    }
    return buffer.toString();
  }
}
