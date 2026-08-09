import '../../../core/db/app_database.dart';

/// Whether [todo] carries [tag] as one of its comma-separated
/// `TodoItems.tags` segments — exact segment match, not a substring, so tag
/// "업무" doesn't also match a to-do tagged "영업무". Shared by
/// `TodoDao.watchByTag` and the search screen's tag filter so the definition
/// can't drift between the two.
bool todoHasTag(TodoRow todo, String tag) =>
    (todo.tags ?? '').split(',').map((t) => t.trim()).contains(tag);
