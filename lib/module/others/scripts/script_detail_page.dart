import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/cupertino_sheet.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/module/task/add_task_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:path/path.dart' as p;
import 'package:qinglong_app/utils/icloud_utils.dart';
import 'package:share_plus/share_plus.dart';

import '../../../main.dart';
import '../../code_editor/codemirror/io.dart';
import '../../code_editor/editor.dart';
import '../../config/config_detail_page.dart';
import '../../home/system_bean.dart';
import 'script_upload_page.dart';

class ScriptDetailPage extends ConsumerStatefulWidget {
  final String title;
  final String? path;

  /// Candidate directories (most trustworthy first) used to locate the file.
  final List<String>? paths;

  const ScriptDetailPage({
    Key? key,
    required this.title,
    this.path,
    this.paths,
  }) : super(key: key);

  @override
  _ScriptDetailPageState createState() => _ScriptDetailPageState();
}

class _ScriptDetailPageState extends ConsumerState<ScriptDetailPage> with LazyLoadState<ScriptDetailPage> {
  String? content;

  /// Directory that actually yielded the file, used for follow-up actions
  /// (add-to-task, delete) so they don't repeat the original path mistake.
  String? _resolvedPath;

  String get _effectivePath => _resolvedPath ?? widget.path ?? "";

  List<Widget> actions = [];

  late CodeMirrorOptions options;
  EditorController? controller;

  getLanguageType(String title) {
    if (title.endsWith(".js")) {
      return 'javascript';
    }

    if (title.endsWith(".sh")) {
      return 'shell';
    }

    if (title.endsWith(".py")) {
      return 'python';
    }
    if (title.endsWith(".json")) {
      return 'shell';
    }
    if (title.endsWith(".yaml")) {
      return 'yaml';
    }
    return "shell";
  }

  @override
  void initState() {
    options = CodeMirrorOptions(
      readOnly: true,
      mode: getLanguageType(widget.title),
    );
    super.initState();
    actions.addAll(
      [
        CupertinoSheer(
          title: "添加到任务",
          onTap: () {
            if (content == null || content!.isEmpty) {
              "未获取到脚本内容,请稍候重试".toast();
              return;
            }
            String command = "task ${_effectivePath}${_effectivePath.isNotEmpty ? p.separator : ""}${widget.title} ";
            String? cron = ScriptUploadPageState.getCronString(content!, widget.title);

            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => AddTaskPage(
                  taskBean: TaskBean(
                    name: widget.title,
                    command: command,
                    schedule: cron,
                  ),
                  hideUploadFile: true,
                ),
              ),
            );
          },
        ),
        addDivider(),
        CupertinoSheer(
          title: "编辑",
          onTap: () {
            if (content == null || content!.isEmpty) {
              "未获取到脚本内容,请稍候重试".toast();
              return;
            }
            Navigator.of(context).pushNamed(
              Routes.routeScriptUpdate,
              arguments: {
                "title": widget.title,
                "path": _effectivePath,
                "content": content,
                "paths": _candidates,
              },
            ).then((value) {
              if (value != null) {
                content = value.toString();
                controller?.setValue(content ?? "");
                setState(() {});
              }
            });
          },
        ),
        addDivider(),
        CupertinoSheer(
          title: "分享",
          onTap: () {
            Share.share(content ?? "");
          },
        ),
        addDivider(),
        CupertinoSheer(
          title: "下载",
          onTap: () async {
            try {
              String name = "${Random().nextInt(40000)}_${widget.title}";
              var file = await FileUtil(0).writeDownloadFile(name, content ?? "");
              "已写入qinglong_app文件夹下,文件名$name".toast2();
            } catch (e) {
              e.toString().toast();
            }
          },
        ),
        addDivider(),
        CupertinoSheer(
          title: "删除",
          onTap: () async {
            HapticFeedback.mediumImpact();
            showCupertinoDialog(
              useRootNavigator: false,
              context: context,
              builder: (context1) => CupertinoAlertDialog(
                title: const Text("确认删除"),
                content: const Text("确认删除该脚本吗"),
                actions: [
                  CupertinoDialogAction(
                    child: const Text(
                      "取消",
                      style: TextStyle(
                        color: Color(0xff999999),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  CupertinoDialogAction(
                    child: Text(
                      "确定",
                      style: TextStyle(
                        color: ref.watch(themeProvider).primaryColor,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(context1).pop();
                      SystemBean? systemBean;

                      try {
                        systemBean = getIt<SystemBean>(instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString());
                      } catch (e) {
                        systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
                      }
                      HttpResponse<NullResponse> result;
                      String deletePath = _effectivePath.isNotEmpty ? _effectivePath : (widget.path ?? "");
                      if (systemBean.isUpperVersion2_14_5()) {
                        result = await SingleAccountPageState.ofApi(context).delScriptNewVersion(widget.title, deletePath);
                      } else {
                        result = await SingleAccountPageState.ofApi(context).delScript(widget.title, deletePath);
                      }
                      if (result.success) {
                        "删除成功".toast();
                        Navigator.of(context).pop(true);
                      } else {
                        result.message?.toast();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    EasyLoading.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ref.watch(themeProvider).themeColor.codeBgColor(),
      appBar: QlAppBar(
        canBack: true,
        backCall: () {
          Navigator.of(context).pop();
        },
        title: widget.title,
        actions: [
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () async {
              codeKey.currentState?.showSearchBar();
            },
            child: Padding(
              padding: const EdgeInsets.only(
                left: 15,
              ),
              child: Center(
                child: Icon(
                  Icons.search,
                  color: Theme.of(context).appBarTheme.iconTheme?.color,
                  size: 22,
                ),
              ),
            ),
          ),
          CupertinoButton(
            color: Colors.transparent,
            padding: EdgeInsets.zero,
            onPressed: () async {
              await hideKeyboardFocus();
              showMoreOperate(context, actions);
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
            ),
          ),
        ],
      ),
      body: content == null
          ? const Center(
              child: LoadingWidget(),
            )
          : SafeArea(
              top: false,
              child: Editor(
                options: options,
                codeMirrorKey: codeKey,
                onCreate: (val) {
                  controller = val;
                  controller?.setOptions(options);
                  controller?.setValue(content ?? "");
                },
                onValue: (val) {},
              ),
            ),
    );
  }

  GlobalKey<CodeMirrorViewState> codeKey = GlobalKey();

  /// Candidate directories, deduplicated and ordered by trustworthiness.
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

  Future<void> loadData() async {
    HttpResponse<String>? last;
    for (final String candidate in _candidates) {
      final HttpResponse<String> response =
          await SingleAccountPageState.ofApi(context).scriptDetail(widget.title, candidate);
      last = response;
      // The panel answers 200 with an empty body for a path that does not
      // exist (getFileContentByName swallows ENOENT), so empty content means
      // "keep looking" rather than "done".
      if (response.success && (response.bean?.isNotEmpty ?? false)) {
        _resolvedPath = candidate;
        content = response.bean;
        setState(() {});
        return;
      }
    }

    if (last != null && last.success) {
      _resolvedPath = _candidates.last;
      content = last.bean ?? "";
      setState(() {});
      return;
    }
    last?.message?.toast();
    setState(() {
      content = "";
    });
  }

  @override
  void onLazyLoad() {
    loadData();
  }
}
