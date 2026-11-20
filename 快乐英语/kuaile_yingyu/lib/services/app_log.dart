import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 统一诊断日志（V1.5.5 新增）
///
/// 原来只有 main.dart 里的 `_logFatal` 记录未捕获异常，业务侧的关键失败
/// （录音没存上、音频播不出来）只走 debugPrint，家长完全看不到。
/// 这里把它们落到同一个文件，设置页「诊断日志」可直接读取并复制。
class AppLog {
  static const fileName = 'app_error.log';

  /// 单文件上限，超过后丢弃前半段，避免无限增长。
  static const _maxBytes = 512 * 1024;

  static Future<File?> _file() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$fileName');
    } catch (_) {
      return null;
    }
  }

  /// 追加一条日志。失败不抛异常——记录日志不能反过来影响主流程。
  static Future<void> append(String tag, String msg) async {
    debugPrint('[$tag] $msg');
    final f = await _file();
    if (f == null) return;
    try {
      if (await f.exists() && await f.length() > _maxBytes) {
        final content = await f.readAsString();
        // 从中间截断，保留较新的一半
        await f.writeAsString(content.substring(content.length ~/ 2));
      }
      await f.writeAsString(
        '${DateTime.now().toIso8601String()}  [$tag] $msg\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // 磁盘不可写时只能放弃
    }
  }

  /// 异常专用：带堆栈
  static Future<void> error(Object error, StackTrace stack) =>
      append('fatal', '$error\n$stack');

  static Future<String> read() async {
    final f = await _file();
    if (f == null) return '（无法访问日志目录）';
    try {
      if (!await f.exists()) return '（还没有日志记录）';
      return await f.readAsString();
    } catch (e) {
      return '（读取失败：$e）';
    }
  }

  static Future<void> clear() async {
    final f = await _file();
    try {
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 日志体积（字节），用于设置页展示
  static Future<int> size() async {
    final f = await _file();
    try {
      if (f != null && await f.exists()) return await f.length();
    } catch (_) {}
    return 0;
  }
}
