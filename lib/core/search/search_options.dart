import 'package:drift/drift.dart';
import '../db/sql_like.dart';

/// Date ranges are half-open; UI converts its inclusive last day to next day.
class SearchOptions {
  const SearchOptions({this.from, this.to, this.colorTag, this.priority,
    this.tag, this.includeCompleted = true, this.limit = 100, this.before});
  final DateTime? from;
  final DateTime? to;
  final String? colorTag;
  final int? priority;
  final String? tag;
  final bool includeCompleted;
  final int limit;
  final SearchCursor? before;
  SearchOptions pageAfter(SearchCursor? cursor) => SearchOptions(
    from: from, to: to, colorTag: colorTag, priority: priority, tag: tag,
    includeCompleted: includeCompleted, limit: limit, before: cursor);
}

class SearchCursor {
  const SearchCursor(this.at, this.id);
  final DateTime at;
  final String id;
}

class SearchStatement {
  SearchStatement(String query, SearchOptions options, {required bool events}) {
    final pattern = buildLikeSubstringPattern(query);
    final table = events ? 'events' : 'todo_items';
    final date = events ? 'start_at' : 'slot_start';
    final conditions = <String>[];
    if (events) {
      conditions.add(r"(title LIKE ? ESCAPE '\' OR memo LIKE ? ESCAPE '\' OR location LIKE ? ESCAPE '\')");
      variables.addAll(List.generate(3, (_) => Variable.withString(pattern)));
    } else {
      conditions.add(r"title LIKE ? ESCAPE '\'");
      variables.add(Variable.withString(pattern));
    }
    void condition(String sql, Variable value) {
      conditions.add(sql);
      variables.add(value);
    }
    if (options.from != null) {
      condition(events ? 'end_at > ?' : 'slot_start >= ?',
        Variable.withDateTime(options.from!));
    }
    if (options.to != null) condition('$date < ?', Variable.withDateTime(options.to!));
    if (events && options.colorTag != null) {
      condition('color_tag = ? COLLATE NOCASE', Variable.withString(options.colorTag!));
    }
    if (!events) {
      if (!options.includeCompleted) conditions.add('is_done = 0');
      if (options.priority != null) condition('priority = ?', Variable.withInt(options.priority!));
      if (options.tag != null) {
        condition('''EXISTS (
          WITH RECURSIVE tag_parts(rest, token) AS (
            SELECT coalesce(tags, '') || ',', ''
            UNION ALL
            SELECT substr(rest, instr(rest, ',') + 1),
              trim(substr(rest, 1, instr(rest, ',') - 1))
            FROM tag_parts WHERE rest <> ''
          ) SELECT 1 FROM tag_parts WHERE token = ?
        )''', Variable.withString(options.tag!));
      }
    }
    final cursor = options.before;
    if (cursor != null) {
      conditions.add('($date < ? OR ($date = ? AND id < ?))');
      variables.addAll([Variable.withDateTime(cursor.at),
        Variable.withDateTime(cursor.at), Variable.withString(cursor.id)]);
    }
    variables.add(Variable.withInt(options.limit.clamp(1, 500)));
    sql = 'SELECT * FROM $table WHERE ${conditions.join(' AND ')} '
      'ORDER BY $date DESC, id DESC LIMIT ?';
  }
  late final String sql;
  final List<Variable> variables = [];
}
