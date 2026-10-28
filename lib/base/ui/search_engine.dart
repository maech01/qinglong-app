// 优化搜索引擎 - 支持中英文混合搜索的高效实现
import 'dart:math';
import 'package:collection/collection.dart';

/// 智能搜索引擎，支持中英文混合搜索
class SmartSearchEngine {
  /// 中英文混合关键词分割
  static List<String> splitChineseAndEnglish(String text) {
    if (text.isEmpty) return [];
    
    final RegExp chinesePattern = RegExp(r'[\u4e00-\u9fff]+');
    final RegExp englishPattern = RegExp(r'[a-zA-Z0-9]+');
    
    final List<String> keywords = [];
    
    // 提取中文
    final chineseMatches = chinesePattern.allMatches(text);
    for (final match in chineseMatches) {
      keywords.add(match.group(0)!);
    }
    
    // 提取英文/数字
    final englishMatches = englishPattern.allMatches(text);
    for (final match in englishMatches) {
      keywords.add(match.group(0)!);
    }
    
    return keywords;
  }
  
  /// 高效搜索算法，基于评分系统
  static List<T> performSmartSearch<T>(List<T> allItems, String query, {
    required String Function(T) titleGetter,
    required String Function(T) contentGetter,
    required String Function(T) descriptionGetter,
    required double Function(String) calculateScore,
  }) {
    if (query.isEmpty) return allItems;
    
    final keywords = splitChineseAndEnglish(query);
    if (keywords.isEmpty) return [];
    
    // 使用Map提高查找效率
    final Map<T, double> scoreMap = {};
    
    for (final keyword in keywords) {
      final lowerKeyword = keyword.toLowerCase();
      
      for (final item in allItems) {
        if (scoreMap.containsKey(item)) continue; // 避免重复处理
        
        final title = titleGetter(item).toLowerCase();
        final content = contentGetter(item).toLowerCase();
        final description = descriptionGetter(item).toLowerCase();
        
        final score = calculateScore(lowerKeyword, title, content, description);
        
        if (score > 0) {
          scoreMap[item] = (scoreMap[item] ?? 0) + score;
        }
      }
    }
    
    // 按评分排序
    final sortedItems = scoreMap.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .map((e) => e.key)
        .toList();
    
    return sortedItems;
  }
  
  /// 计算关键词匹配评分
  static double calculateMatchScore(String keyword, String title, String content, String description) {
    double score = 0.0;
    
    // 标题完全匹配加分
    if (title == keyword) {
      score += 100.0;
    }
    // 标题开头匹配
    else if (title.startsWith(keyword)) {
      score += 50.0;
    }
    // 标题包含
    else if (title.contains(keyword)) {
      score += 20.0;
    }
    
    // 内容匹配
    if (content.contains(keyword)) {
      score += 10.0;
    }
    
    // 描述匹配
    if (description.contains(keyword)) {
      score += 5.0;
    }
    
    // 中文关键词完整匹配加分
    if (keyword.length >= 2 && 
        (title.contains(keyword) || content.contains(keyword) || description.contains(keyword))) {
      score += 15.0;
    }
    
    return score;
  }
  
  /// 模糊搜索 - 用于宽松匹配
  static List<T> performFuzzySearch<T>(List<T> allItems, String query, {
    required String Function(T) titleGetter,
    required String Function(T) contentGetter,
    required String Function(T) descriptionGetter,
  }) {
    if (query.isEmpty) return allItems;
    
    final normalizedQuery = query.toLowerCase().trim();
    final searchWords = splitChineseAndEnglish(normalizedQuery);
    
    return allItems.where((item) {
      final title = titleGetter(item).toLowerCase();
      final content = contentGetter(item).toLowerCase();
      final description = descriptionGetter(item).toLowerCase();
      
      return searchWords.any((word) {
        return title.contains(word) || 
               content.contains(word) || 
               description.contains(word);
      });
    }).toList();
  }
}

/// 搜索结果项模型
class SearchResult<T> {
  final T item;
  final double score;
  final String matchType; // exact, prefix, contains
  
  SearchResult({
    required this.item,
    required this.score,
    required this.matchType,
  });
}

/// 搜索查询管理器
class SearchQueryManager {
  final Duration debounceDuration;
  final int minQueryLength;
  
  SearchQueryManager({
    this.debounceDuration = const Duration(milliseconds: 300),
    this.minQueryLength = 1,
  });
  
  Stream<T> debounceSearch<T>(StreamController<T> controller, Stream<String> queryStream) {
    return queryStream
        .debounceTime(debounceDuration)
        .where((query) => query.length >= minQueryLength)
        .asyncMap((query) async {
          // 执行异步搜索操作
          return await _performSearch(query);
        })
        .distinct()
        .listen(controller.add)
        .asBroadcast();
  }
  
  Future<T> _performSearch<T>(String query) async {
    // 实际的搜索实现
    throw UnimplementedError();
  }
}