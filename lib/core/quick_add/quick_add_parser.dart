import 'package:flutter/material.dart' show TimeOfDay;

import '../date_math.dart';

/// Every spelling the English explicit-date pattern accepts, mapped to its
/// month number — both the full name and the abbreviation resolve to the
/// same key here, since the regex's own `(?:...)?` optional suffixes are
/// what actually distinguish "mar" from "march" at match time.
const Map<String, int> _englishMonths = {
  'jan': 1, 'january': 1,
  'feb': 2, 'february': 2,
  'mar': 3, 'march': 3,
  'apr': 4, 'april': 4,
  'may': 5,
  'jun': 6, 'june': 6,
  'jul': 7, 'july': 7,
  'aug': 8, 'august': 8,
  'sep': 9, 'sept': 9, 'september': 9,
  'oct': 10, 'october': 10,
  'nov': 11, 'november': 11,
  'dec': 12, 'december': 12,
};

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

  /// The day the phrase pointed at (e.g. "내일"/"tomorrow"/"明日",
  /// "화요일"/"tuesday"/"火曜日", "3월 15일"/"March 15th"/"3月15日"), or null
  /// if none was recognized — the caller should fall back to whatever day
  /// was already in context (today, or the day view currently open).
  final DateTime? date;

  /// A time-of-day, populated **only** when the phrase was unambiguous —
  /// carried an AM/PM marker (오전/오후/아침/저녁/밤, 午前/午後/朝/夜/晩,
  /// am/pm), used 24-hour notation (hour ≥ 13), or named
  /// 정오/자정/正午/真夜中/noon/midnight. A bare number
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
/// English/Japanese day and time phrases people actually type into a
/// quick-add box — "내일 오후 3시 회의", "next tuesday 9am standup", "明日
/// 午後3時 会議". Each language's phrases are matched independently (not
/// translated through one another), so this is really three parsers sharing
/// one pass over the text rather than one language-agnostic engine —
/// supporting a new language means adding its own patterns, not extending a
/// shared vocabulary. Anything none of them recognize is simply left in
/// [QuickAddResult.title] untouched, so a completely unparseable input still
/// round-trips as a plain title with no date/time guessed — never a worse
/// outcome than not having this at all.
QuickAddResult parseQuickAdd(String input, {required DateTime now}) {
  var text = input.trim();
  DateTime? date;
  TimeOfDay? time;

  DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String strip(Match m) {
    final replaced = text.replaceRange(m.start, m.end, ' ');
    return replaced;
  }

  // --- Tags: #업무 #급함 — any number, order preserved. Stripped out first,
  // before any date/time phrase is matched, so a tag whose text happens to
  // contain a date/time word (e.g. "#내일신문") can't have that word torn out
  // from inside the tag by the parsers below — that left the tag emptied
  // (dropped entirely, since `#` followed by whitespace no longer matches
  // the tag pattern) while wrongly setting the date/time anyway. ---
  final tags = [
    for (final m in RegExp(r'#(\S+)').allMatches(text)) m.group(1)!,
  ];
  if (tags.isNotEmpty) {
    text = text.replaceAll(RegExp(r'#\S+'), ' ');
  }

  // --- Relative day: 오늘/내일/모레, today/tomorrow, 今日/明日/明後日 ---
  final relative = RegExp(
    r'(오늘|내일|모레|today|tomorrow|明後日|今日|明日)',
    caseSensitive: false,
  ).firstMatch(text);
  if (relative != null) {
    final word = relative.group(0)!.toLowerCase();
    final offset = switch (word) {
      '오늘' || 'today' || '今日' => 0,
      '내일' || 'tomorrow' || '明日' => 1,
      '모레' || '明後日' => 2,
      _ => 0,
    };
    date = addCalendarDays(dateOnly(now), offset);
    text = strip(relative);
  }

  // --- Weekday: (다음주 )?(월|화|수|목|금|토|일)요일,
  // (来週)?(月|火|水|木|金|土|日)曜日, (next )?monday..sunday ---
  if (date == null) {
    void applyWeekday(RegExpMatch m, List<String> order, String letter, bool nextWeek) {
      final target = order.indexOf(letter) + 1; // 1=Mon..7=Sun
      date = _nextWeekday(dateOnly(now), target, forceNextWeek: nextWeek);
      text = strip(m);
    }

    const koOrder = ['월', '화', '수', '목', '금', '토', '일'];
    const jaOrder = ['月', '火', '水', '木', '金', '土', '日'];
    const enOrder = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    final koWeekday = RegExp(r'(다음\s?주\s?)?(월|화|수|목|금|토|일)요일').firstMatch(text);
    final jaWeekday = RegExp(r'(来週\s?)?(月|火|水|木|金|土|日)曜日').firstMatch(text);
    final enWeekday = RegExp(
      r'(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
      caseSensitive: false,
    ).firstMatch(text);

    if (koWeekday != null) {
      applyWeekday(koWeekday, koOrder, koWeekday.group(2)!, koWeekday.group(1) != null);
    } else if (jaWeekday != null) {
      applyWeekday(jaWeekday, jaOrder, jaWeekday.group(2)!, jaWeekday.group(1) != null);
    } else if (enWeekday != null) {
      applyWeekday(
        enWeekday,
        enOrder,
        enWeekday.group(2)!.toLowerCase(),
        enWeekday.group(1) != null,
      );
    }
  }

  // --- Explicit date: N월 N일 / N月N日, English month name + day
  // ("March 15", "Mar 15th") ---
  if (date == null) {
    DateTime resolveExplicitDate(int month, int day) {
      final thisYear = DateTime(now.year, month, day);
      // A month/day that's already passed this year almost certainly means
      // next year, not "create this in the past" — e.g. typing "1월 5일" in
      // December means next January, not three days after the year already
      // ended. Compared by date only (dateOnly(now)), so typing today's own
      // month/day still resolves to today, not a year out.
      return thisYear.isBefore(dateOnly(now))
          ? DateTime(now.year + 1, month, day)
          : thisYear;
    }

    // Korean 월/일 and Japanese 月/日 share the same "number, month marker,
    // number, day marker" shape, so one pattern covers both.
    final koJaExplicit = RegExp(
      r'(\d{1,2})[월月]\s*(\d{1,2})[일日]',
    ).firstMatch(text);
    if (koJaExplicit != null) {
      final month = int.parse(koJaExplicit.group(1)!);
      final day = int.parse(koJaExplicit.group(2)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        date = resolveExplicitDate(month, day);
        text = strip(koJaExplicit);
      }
    }

    if (date == null) {
      final enExplicit = RegExp(
        r'\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
        r'jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|'
        r'dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (enExplicit != null) {
        final month = _englishMonths[enExplicit.group(1)!.toLowerCase()]!;
        final day = int.parse(enExplicit.group(2)!);
        if (day >= 1 && day <= 31) {
          date = resolveExplicitDate(month, day);
          text = strip(enExplicit);
        }
      }
    }
  }

  // --- Time: 정오/자정/正午/真夜中/noon/midnight ---
  final namedTime = RegExp(
    r'(정오|자정|noon|midnight|正午|真夜中)',
    caseSensitive: false,
  ).firstMatch(text);
  if (namedTime != null) {
    final word = namedTime.group(0)!.toLowerCase();
    time = (word == '정오' || word == 'noon' || word == '正午')
        ? const TimeOfDay(hour: 12, minute: 0)
        : const TimeOfDay(hour: 0, minute: 0);
    text = strip(namedTime);
  }

  // --- Time: (오전|오후|아침|저녁|밤) N시(반|N분)?,
  // (午前|午後|朝|夜|晩) N時(半|N分)? ---
  if (time == null) {
    // (?!간|間) so "시"/"時" isn't matched as an hour marker when it's
    // actually the start of "시간"/"時間" (a duration word, "N hours") —
    // e.g. "오후 3시간 후" ("in 3 hours, PM-ish phrasing") must not be read
    // as 3:00 PM, same trap in Japanese with "時間".
    final koJaTime = RegExp(
      r'(오전|오후|아침|저녁|밤|午前|午後|朝|夜|晩)\s?(\d{1,2})[시時](?!간|間)'
      r'\s?(반|半|\d{1,2}[분分])?',
    ).firstMatch(text);
    if (koJaTime != null) {
      final marker = koJaTime.group(1)!;
      final isPm =
          marker == '오후' ||
          marker == '저녁' ||
          marker == '밤' ||
          marker == '午後' ||
          marker == '夜' ||
          marker == '晩';
      var hour = int.parse(koJaTime.group(2)!) % 12;
      if (isPm) hour += 12;
      final minutePart = koJaTime.group(3);
      final minute = minutePart == null
          ? 0
          : (minutePart == '반' || minutePart == '半'
                ? 30
                : int.parse(minutePart.replaceAll(RegExp('[분分]'), '')));
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute < 60) {
        time = TimeOfDay(hour: hour, minute: minute);
        text = strip(koJaTime);
      }
    }
  }

  // --- Time: 24-hour bare "N시"/"N時" where N >= 13 (unambiguous) ---
  if (time == null) {
    // (?!간|間) — see the comment on the koJaTime regex above: without it,
    // "18시간"/"18時間" ("18 hours", a duration) would misparse as 18:00.
    final h24 = RegExp(
      r'(\d{1,2})[시時](?!간|間)\s?(\d{1,2}[분分])?',
    ).firstMatch(text);
    if (h24 != null) {
      final hour = int.parse(h24.group(1)!);
      if (hour >= 13 && hour <= 23) {
        final minutePart = h24.group(2);
        final minute = minutePart == null
            ? 0
            : int.parse(minutePart.replaceAll(RegExp('[분分]'), ''));
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

  // --- Priority: !낮음/!low/!低, !보통/!medium/!中, !높음/!high/!高 ---
  int? priority;
  final priorityMatch = RegExp(
    r'!(낮음|보통|높음|low|medium|high|低|中|高)',
    caseSensitive: false,
  ).firstMatch(text);
  if (priorityMatch != null) {
    final word = priorityMatch.group(1)!.toLowerCase();
    priority = switch (word) {
      '낮음' || 'low' || '低' => 1,
      '보통' || 'medium' || '中' => 2,
      '높음' || 'high' || '高' => 3,
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
    return addCalendarDays(from, delta);
  }
  final thisWeekStart = addCalendarDays(
    from,
    -((from.weekday - DateTime.monday) % 7),
  );
  final nextWeekStart = addCalendarDays(thisWeekStart, 7);
  return addCalendarDays(nextWeekStart, targetWeekday - DateTime.monday);
}
