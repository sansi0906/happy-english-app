import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'app_log.dart';

/// 音频播放封装：课文点读 / 单词发音。
/// V1.5.4：慢速音频（*_slow.mp3）已从包内移除（UI 早已无入口），
/// 同步删掉 slow 分支，只保留一条播放路径，避免探测不存在的资源。
class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  /// 播放完成回调 + 持有者（V1.5.5）
  /// 原来 onComplete 是裸的静态字段：A 页面注册后 B 页面播放，播完回调仍打到 A。
  /// 现在绑定持有者，只有当前持有者能收到回调、也只有持有者能清空。
  static VoidCallback? _onDone;
  static Object? _owner;

  static bool _listening = false;
  static void _ensureListener() {
    if (_listening) return;
    _listening = true;
    _player.onPlayerComplete.listen((_) => _onDone?.call());
  }

  /// 注册"播放结束"回调。[owner] 通常是调用页面的 State 实例。
  static void bindCompletion(Object owner, VoidCallback? cb) {
    _owner = owner;
    _onDone = cb;
  }

  /// 页面销毁时调用：只有当前持有者才能清空，避免误清掉别的页面的回调。
  static void releaseCompletion(Object owner) {
    if (identical(_owner, owner)) {
      _owner = null;
      _onDone = null;
    }
  }

  /// 播放示范音。
  /// 返回是否成功：失败不抛异常，调用方可据此给用户提示。
  static Future<bool> play(String assetPath) async {
    _ensureListener();
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath.replaceFirst('assets/', '')));
      return true;
    } catch (e, st) {
      // 素材缺失/解码失败不能静默：留日志，并让 UI 有机会提示
      AppLog.append('audio', '播放失败 path=$assetPath error=$e');
      debugPrintStack(stackTrace: st);
      return false;
    }
  }

  static Future<void> stop() => _player.stop();

  static Future<void> dispose() => _player.dispose();
}
