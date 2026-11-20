import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 音频播放封装：课文点读 / 单词发音。
/// V1.5.4：慢速音频（*_slow.mp3）已从包内移除（UI 早已无入口），
/// 同步删掉 slow 分支，只保留一条播放路径，避免探测不存在的资源。
class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  /// 播放完成回调（UI 据此恢复播放按钮状态）
  static void Function()? onComplete;

  static bool _listening = false;
  static void _ensureListener() {
    if (_listening) return;
    _listening = true;
    _player.onPlayerComplete.listen((_) => onComplete?.call());
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
      debugPrint('AudioService.play 失败 path=$assetPath error=$e');
      debugPrintStack(stackTrace: st);
      return false;
    }
  }

  static Future<void> stop() => _player.stop();

  static Future<void> dispose() => _player.dispose();
}
