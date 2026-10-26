import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/search/search_options.dart';

enum SearchResultType { all, events, todos }

class SearchMemory {
  const SearchMemory({
    this.options = const SearchOptions(),
    this.type = SearchResultType.all,
  });
  final SearchOptions options;
  final SearchResultType type;
}

class SearchMemoryController extends Notifier<SearchMemory> {
  @override
  SearchMemory build() => const SearchMemory();
  void save(SearchMemory value) => state = value;
}

final searchMemoryProvider =
    NotifierProvider<SearchMemoryController, SearchMemory>(
      SearchMemoryController.new,
    );
