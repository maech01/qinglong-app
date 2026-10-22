# qinglong_app

基于 Flutter 框架编写的APP

基于[qinglong](https://github.com/whyour/qinglong)开源项目

可前往[**Release**](https://github.com/ayoulx/qinglong-app/releases)下载**客户端**使用，非**服务端**！

## 本分支的改动

### 1. 修复二级及更深目录下的脚本打不开

青龙 `/api/scripts` 返回的每个条目带 `key`（相对脚本根目录的完整路径）和 `parent`（所在目录）。
旧代码打开文件时直接把服务端给的 `parent` 拼进 `GET /api/scripts/<文件名>?path=<parent>`：

* 面板只回传**直接上级目录名**（`sub` 而不是 `folder/sub`）时，两级以上的路径就拼错了；
* 面板/反代把**绝对路径**塞进 `parent` 时，同样拼出一个不存在的路径。

更麻烦的是服务端对不存在的文件返回 `200` + 空内容（`getFileContentByName` 吞掉 ENOENT），
所以界面上表现为"点进去是空白"，而不是报错——这就是"二级文件夹以上的脚本不能打开"。

改法：

* `ScriptData.normalizeTree()` 用**树结构本身**推导每个节点的目录，不再依赖服务端的 `parent`；
* `ScriptData.pathCandidates` 给出有序候选：结构推导值 → 服务端原值 → `key` 的 dirname；
* `ScriptDetailPage` 逐个候选尝试，取第一个非空结果；空文件也不会误判成失败；
* 上传脚本时的目标目录树（`upload_script_widget.dart`）同样走结构推导，"添加到任务"和删除也改用实际命中的目录。

`pathtest.dart` 覆盖了根目录、一级、二级、三级、错误 `parent`、绝对路径 `parent` 与幂等性，11 项断言全通过。

### 2. 历史日志不再卡顿

四个日志页（历史日志 / 即时日志 / 依赖日志 / 订阅日志）和任务日志详情原来都是
`SingleChildScrollView + ExtendedText(整段文本)`：几十万行的日志要在 UI 线程上一次排版完，
必然卡死或掉帧。

改为 `VirtualLogView`：切行一次（12 MB / 12 万行实测 55 ms），用 `ListView.builder` 只排版可见行；
选择功能由外层一个 `SelectionArea` 提供，不再每行一个选择控制器；
超过 30 万行时只保留**最新的**部分并在顶部提示省略行数。

### 3. 其它

* `taskLogDetail` 原来用字符串拼接 `?path=`，任务名含空格/中文时会拼出非法 URL，改为走 `queryParameters` 并对文件名做 `encodeURIComponent` 等价编码；
* 任务日志列表的搜索改为先过滤再构建，不再给每个不匹配项塞一个 `SizedBox.shrink()`。

## 构建

本仓库是 2022 年的 Flutter 工程（Dart `<3.0.0`、AGP 4.1 / Gradle 6.7 的构建布局），
**必须用 Flutter 3.7.x + JDK 11**：Flutter 3.16 起删掉了项目依赖的 `apply from: flutter.gradle`，
而 Gradle 6.7 跑不了 JDK 17。

```bash
./build_apk.sh          # 自动补签名密钥 → pub get → build apk
# 产物: build/app/outputs/flutter-apk/app-release.apk
```

不想装环境就用 CI：[`Build APK`](.github/workflows/build-apk.yml) 工作流会在推送后构建并上传
`qinglong-app-release` 构件，直接下载即可。

签名密钥 `android/app/qinglong.keystore` 被 `.gitignore` 忽略，首次构建由脚本自动生成
（别名/口令与原工程一致：`jiangyuesong`）。
