import 'package:flutter_test/flutter_test.dart';
import 'package:planfit/core/db/sql_like.dart';

/// [buildLikeSubstringPattern] escapes what SQL `LIKE` would otherwise read
/// as wildcards in the user's own search text. It had no test, which is a
/// poor fit for the one piece of query-building in this app whose whole
/// reason for existing is getting three escape cases right — and where
/// being wrong is silent: a search simply returns too much, or nothing,
/// with no error to notice.
///
/// Pure-function tests rather than DAO round trips: [EventDao.search] and
/// [TodoDao.search] pass the result of this straight to `ColumnFilters.like`
/// with `escapeChar: likeEscapeChar`, so what matters is the pattern string.
void main() {
  test('wraps plain text in wildcards, escaping nothing', () {
    expect(buildLikeSubstringPattern('dentist'), '%dentist%');
  });

  test("escapes % so a user's literal percent isn't a wildcard — the case "
      'that turns "50% off" into a search for "50" followed by anything at '
      'all', () {
    expect(buildLikeSubstringPattern('50% off'), r'%50\% off%');
  });

  test('escapes _ so it matches an underscore rather than any single '
      'character — "under_score" must not also match "understore"', () {
    expect(buildLikeSubstringPattern('under_score'), r'%under\_score%');
  });

  test('escapes the escape character itself, before the wildcards — '
      "otherwise a query ending in a backslash would escape the pattern's "
      'own trailing wildcard instead of matching a literal backslash', () {
    expect(buildLikeSubstringPattern(r'a\b'), r'%a\\b%');
    expect(buildLikeSubstringPattern('\\'), r'%\\%');
  });

  test('a backslash the user typed does not escape a wildcard they typed '
      'next to it — both survive as literals', () {
    // Escaping % first and the backslash second would produce `\\%` here,
    // which reads as "a literal backslash, then any run of characters".
    expect(buildLikeSubstringPattern(r'\%'), r'%\\\%%');
  });

  test('escapes every occurrence, not just the first', () {
    expect(buildLikeSubstringPattern('a%b%c'), r'%a\%b\%c%');
    expect(buildLikeSubstringPattern('a_b_c'), r'%a\_b\_c%');
  });

  test('an empty query is a pattern that matches everything, which is what '
      'an empty search box should show', () {
    expect(buildLikeSubstringPattern(''), '%%');
  });

  test('leaves non-ASCII text alone — Korean titles are the common case '
      'here and contain no LIKE metacharacters', () {
    expect(buildLikeSubstringPattern('치과 예약'), '%치과 예약%');
  });
}
