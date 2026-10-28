import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/module/others/task_log/task_log_bean.dart';
import 'package:qinglong_app/module/others/task_log/task_log_cache.dart';
import 'package:qinglong_app/module/task/intime_log/intime_history_log_page.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../../main.dart';
import '../../home/system_bean.dart';

class TaskLogPage extends ConsumerStatefulWidget {
  final String? searchText;

  const TaskLogPage({
    Key? key,
    this.searchText,
  }) : super(key: key);

  @override
  _TaskLogPageState createState() => _TaskLogPageState();
}

class _TaskLogPageState extends ConsumerState<TaskLogPage> with LazyLoadState<TaskLogPage> {
  List<TaskLogBean> list = [];

  /// 已展开的目录名，用于只给展开的目录构建子项。
  final Set<String> _expanded = <String>{};

  int get _accountIndex => SingleAccountPageState.of(context)?.index ?? 0;

  TextEditingController searchText = TextEditingController();

  ScrollController controller = ScrollController();

  bool buttonshow = false;

  void scrollToTop() {
    controller.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(floatingButtonVisibility);
    searchText.addListener(() {
      setState(() {});
    });
  }

  void floatingButtonVisibility() {
    double y = controller.offset;
    if (y > MediaQuery.of(context).size.height / 2) {
      if (buttonshow == true) return;
      setState(() {
        buttonshow = true;
      });
    } else {
      if (buttonshow == false) return;
      setState(() {
        buttonshow = false;
      });
    }
  }

  Widget searchCell(WidgetRef context) {
    return Container(
      color: ref.watch(themeProvider).themeColor.searchBgColor(),
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 10,
      ),
      child: SearchCell(
        controller: searchText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter once per build instead of emitting a zero-size widget for every
    // non-matching row inside itemBuilder (that kept the whole log tree in
    // the scroll view even while searching).
    final String query = searchText.text.trim();
    final List<TaskLogBean> visible = query.isEmpty
        ? list
        : list.where((TaskLogBean e) => (e.name ?? "").contains(query)).toList();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Scaffold(
        floatingActionButton: Visibility(
          visible: buttonshow,
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              scrollToTop();
            },
            elevation: 2,
            child: const Icon(CupertinoIcons.up_arrow),
          ),
        ),
        appBar: QlAppBar(
          canBack: true,
          backCall: () {
            Navigator.of(context).pop();
          },
          title: "任务日志",
        ),
        // 不把整个页面堵在请求上：进来就先给搜索框和列表外壳，
        // 数据到了再填行。点「日志历史」时这里已经是预取过的。
        body: SlidableAutoCloseBehavior(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 50),
            controller: controller,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemBuilder: (context, index) {
              if (index == 0) {
                return searchCell(ref);
              }
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: LoadingWidget()),
                );
              }
              if (visible.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
                    child: Text(
                      "没有匹配的日志",
                      style: TextStyle(
                        color: ref.watch(themeProvider).themeColor.descColor(),
                      ),
                    ),
                  ),
                );
              }
              TaskLogBean item = visible[index - 1];

                    if ((item.isDir ?? false)) {
                      return Slidable(
                        key: ValueKey(item.name ?? ""),
                        endActionPane: ActionPane(
                          motion: const StretchMotion(),
                          extentRatio: 0.2,
                          children: [
                            SlidableAction(
                              backgroundColor: const Color(0xffEA4D3E),
                              onPressed: (_) {
                                showCupertinoDialog(
                                  context: context,
                                  useRootNavigator: false,
                                  builder: (context) => CupertinoAlertDialog(
                                    title: const Text("确认删除"),
                                    content: const Text("确定删除这个文件夹吗"),
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
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          deleteFold(item);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              foregroundColor: Colors.white,
                              icon: CupertinoIcons.delete,
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: query.isNotEmpty,
                          title: Text(
                            item.name ?? "",
                            style: TextStyle(
                              color: ref.watch(themeProvider).themeColor.titleColor(),
                              fontSize: 16,
                            ),
                          ),
                          onExpansionChanged: (bool open) {
                            setState(() {
                              if (open) {
                                _expanded.add(item.name ?? "");
                              } else {
                                _expanded.remove(item.name ?? "");
                              }
                            });
                          },
                          // 只给真正展开的目录构建子项。
                          // 旧实现在每次 build 时把所有日志文件都构造成 ListTile，
                          // 几千个文件时搜索框每输入一个字都要重建一遍。
                          children: (!query.isNotEmpty && !_expanded.contains(item.name ?? ""))
                              ? const <Widget>[]
                              : (item.files?.isNotEmpty ?? false)
                              ? item.files!
                                  .map((e) => ListTile(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            CupertinoPageRoute(
                                              builder: (context) => InTimeHistoryLogPage(
                                                path: item.name ?? "",
                                                title: e,
                                              ),
                                            ),
                                          );
                                        },
                                        title: Text(
                                          e,
                                          style: TextStyle(
                                            color: ref.watch(themeProvider).themeColor.titleColor(),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ))
                                  .toList()
                              : (item.children ?? [])
                                  .map((e) => ListTile(
                                        onTap: () {
                                          Navigator.of(context)
                                              .push(
                                            CupertinoPageRoute(
                                              builder: (context) => InTimeHistoryLogPage(
                                                path: item.name ?? "",
                                                title: e.title ?? "",
                                              ),
                                            ),
                                          )
                                              .then((value) {
                                            if (value != null && value == true) {
                                              loadData();
                                            }
                                          });
                                        },
                                        title: Text(
                                          e.title ?? "",
                                          style: TextStyle(
                                            color: ref.watch(themeProvider).themeColor.titleColor(),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                        ),
                      );
                    } else {
                      return Slidable(
                        key: ValueKey(item.name ?? ""),
                        endActionPane: ActionPane(
                          motion: const StretchMotion(),
                          extentRatio: 0.2,
                          children: [
                            SlidableAction(
                              backgroundColor: const Color(0xffEA4D3E),
                              onPressed: (_) {
                                showCupertinoDialog(
                                  context: context,
                                  useRootNavigator: false,
                                  builder: (context) => CupertinoAlertDialog(
                                    title: const Text("确认删除"),
                                    content: const Text("确定删除这个文件吗"),
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
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          deleteFold(item);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              foregroundColor: Colors.white,
                              icon: CupertinoIcons.delete,
                            ),
                          ],
                        ),
                        child: ListTile(
                          onTap: () {
                            if (item.isDir ?? false) {
                              "该文件夹为空".toast();
                              return;
                            }

                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => InTimeHistoryLogPage(
                                  path: "",
                                  title: item.name ?? "",
                                ),
                              ),
                            );
                          },
                          title: Text(
                            item.name ?? "",
                            style: TextStyle(
                              color: ref.watch(themeProvider).themeColor.titleColor(),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }
                  },
            itemCount: list.isEmpty
                ? 2
                : (visible.isEmpty ? 2 : visible.length + 1),
                ),
              ),
      ),
    );
  }

  Future<void> loadData() async {
    final int idx = _accountIndex;
    final Api api = SingleAccountPageState.ofApi(context);

    // 预取命中就先把内容铺上，用户不用等网络。
    final List<TaskLogBean>? cached = TaskLogCache.peek(idx);
    if (cached != null) {
      setState(() {
        list = cached;
      });
      _applySearchText();
    }

    final bool ok = await TaskLogCache.load(api, idx);
    if (!mounted) return;

    final List<TaskLogBean>? data = TaskLogCache.peek(idx);
    if (ok && data != null) {
      setState(() {
        list = data;
      });
      _applySearchText();
    } else if (cached == null) {
      "日志列表加载失败，下拉重试".toast();
    }
  }

  void _applySearchText() {
    final String? wanted = widget.searchText;
    if (wanted == null || wanted.isEmpty) return;
    if (searchText.text == wanted) return;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) return;
      searchText.text = wanted;
    });
  }

  @override
  void onLazyLoad() {
    loadData();
  }

  void deleteFold(TaskLogBean item) async {
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
    var temp = item.isDir == true
        ? await SingleAccountPageState.ofApi(context).deleteLogFold(item.name ?? "", "")
        : await SingleAccountPageState.ofApi(context).deleteLog(item.name ?? "", "");
    EasyLoading.dismiss();
    if (temp.success) {
      "已删除".toast();
      // 缓存里的树还带着刚删掉的节点，得作废
      TaskLogCache.invalidate(_accountIndex);
      await loadData();
    } else {
      temp.message.toast();
    }
  }
}
