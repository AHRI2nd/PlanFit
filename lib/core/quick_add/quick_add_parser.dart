import 'package:flutter/material.dart' show TimeOfDay;

/// What [parseQuickAdd] pulled out of a free-text line like "내일 오후 3시
/// 회의" — plus [title], the leftover text with every matched phrase
/// stripped out.
class QuickAddResult {
  const QuickAddResult({
    required this.title,
    this.date,
    this.time,
    this.priority,
    this.tags = const [],
  });

  final String title;

  /// The day the phrase pointed at (e.g. "내일"/"tomorrow", "화요일"/
  /// "tuesday", "3월 15일"), or null if none was recognized — the caller
  /// should fall back to whatever day was already in context (today, or
  /// the day view currently open).
  final DateTime? date;

  /// A time-of-day, populated **only** when the phrase was unambiguous —
  /// carried an AM/PM marker (오전/오후/아침/저녁/밤/am/pm), used 24-hour
  /// notation (hour ≥ 13), or named 정오/자정/noon/midnight. A bare number
  /// like "3시"/"at 3" is genuinely ambiguous (3am? 3pm?) and deliberately
  /// left null rather than guessed — silently picking the wrong half of the
  /// day is worse than just not auto-filling it.
  final TimeOfDay? time;

  /// A to-do priority (see `TodoPriority`) from a `!높음`/`!high`-style
  /// token, or null if none was written — unlike date/time, there's no
  /// ambiguous form to deliberately leave unparsed here, since the word
  /// itself is the whole signal.
  final int? priority;

  /// Every `#tag` token found, in the order they appeared. Empty (not null)
  /// when none were written — a to-do simply has no tags then, same as if
  /// the field had never been touched.
  final List<String> tags;
}

/// A small, deterministic (not ML-based) parser for the common Korean/
/// English day and time phrases people actually type into a quick-add box
/// — "내일 오후 3시 회의", "next tuesday 9am standup". Anything it doesn't
/// recognize is simply left in [QuickAddResult.title] untouched, so a
/// completely unparseable input still round-trips as a plain title with no
/// date/time guessed — never a worse outcome than not having this at all.
QuickAddResult parseQuickAdd(String input, {required DateTime now}) {
  var text = input.trim();
  DateTime? date;
  TimeOfDay? time;

  DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String strip(Match m) {
    final replaced = text.replaceRange(m.start, m.end, ' ');
    return replaced;
  }

  // --- Relative day: 오늘/내일/모레, today/tomorrow ---
  final relative = RegExp(
    r'(오늘|내일|모레|today|tomorrow)',
    caseSensitive: false,
  ).firstMatch(text);
  if (relative != null) {
    final word = relative.group(0)!.toLowerCase();
    final offset = switch (word) {
      '오늘' || 'today' => 0,
      '내일' || 'tomorrow' => 1,
      '모레' => 2,
      _ => 0,
    };
    date = dateOnly(now).add(Duration(days: offset));
    text = strip(relative);
  }

  // --- Weekday: (다음주 )?(월|화|수|목|금|토|일)요일, (next )?monday..sunday ---
  if (date == null) {
    final koWeekday = RegExp(r'(다음\s?주\s?)?(월|화|수|목|금|토|일)요일').firstMatch(text);
    if (koWeekday != null) {
      const order = ['월', '화', '수', '목', '금', '토', '일'];
      final target = order.indexOf(koWeekday.group(2)!) + 1; // 1=Mon..7=Sun
      final nextWeek = koWeekday.group(1) != null;
      date = _nextWeekday(dateOnly(now), target, forceNextWeek: nextWeek);
      text = strip(koWeekday);
    } else {
      final enWeekday = RegExp(
        r'(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
        caseSensitive: false,
      ).firstMatch(text);
      if (enWeekday != null) {
        const names = [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday',
        ];
        final target = names.indexOf(enWeekday.group(2)!.toLowerCase()) + 1;
        final nextWeek = enWeekday.group(1) != null;
        date = _nextWeekday(dateOnly(now), target, forceNextWeek: nextWeek);
        text = strip(enWeekday);
      }
    }
  }

  // --- Explicit date: N월 N일 ---
  if (date == null) {
    final explicit = RegExp(r'(\d{1,2})월\s*(\d{1,2})일').firstMatch(text);
    if (explicit != null) {
      final month = int.parse(explicit.group(1)!);
      final day = int.parse(explicit.group(2)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        date = DateTime(now.year, month, day);
        text = strip(explicit);
      }
    }
  }

  // --- Time: 정오/자정/noon/midnight ---
  final namedTime = RegExp(
    r'(정오|자정|noon|midnight)',
    caseSensitive: false,
  ).firstMatch(text);
  if (namedTime != null) {
    final word = namedTime.group(0)!.toLowerCase();
    time = (word == '정오' || word == 'noon')
        ? const TimeOfDay(hour: 12, minute: 0)
        : const TimeOfDay(hour: 0, minute: 0);
    text = strip(namedTime);
  }

  // --- Time: (오전|오후|아침|저녁|밤) N시(반| N분)? ---
  if (time == null) {
    final koTime = RegExp(
      r'(오전|오후|아침|저녁|밤)\s?(\d{1,2})시\s?(반|\d{1,2}분)?',
    ).firstMatch(text);
    if (koTime != null) {
      final isPm =
          koTime.group(1) == '오후' ||
          koTime.group(1) == '저녁' ||
          koTime.group(1) == '밤';
      var hour = int.parse(koTime.group(2)!) % 12;
      if (isPm) hour += 12;
      final minutePart = koTime.group(3);
      final minute = minutePart == null
          ? 0
          : (minutePart == '반'
                ? 30
                : int.parse(minutePart.replaceAll('분', '')));
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute < 60) {
        time = TimeOfDay(hour: hour, minute: minute);
        text = strip(koTime);
      }
    }
  }

  // --- Time: 24-hour bare "N시" where N >= 13 (unambiguous) ---
  if (time == null) {
    final h24 = RegExp(r'(\d{1,2})시\s?(\d{1,2}분)?').firstMatch(text);
    if (h24 != null) {
      final hour = int.parse(h24.group(1)!);
      if (hour >= 13 && hour <= 23) {
        final minutePart = h24.group(2);
        final minute = minutePart == null
            ? 0
            : int.parse(minutePart.replaceAll('분', ''));
        time = TimeOfDay(hour: hour, minute: minute);
        text = strip(h24);
      }
    }
  }

  // --- Time: English "3pm", "9:30am" ---
  if (time == null) {
    final enTime = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s?(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (enTime != null) {
      var hour = int.parse(enTime.group(1)!) % 12;
      if (enTime.group(3)!.toLowerCase() == 'pm') hour += 12;
      final minute = enTime.group(2) == null ? 0 : int.parse(enTime.group(2)!);
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute < 60) {
        time = TimeOfDay(hour: hour, minute: minute);
        text = strip(enTime);
      }
    }
  }

  // --- Tags: #업무 #급함 — any number, order preserved. Matched before
  // priority so a tag that happens to contain "!" text isn't mistaken for a
  // priority marker (moot with today's word list, but keeps the ordering
  // intentional rather than accidental). ---
  final tags = [
    for (final m in RegExp(r'#(\S+)').allMatches(text)) m.group(1)!,
  ];
  if (tags.isNotEmpty) {
    text = text.replaceAll(RegExp(r'#\S+'), ' ');
  }

  // --- Priority: !낮음/!low, !보통/!medium, !높음/!high ---
  int? priority;
  final priorityMatch = RegExp(
    r'!(낮음|보통|높음|low|medium|high)',
    caseSensitive: false,
  ).firstMatch(text);
  if (priorityMatch != null) {
    final word = priorityMatch.group(1)!.toLowerCase();
    priority = switch (word) {
      '낮음' || 'low' => 1,
      '보통' || 'medium' => 2,
      '높음' || 'high' => 3,
      _ => null,
    };
    text = strip(priorityMatch);
  }

  final title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return QuickAddResult(
    title: title,
    date: date,
    time: time,
    priority: priority,
    tags: tags,
  );
}

/// The next date on/after [from] that falls on [targetWeekday] (1=Mon..
/// 7=Sun) — [from] itself counts unless [forceNextWeek].
///
/// [forceNextWeek] means "next week's Tuesday", a *calendar*-week concept:
/// it's the target weekday within the Mon–Sun block right after [from]'s
/// own, regardless of how many days that numerically is — e.g. said on a
/// Wednesday, "다음주 화요일" means 9 days out (next week's Tuesday), not
/// simply "the closest upcoming Tuesday plus 7 days" (which would overshoot
/// to the Tuesday after that, since this week's Tuesday already passed).
DateTime _nextWeekday(
  DateTime from,
  int targetWeekday, {
  required bool forceNextWeek,
}) {
  if (!forceNextWeek) {
    // Dart's `%` on a non-negative divisor always returns a non-negative
    // result, so this is already the closest occurrence on/after `from`
    // (0 when `from` itself is the target weekday).
    final delta = (targetWeekday - from.weekday) % 7;
    return from.add(Duration(days: delta));
  }
  final thisWeekStart = from.subtract(
    Duration(days: (from.weekday - DateTime.monday) % 7),
  );
  final nextWeekStart = thisWeekStart.add(const Duration(days: 7));
  return nextWeekStart.add(Duration(days: targetWeekday - DateTime.monday));
}
