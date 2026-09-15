import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/l10n/app_localizations.dart';

/// Counted strings in the English locale read ungrammatically at one unless
/// the message itself branches on the count. The ARB already used ICU
/// `plural` for some of them (`icsImportSuccess`, `calendarImportSuccess`,
/// `eventRepeatCountTimes`) and plain interpolation for others, so the home
/// screen's week summary said "1 events" every week that held a single
/// event — the most-visited screen in the app.
///
/// These pin the branches. Korean has no plural agreement, so its own
/// wording must stay the same at every count — asserted here too, since the
/// obvious way to "fix" this is to add ICU plurals to both files at once.
void main() {
  final en = lookupAppL10n(const Locale('en'));
  final ko = lookupAppL10n(const Locale('ko'));

  group('homeWeekSummary', () {
    test('one event is singular, and the to-do half agrees with its own '
        'total rather than with the event count', () {
      expect(en.homeWeekSummary(1, 0, 1), '1 event · 0/1 to-do done');
    });

    test('the two halves count independently — one event alongside several '
        'to-dos, and several events alongside one', () {
      expect(en.homeWeekSummary(1, 2, 3), '1 event · 2/3 to-dos done');
      expect(en.homeWeekSummary(3, 0, 1), '3 events · 0/1 to-do done');
    });

    test('zero takes the plural form, which is what English does', () {
      expect(en.homeWeekSummary(0, 0, 0), '0 events · 0/0 to-dos done');
    });

    test('Korean is unchanged at every count', () {
      expect(ko.homeWeekSummary(1, 0, 1), '일정 1개 · 할 일 0/1 완료');
      expect(ko.homeWeekSummary(3, 2, 5), '일정 3개 · 할 일 2/5 완료');
    });
  });

  group('backupImportSuccess', () {
    test('both counts branch, including the mixed case that would expose '
        'only one of them', () {
      expect(en.backupImportSuccess(1, 1), 'Imported 1 event and 1 to-do');
      expect(en.backupImportSuccess(1, 4), 'Imported 1 event and 4 to-dos');
      expect(en.backupImportSuccess(4, 1), 'Imported 4 events and 1 to-do');
      expect(en.backupImportSuccess(0, 0), 'Imported 0 events and 0 to-dos');
    });

    test('Korean is unchanged at every count', () {
      expect(ko.backupImportSuccess(1, 1), '일정 1개, 할 일 1개를 가져왔어요');
    });
  });

  // The neighbouring counted strings that were already correct — kept here
  // so a later sweep through this file doesn't "unify" them into the same
  // plural shape and change wording that is deliberate.
  group('strings that must stay as they are', () {
    test('adjectives and fractions need no agreement at one', () {
      expect(en.homeTodosOverdue(1), '1 overdue');
      expect(en.homeTodosDone(0, 1), '0/1 done');
      expect(en.todoSelectionCount(1), '1 selected');
      expect(en.eventSelectionDeleted(1), 'Deleted 1');
    });

    test('the messages that already used ICU plural still do', () {
      expect(en.icsImportSuccess(1), 'Imported 1 event');
      expect(en.icsImportSuccess(2), 'Imported 2 events');
      expect(en.eventRepeatCountTimes(1), '1 time');
      expect(en.eventRepeatCountTimes(2), '2 times');
    });
  });
}
