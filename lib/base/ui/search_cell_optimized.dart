// 优化搜索输入框 - 支持中文语音输入和智能提示
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';

class OptimizedSearchCell extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String? hintText;
  final bool autoFocus;

  const OptimizedSearchCell({
    Key? key,
    required this.controller,
    this.onSearchChanged,
    this.onSubmitted,
    this.onClear,
    this.hintText,
    this.autoFocus = false,
  }) : super(key: key);

  @override
  ConsumerState createState() => _OptimizedSearchCellState();
}

class _OptimizedSearchCellState extends ConsumerState<OptimizedSearchCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;
  bool _isComposing = false;
  Timer? _debounceTimer;
  bool _lastEmpty = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _focusNode = FocusNode()
      ..addListener(_onFocusChanged)
      ..canRequestFocus = widget.autoFocus;

    // 监听文本变化，防抖处理
    _controller.addListener(_onTextChanged);

    // 自动聚焦
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _onTextChanged() {
    // 检测中文输入法组字状态
    final bool isComposing = _controller.value.composing.isValid;
    if (isComposing) {
      _isComposing = true;
      return; // 组字时不触发搜索和 setState
    }

    // 如果之前在组字状态，现在组字完成，触发搜索
    if (_isComposing) {
      _isComposing = false;
    }

    // 防抖处理，避免频繁调用
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        widget.onSearchChanged?.call(_controller.text);
      }
    });

    // 只在空/非空状态变化时才 setState，避免中文组字时频繁重建
    final bool isEmpty = _controller.text.isEmpty;
    if (isEmpty != _lastEmpty) {
      _lastEmpty = isEmpty;
      if (mounted) {
        setState(() {
          _isEditing = !isEmpty;
        });
      }
    }
  }

  void _onFocusChanged() {
    // 只在 mounted 时更新状态
    if (mounted) {
      setState(() {
        _isEditing = _focusNode.hasFocus;
      });
    }
  }

  void _handleClear() {
    // 清除文本时的处理
    _debounceTimer?.cancel();
    _controller.clear();
    widget.onClear?.call();
    // 不请求新 FocusNode，避免不必要的 UI 重建
  }

  void _handleSubmit() {
    _debounceTimer?.cancel();
    widget.onSubmitted?.call(_controller.text.trim());
  }

  void _startVoiceInput() {
    // 语音输入处理
    setState(() {
      _isVoiceInput = true;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: ref.watch(themeProvider).themeColor.pinedAndWhite(),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 搜索图标
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search, color: ref.watch(themeProvider).themeColor.descColor(), size: 20),
          ),

          // 搜索输入框
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _handleSubmit(),
              decoration: InputDecoration(
                hintText: widget.hintText ?? '搜索任务、环境变量...',
                hintStyle: TextStyle(
                  color: ref.watch(themeProvider).themeColor.descColor(),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),

          // 清除按钮
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: _handleClear,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.clear,
                  color: ref.watch(themeProvider).themeColor.descColor(),
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}