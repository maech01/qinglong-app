import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/virtual_log_view.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:share_plus/share_plus.dart';

import '../../../base/cupertino_sheet.dart';
import '../../../main.dart';
import '../../home/system_bean.dart';

class InTimeHistoryLogPage extends StatefulWidget {
  final String title;

  /// 主路径（向后兼容）。优先使用 [paths] 中的候选。
  final String path;

  /// 多个目录候选，按可信度排序。尝试直到某个返回非空内容为止。
  final List<String>? paths;

  const InTimeHistoryLogPage({
    Key? key,
    required this.title,
    this.path = "",
    this.paths,
  }) : super(key: key);

  @override
  _InTimeHistoryLogPageState createState() => _InTimeHistoryLogPageState();
}

class _InTimeHistoryLogPageState extends State<InTimeHistoryLogPage> with LazyLoadState<InTimeHistoryLogPage> {
  String? content;

  /// 实际返回内容的目录，用于后续删除等操作。
  String? _resolvedPath;

  bool isRequest = false;
  bool canRequest = true;

  /// 所有要尝试的目录候选，去重后按优先级排序。
  List<String> get _candidates {
    final List<String> out = <String>[];
    void add(String? value) {
      if (value == null) return;
      final String v = value.trim();
      if (out.contains(v)) return;
      out.add(v);
    }

    for (final String p in widget.paths ?? const <String>[]) {
      add(p);
    }
    add(widget.path);
    if (out.isEmpty) out.add("");
    return out;
  }

  getLogData() async {
    HttpResponse<String>? last;
    for (final String candidate in _candidates) {
      final HttpResponse<String> response =
          await SingleAccountPageState.ofApi(context).taskLogDetail(widget.title, candidate);
      last = response;
      // 服务端对不存在的路径可能返回 200 但空 body，把空内容当作“继续找下一个候选”。
      if (response.success && (response.bean?.isNotEmpty ?? false)) {
        _resolvedPath = candidate;
        content = response.bean;
        if (mounted) setState(() {});
        return;
      }
    }

    if (last != null && last.success) {
      _resolvedPath = _candidates.last;
      content = last.bean ?? "";
      if (mounted) setState(() {});
      return;
    }
    if (mounted) last?.message?.toast();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QlAppBar(
        canBack: true,
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () {
              showMoreOperate(
                context,
                [
                  CupertinoSheer(
                    title: "分享",
                    onTap: () async {
                      Share.share(content ?? "");
                    },
                  ),
                  addDivider(),
                  CupertinoSheer(
                    title: "删除",
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      deleteFold(widget.title, _resolvedPath ?? widget.path);
                    },
                  ),
                ],
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Center(
                child: Icon(
                  Icons.more_horiz,
                  size: 26,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                ),
              ),
            )
          )
        ],
        title: widget.title,
      ),
      body: SafeArea(
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.only(
            bottom: 10,
          ),
          child: (content == null)
              ? const Center(
                  child: LoadingWidget(),
                )
              : VirtualLogView(content: content!),
        ),
      ),
    );
  }

  @override
  void onLazyLoad() {
    getLogData();
  }

  void deleteFold(String title, String path) async {
    SystemBean? systemBean;

    try {
      systemBean = getIt<SystemBean>(instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString());
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }
    if (!systemBean.isUpperVersion2_14_5()) {
      "该功能仅支持v2.14.5及以上版本".toast();
      return;
    }

    EasyLoading.show(status: "删除中...");
    var temp = await SingleAccountPageState.ofApi(context).deleteLog(title, path);
    EasyLoading.dismiss();
    if (temp.success) {
      "已删除".toast();
      Navigator.of(context).pop(true);
    } else {
      temp.message.toast();
    }
  }
}
