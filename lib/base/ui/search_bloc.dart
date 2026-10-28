// 搜索BLoC - 支持防抖和高效状态管理
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/ui/search_engine.dart';

// 搜索事件
abstract class SearchEvent {}

class SearchTextChanged extends SearchEvent {
  final String query;
  SearchTextChanged(this.query);
}

class SearchSubmitted extends SearchEvent {
  final String query;
  SearchSubmitted(this.query);
}

class SearchClear extends SearchEvent {}

class SearchLoadMore extends SearchEvent {}

// 搜索状态
abstract class SearchState {}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchSuccess extends SearchState {
  final List<SearchResult<dynamic>> results;
  final bool hasMore;
  SearchSuccess(this.results, {this.hasMore = false});
}

class SearchFailure extends SearchState {
  final String error;
  SearchFailure(this.error);
}

class SearchEmpty extends SearchState {}

// 搜索BLoC
class SearchBloc extends StateNotifier<SearchState> {
  final SmartSearchEngine _searchEngine = SmartSearchEngine();
  final SearchQueryManager _queryManager;
  
  SearchBloc({SearchQueryManager? queryManager}) 
      : _queryManager = queryManager ?? SearchQueryManager(),
        super(SearchInitial());
  
  // 防抖搜索控制器
  StreamSubscription<String>? _searchSubscription;
  final StreamController<SearchEvent> _eventController = StreamController.broadcast();
  
  // 搜索结果缓存
  final Map<String, List<SearchResult<dynamic>>> _searchCache = {};
  final List<SearchResult<dynamic>> _allResults = [];
  
  // 当前查询
  String _currentQuery = '';
  int _page = 1;
  bool _isLoading = false;
  
  // 初始化搜索数据
  void loadAllResults(List<SearchResult<dynamic>> results) {
    _allResults.clear();
    _allResults.addAll(results);
    _clearCache();
    _performSearch(_currentQuery);
  }
  
  // 设置搜索订阅
  void setSearchSubscription(Stream<String> queryStream) {
    _searchSubscription?.cancel();
    _searchSubscription = _queryManager.debounceSearch(
      StreamController.broadcast(),
      queryStream,
    ).listen((query) {
      _performSearch(query);
    });
  }
  
  // 执行搜索
  void _performSearch(String query) {
    if (!_isLoading) {
      _isLoading = true;
      state = SearchLoading();
      
      // 防重复搜索
      if (_currentQuery == query && _searchCache.containsKey(query)) {
        state = SearchSuccess(_searchCache[query]!);
        _isLoading = false;
        return;
      }
      
      _currentQuery = query;
      
      // 智能搜索
      final searchResults = _searchEngine.performFuzzySearch(
        _allResults,
        query,
        titleGetter: (result) => result.title,
        contentGetter: (result) => result.content ?? '',
        descriptionGetter: (result) => result.description ?? '',
      );
      // 缓存结果
      if (query.isNotEmpty) {
        _searchCache[query] = searchResults;
      }
      
      // 更新状态
      if (searchResults.isEmpty && query.isNotEmpty) {
        state = SearchEmpty();
      } else {
        state = SearchSuccess(searchResults);
      }
      
      _isLoading = false;
    }
  }
  
  // 清除搜索
  void clearSearch() {
    _currentQuery = '';
    _clearCache();
    state = SearchInitial();
  }
  
  // 加载更多
  void loadMore() {
    if (_isLoading) return;
    _searchCache.clear(); // 清除缓存以强制重新搜索
    _performSearch(_currentQuery);
  }
  
  // 清除缓存
  void _clearCache() {
    _searchCache.clear();
    _page = 1;
  }
  
  // 错误处理
  void handleError(String error) {
    state = SearchFailure(error);
    _isLoading = false;
  }
  
  // 销毁
  void dispose() {
    _searchSubscription?.cancel();
    _eventController.close();
  }
}

// 搜索提供者
final searchBlocProvider = StateNotifierProvider.family<SearchBloc, SearchState>((
  ref, List<SearchResult<dynamic>> allResults,
) {
  final bloc = SearchBloc();
  bloc.loadAllResults(allResults);
  return bloc;
});