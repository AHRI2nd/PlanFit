import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/quick_add/quick_add_parser.dart';

void main() {
  // A Wednesday, so weekday-math tests have an unambiguous anchor.
  final now = DateTime(2026, 3, 4);

  group('relative day', () {
    test('오늘/내일/모레', () {
      expect(parseQuickAdd('오늘 회의', now: now).date, DateTime(2026, 3, 4));
      expect(parseQuickAdd('내일 회의', now: now).date, DateTime(2026, 3, 5));
      expect(parseQuickAdd('모레 회의', now: now).date, DateTime(2026, 3, 6));
    });

    test('today/tomorrow', () {
      expect(
        parseQuickAdd('today meeting', now: now).date,
        DateTime(2026, 3, 4),
      );
      expect(
        parseQuickAdd('tomorrow meeting', now: now).date,
        DateTime(2026, 3, 5),
      );
    });

    test('strips the matched word out of the title', () {
      final r = parseQuickAdd('내일 회의', now: now);
      expect(r.title, '회의');
    });
  });

  group('weekday', () {
    test('bare weekday resolves to the closest one on/after today', () {
      // now = Wed 2026-03-04. Friday is 2 days out.
      expect(parseQuickAdd('금요일 회의', now: now).date, DateTime(2026, 3, 6));
      // Wednesday itself resolves to today.
      expect(parseQuickAdd('수요일 회의', now: now).date, DateTime(2026, 3, 4));
    });

    test('다음주 prefix always skips to next week, even for today\'s '
        'weekday', () {
      expect(parseQuickAdd('다음주 수요일 회의', now: now).date, DateTime(2026, 3, 11));
      expect(
        parseQuickAdd('다음 주 화요일 회의', now: now).date,
        DateTime(2026, 3, 10),
      );
    });

    test('english weekday, with and without "next"', () {
      expect(
        parseQuickAdd('friday standup', now: now).date,
        DateTime(2026, 3, 6),
      );
      expect(
        parseQuickAdd('next wednesday standup', now: now).date,
        DateTime(2026, 3, 11),
      );
    });
  });

  group('explicit date', () {
    test('N월 N일', () {
      final r = parseQuickAdd('3월 15일 생일파티', now: now);
      expect(r.date, DateTime(2026, 3, 15));
      expect(r.title, '생일파티');
    });

    test('a month/day already passed this year rolls to next year', () {
      // now is 2026-03-04 — "1월 5일" (Jan 5) already happened this year.
      final r = parseQuickAdd('1월 5일 회의', now: now);
      expect(r.date, DateTime(2027, 1, 5));
    });

    test('a month/day still ahead this year stays in this year', () {
      final r = parseQuickAdd('12월 25일 회의', now: now);
      expect(r.date, DateTime(2026, 12, 25));
    });

    test("today's own month/day resolves to today, not a year out", () {
      final r = parseQuickAdd('3월 4일 회의', now: now);
      expect(r.date, DateTime(2026, 3, 4));
    });
  });

  group('time', () {
    test('오전/오후 N시 is unambiguous', () {
      expect(
        parseQuickAdd('오후 3시 회의', now: now).time,
        const TimeOfDay(hour: 15, minute: 0),
      );
      expect(
        parseQuickAdd('오전 9시 회의', now: now).time,
        const TimeOfDay(hour: 9, minute: 0),
      );
      // 오후 12시 stays noon, not 24:00.
      expect(
        parseQuickAdd('오후 12시 회의', now: now).time,
        const TimeOfDay(hour: 12, minute: 0),
      );
    });

    test('저녁/밤 map to PM, 아침 to AM', () {
      expect(
        parseQuickAdd('저녁 7시 약속', now: now).time,
        const TimeOfDay(hour: 19, minute: 0),
      );
      expect(
        parseQuickAdd('밤 11시 통화', now: now).time,
        const TimeOfDay(hour: 23, minute: 0),
      );
      expect(
        parseQuickAdd('아침 7시 운동', now: now).time,
        const TimeOfDay(hour: 7, minute: 0),
      );
    });

    test('minutes: 반 and N분', () {
      expect(
        parseQuickAdd('오후 3시 반 회의', now: now).time,
        const TimeOfDay(hour: 15, minute: 30),
      );
      expect(
        parseQuickAdd('오전 9시 15분 회의', now: now).time,
        const TimeOfDay(hour: 9, minute: 15),
      );
    });

    test('24-hour bare hour >= 13 is unambiguous', () {
      expect(
        parseQuickAdd('15시 회의', now: now).time,
        const TimeOfDay(hour: 15, minute: 0),
      );
    });

    test('a bare small hour with no marker is left ambiguous (null)', () {
      expect(parseQuickAdd('3시 회의', now: now).time, isNull);
      // The digits stay in the title since nothing was confidently matched.
      expect(parseQuickAdd('3시 회의', now: now).title, '3시 회의');
    });

    test('"N시간" (a duration word, not a clock time) is never mistaken for an '
        'hour, even when N is in the unambiguous 13-23 range', () {
      final r = parseQuickAdd('18시간 후에 통화', now: now);
      expect(r.time, isNull);
      expect(r.title, '18시간 후에 통화');
    });

    test('"오후 3시간 후" (PM-looking prefix, still a duration word) is left '
        'unparsed too', () {
      final r = parseQuickAdd('오후 3시간 후 통화', now: now);
      expect(r.time, isNull);
    });

    test('정오/자정/noon/midnight', () {
      expect(
        parseQuickAdd('정오 점심', now: now).time,
        const TimeOfDay(hour: 12, minute: 0),
      );
      expect(
        parseQuickAdd('자정 마감', now: now).time,
        const TimeOfDay(hour: 0, minute: 0),
      );
      expect(
        parseQuickAdd('noon lunch', now: now).time,
        const TimeOfDay(hour: 12, minute: 0),
      );
    });

    test('english Npm / N:MMam', () {
      expect(
        parseQuickAdd('3pm meeting', now: now).time,
        const TimeOfDay(hour: 15, minute: 0),
      );
      expect(
        parseQuickAdd('9:30am standup', now: now).time,
        const TimeOfDay(hour: 9, minute: 30),
      );
    });
  });

  group('tags', () {
    test('a single #tag is extracted and stripped from the title', () {
      final r = parseQuickAdd('회의 준비 #업무', now: now);
      expect(r.tags, ['업무']);
      expect(r.title, '회의 준비');
    });

    test('multiple #tags are all collected, in order', () {
      final r = parseQuickAdd('#업무 #급함 회의 준비', now: now);
      expect(r.tags, ['업무', '급함']);
      expect(r.title, '회의 준비');
    });

    test('no tags yields an empty (not null) list and an untouched title', () {
      final r = parseQuickAdd('회의 준비', now: now);
      expect(r.tags, isEmpty);
      expect(r.title, '회의 준비');
    });

    test(
      'a tag containing a date word is kept intact and does not set a date',
      () {
        final r = parseQuickAdd('#내일신문 읽기', now: now);
        expect(r.tags, ['내일신문']);
        expect(r.date, isNull);
        expect(r.title, '읽기');
      },
    );

    test('a tag containing a weekday word is kept intact and does not set a '
        'date', () {
      final r = parseQuickAdd('#월요일아침루틴 하기', now: now);
      expect(r.tags, ['월요일아침루틴']);
      expect(r.date, isNull);
    });
  });

  group('priority', () {
    test('!high / !높음 map to 3', () {
      expect(parseQuickAdd('보고서 !high', now: now).priority, 3);
      expect(parseQuickAdd('보고서 !높음', now: now).priority, 3);
    });

    test('!medium / !보통 map to 2, !low / !낮음 map to 1', () {
      expect(parseQuickAdd('보고서 !medium', now: now).priority, 2);
      expect(parseQuickAdd('보고서 !보통', now: now).priority, 2);
      expect(parseQuickAdd('보고서 !low', now: now).priority, 1);
      expect(parseQuickAdd('보고서 !낮음', now: now).priority, 1);
    });

    test('the priority token is stripped from the title', () {
      expect(parseQuickAdd('보고서 작성 !높음', now: now).title, '보고서 작성');
    });

    test('no priority token leaves priority null', () {
      expect(parseQuickAdd('그냥 할 일', now: now).priority, isNull);
    });
  });

  group('combined date + time + title', () {
    test('내일 오후 3시 회의 resolves all three and leaves a clean title', () {
      final r = parseQuickAdd('내일 오후 3시 회의', now: now);
      expect(r.date, DateTime(2026, 3, 5));
      expect(r.time, const TimeOfDay(hour: 15, minute: 0));
      expect(r.title, '회의');
    });

    test(
      'an input with no recognizable phrase returns the title unchanged',
      () {
        final r = parseQuickAdd('그냥 할 일', now: now);
        expect(r.date, isNull);
        expect(r.time, isNull);
        expect(r.title, '그냥 할 일');
      },
    );

    test('date + time + tag + priority all resolve together, clean title', () {
      final r = parseQuickAdd('내일 오후 3시 회의 #업무 !높음', now: now);
      expect(r.date, DateTime(2026, 3, 5));
      expect(r.time, const TimeOfDay(hour: 15, minute: 0));
      expect(r.tags, ['업무']);
      expect(r.priority, 3);
      expect(r.title, '회의');
    });
  });
}
