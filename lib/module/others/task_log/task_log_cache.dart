import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/module/others/task_log/task_log_bean.dart';

/// `/api/logs` 只能整棵返回（服务端没有按目录过滤的参数，永远是
/// `readDirs(logPath)` 全量），面板跑久了这棵树可能上千个节点、几 MB。
/// 等到点进「任务日志」再发请求，用户就得对着转圈等网络。
///
/// 这里做两件事：
///  * 在任务详情页打开时就预取（「日志历史」就在那一页，一点就到）；
///  * 把结果留在内存里，同账号再次进入直接出内容。
///
/// 单飞（single-flight）保证同一账号同时只有一个请求在跑，预取和页面
/// 自身的刷新不会各发一遍。
class TaskLogCache {
  static final Map<int, List<TaskLogBean>> _data = <int, List<TaskLogBean>>{};
  static final Map<int, Future<bool>> _inflight = <int, Future<bool>>{};

  /// 已有结果就直接给，没有返回 null（不触发请求）。
  static List<TaskLogBean>? peek(int index) => _data[index];

  static void put(int index, List<TaskLogBean> data) => _data[index] = data;

  /// 删除日志后必须让缓存失效，否则列表还是旧的。
  static void invalidate(int index) {
    _data.remove(index);
  }

  /// 拉取（或复用正在跑的那次）。返回是否拿到了数据。
  static Future<bool> load(Api api, int index) {
    final Future<bool>? running = _inflight[index];
    if (running != null) return running;

    final Future<bool> task = _fetch(api, index);
    _inflight[index] = task;
    // 放在 then 里移除，保证调用方拿到的是最终结果
    task.whenComplete(() {
      if (identical(_inflight[index], task)) {
        _inflight.remove(index);
      }
    });
    return task;
  }

  static Future<bool> _fetch(Api api, int index) async {
    final response = await api.taskLog();
    if (response.success && response.bean != null) {
      _data[index] = response.bean!;
      return true;
    }
    return false;
  }
}
