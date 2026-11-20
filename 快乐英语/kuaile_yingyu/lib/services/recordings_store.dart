import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_log.dart';

/// 跟读录音本地归档（V1.1 新增）
/// 录音与索引保存在公共下载目录 Download/快乐英语录音/
/// （无需权限，adb 可直接读取；家长可在文件管理器查看/拷贝）。
/// 文件名：{昵称}_{bookId}_{itemId}_{分数}_{yyyyMMdd_HHmmss}.wav
///
/// V1.5.5：原先所有异常都是 `catch (_) {}` 静默吞掉，录音没存上也无从发现。
/// 现在统一走 [_fail] 记录操作名与原因到 [lastError]，并打日志，
/// 设置页/诊断包可以据此暴露"最近一次录音失败"的真相。
class RecordingsStore {
  static const _channel = MethodChannel('kuaile_recordings');

  /// 最近一次失败原因（成功后清空）。null 表示最近一次操作成功。
  static String? lastError;

  static void _fail(String op, Object e, [StackTrace? st]) {
    lastError = '$op: $e';
    AppLog.append('recordings', '$op 失败: $e');
    if (st != null) debugPrintStack(stackTrace: st);
  }

  // V1.3.7：索引"读全量→追加→写回"用 Future 队列串行化，
  // 避免快速连续录音时并发读写导致索引丢失。
  static Future<void> _lock = Future.value();

  static Future<T> _serial<T>(Future<T> Function() f) {
    final p = _lock.then((_) => f());
    _lock = p.then((_) {}, onError: (_) {});
    return p;
  }

  /// 归档一条录音：更新索引后整体写入 Download/快乐英语录音/
  /// [srcPath] 临时 WAV 路径；[fileName] 归档文件名。
  /// 返回是否成功；成功后由调用方删除临时文件。
  static Future<bool> saveWav({
    required String srcPath,
    required String fileName,
    required String child,
    required String bookId,
    required String itemId,
    required String text,
    required double score,
    required int stars,
  }) {
    return _serial(() async {
      try {
        // 读旧索引 → 追加 → 完整写回
        final List<dynamic> list = [];
        final old = await readIndex();
        if (old != null && old.isNotEmpty) {
          try {
            final arr = jsonDecode(old) as List<dynamic>;
            list.addAll(arr);
          } catch (e, st) {
            // 索引损坏不应中断归档：记录原因后按空索引重建，避免旧数据连带失败
            _fail('saveWav/parseIndex', e, st);
          }
        }
        list.add({
          'file': fileName,
          'child': child,
          'book_id': bookId,
          'item_id': itemId,
          'text': text,
          'score': score,
          'stars': stars,
          'ts': DateTime.now().toIso8601String(),
        });
        final indexJson = const JsonEncoder.withIndent('  ').convert(list);
        final ok = await _channel.invokeMethod<bool>('saveWav', {
              'srcPath': srcPath,
              'fileName': fileName,
              'indexJson': indexJson,
            }) ??
            false;
        if (ok) {
          lastError = null;
        } else {
          lastError = 'saveWav: 原生侧返回失败（可能是下载目录不可写）';
        }
        return ok;
      } catch (e, st) {
        _fail('saveWav', e, st);
        return false;
      }
    });
  }

  /// 读取索引 JSON 原文（无记录返回 null）
  static Future<String?> readIndex() async {
    try {
      return await _channel.invokeMethod<String>('readIndex');
    } catch (e, st) {
      _fail('readIndex', e, st);
      return null;
    }
  }

  /// 把某条录音拷贝到 app 缓存目录并返回本地路径（供回听）。
  /// 文件已被自动清理（只保留最高分）时返回 null。
  static Future<String?> copyRecording(String fileName) async {
    try {
      return await _channel.invokeMethod<String>('copyRecording', {
        'fileName': fileName,
      });
    } catch (e, st) {
      _fail('copyRecording', e, st);
      return null;
    }
  }

  /// 清空全部录音与索引
  static Future<void> clearAll() async {
    try {
      await _channel.invokeMethod('clearAll');
      lastError = null;
    } catch (e, st) {
      _fail('clearAll', e, st);
    }
  }

  /// 导出全部录音为 zip，放到公共下载目录根目录。
  /// 返回可读路径（如 "Download/快乐英语录音_20261119_143000.zip"）；
  /// 没有录音或失败时返回 null。
  static Future<String?> exportAll() async {
    try {
      final p = await _channel.invokeMethod<String>('exportAll');
      if (p == null) lastError = 'exportAll: 没有可导出的录音';
      return p;
    } catch (e, st) {
      _fail('exportAll', e, st);
      return null;
    }
  }

  /// 录音统计：条数 + 占用字节。
  /// 读取失败时返回 error=true，UI 可区分"真的 0 条"和"读不到"。
  static Future<({int count, int bytes, bool error})> stats() async {
    try {
      final s = await _channel.invokeMethod<String>('stats');
      if (s == null) return (count: 0, bytes: 0, error: false);
      final m = jsonDecode(s) as Map<String, dynamic>;
      return (
        count: m['count'] as int? ?? 0,
        bytes: m['bytes'] as int? ?? 0,
        error: false,
      );
    } catch (e, st) {
      _fail('stats', e, st);
      return (count: 0, bytes: 0, error: true);
    }
  }
}
