import 'package:flutter/material.dart';

/// Virtualized, selectable log viewer.
///
/// The original pages rendered an entire log file through a single
/// `ExtendedText` / `SelectableText` inside a `SingleChildScrollView`. A large
/// QingLong log (tens of thousands of lines) forced one gigantic text layout
/// pass on the UI thread, which is why opening history logs froze the app.
///
/// This widget splits the payload into lines once and lets `ListView.builder`
/// lay out only the visible ones, so opening a 20 MB log stays responsive.
///
/// Selection is provided by a single [SelectionArea] around the list instead of
/// one controller per line, which keeps per-frame cost flat.
class VirtualLogView extends StatefulWidget {
  const VirtualLogView({
    super.key,
    required this.content,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    this.maxLines = 300000,
    this.controller,
    this.autoScrollToEnd = false,
  });

  final String content;
  final double fontSize;
  final EdgeInsets padding;

  /// Optional external controller (e.g. so a page can jump to the tail).
  final ScrollController? controller;

  /// Jump to the newest line once the first frame is laid out.
  final bool autoScrollToEnd;

  /// Hard ceiling on rendered lines. Beyond this only the newest lines are
  /// kept (a log's tail is what people actually read) and a notice is shown.
  final int maxLines;

  @override
  State<VirtualLogView> createState() => _VirtualLogViewState();
}

class _VirtualLogViewState extends State<VirtualLogView> {
  late List<String> _lines;
  bool _truncated = false;
  ScrollController? _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _ownsController = widget.controller == null;
    _split();
  }

  void _jumpToEnd() {
    final ScrollController? c = _controller;
    if (c == null || !c.hasClients) return;
    c.jumpTo(c.position.maxScrollExtent);
  }

  @override
  void didUpdateWidget(covariant VirtualLogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.content, widget.content)) {
      _split();
      if (widget.autoScrollToEnd) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      }
    }
  }

  /// 只保留日志尾部这么多字符。更大的文件整段切行会分配上百万个字符串，
  /// 而这些内容没人会从头读。
  static const int _tailChars = 8 * 1024 * 1024;

  void _split() {
    final String raw = widget.content;
    final int max = widget.maxLines;
    bool truncated = false;

    String tail = raw;
    if (raw.length > _tailChars) {
      tail = raw.substring(raw.length - _tailChars);
      truncated = true;
      // 截断点大概率落在行中间，丢掉第一段残行。
      final int nl = tail.indexOf('\n');
      if (nl >= 0 && nl + 1 < tail.length) {
        tail = tail.substring(nl + 1);
      }
    }

    List<String> all = tail.split('\n');
    if (max > 0 && all.length > max) {
      all = all.sublist(all.length - max);
      truncated = true;
    }

    _lines = all;
    _truncated = truncated;

    // Strip a trailing \r so CRLF logs don't render with stray glyphs.
    for (int i = 0; i < _lines.length; i++) {
      final String l = _lines[i];
      if (l.endsWith('\r')) {
        _lines[i] = l.substring(0, l.length - 1);
      }
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: widget.fontSize,
      height: 1.35,
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Roboto Mono', 'DroidSansMono', 'Courier New'],
      color: Theme.of(context).textTheme.bodyMedium?.color,
    );

    if (_lines.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return SelectionArea(
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: ListView.builder(
          controller: _controller,
          padding: widget.padding,
          // A very long log can exceed the default cacheExtent budget; a small
          // fixed extent keeps recycled rows cheap while staying smooth.
          cacheExtent: 1200,
          itemCount: _lines.length + (_truncated ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (_truncated && index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '… 日志过大，仅显示最后 ${_lines.length} 行',
                  style: style.copyWith(
                    fontSize: widget.fontSize,
                    color: Colors.orange,
                  ),
                ),
              );
            }
            final int i = index - (_truncated ? 1 : 0);
            final String line = _lines[i];
            return Text(
              line.isEmpty ? ' ' : line,
              style: style,
              softWrap: true,
            );
          },
        ),
      ),
    );
  }
}
