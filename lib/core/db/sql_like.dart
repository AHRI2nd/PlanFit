/// Builds a safe `LIKE` substring-match pattern from raw user input.
///
/// `%` and `_` are SQL `LIKE` wildcards (any-run-of-characters and
/// any-single-character respectively) — a search box that hands the user's
/// query straight into a `'%$query%'` pattern silently reinterprets any `%`
/// or `_` *they* typed as a wildcard instead of a literal character. A
/// search for "50% off" would then match "50" followed by literally
/// anything, and "under_score" would match "understore", "underXscore",
/// anything with one character in that slot — both far broader than what
/// the user actually typed, with no indication anything odd happened.
///
/// Escapes both characters (plus the escape character itself, so a query
/// containing a literal backslash doesn't escape whatever follows it) with
/// [likeEscapeChar] before wrapping in `%...%`. Pass [likeEscapeChar] to
/// `ColumnFilters.like`'s own `escapeChar` parameter so the database
/// actually treats it as an escape rather than a literal character to
/// match.
const likeEscapeChar = r'\';

String buildLikeSubstringPattern(String query) {
  final escaped = query
      .replaceAll(likeEscapeChar, '$likeEscapeChar$likeEscapeChar')
      .replaceAll('%', '$likeEscapeChar%')
      .replaceAll('_', '${likeEscapeChar}_');
  return '%$escaped%';
}
