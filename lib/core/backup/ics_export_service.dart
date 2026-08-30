import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../../features/schedule/domain/event_input.dart';
import '../../features/schedule/domain/event_repository.dart';
import 'ics_parser.dart';

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
    final result = const IcsParser().parse(raw);

    for (final v in result.vevents) {
      await eventRepository.save(
        EventInput(
          title: v.title,
          memo: v.memo,
          location: v.location,
          startAt: v.start,
          endAt: v.end,
          isAllDay: v.isAllDay,
          notify: false,
        ),
      );
    }
    return IcsImportSummary(
      eventCount: result.vevents.length,
      skippedCount: result.skipped,
    );
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
