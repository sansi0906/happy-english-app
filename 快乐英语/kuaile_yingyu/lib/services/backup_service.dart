import 'dart:async';

import 'package:flutter/services.dart';

import '../data/progress_db.dart';
import 'app_log.dart';

/// 学习记录备份的对外入口。
///
/// 备份的生成、校验、恢复都在 [ProgressDb]（数据层）；
/// 这里只负责把备份文件交到家长手里——导出到公共下载目录
/// `Download/快乐英语备份/`，方便转发到电脑或换机时导入。
class BackupService {
  static const _channel = MethodChannel('kuaile_recordings');

  /// 导出备份到下载目录，返回可读路径（如 "Download/快乐英语备份/xxx.json"）。
  /// 失败返回 null 并写诊断日志。
  static Future<String?> exportToDownloads() async {
    try {
      final json = await ProgressDb.exportJson();
      final name = '快乐英语进度_${_stamp()}.json';
      return await _channel.invokeMethod<String>('saveText', {
        'fileName': name,
        'content': json,
      });
    } catch (e, st) {
      AppLog.append('backup', '导出到下载目录失败: $e');
      unawaited(Future.microtask(() => AppLog.error(e, st)));
      return null;
    }
  }

  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }
}
