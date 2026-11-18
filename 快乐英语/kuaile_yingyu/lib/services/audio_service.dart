import 'package:audioplayers/audioplayers.dart';

/// 音频播放封装：点读/单词发音，统一按正常语速播放。
class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  /// 播放完成回调（UI 据此恢复播放按钮状态）
  static void Function()? onComplete;

  /// 初始化完成监听（进程内只注册一次）
  static bool _listening = false;
  static void _ensureListener() {
    if (_listening) return;
    _listening = true;
    _player.onPlayerComplete.listen((_) => onComplete?.call());
  }

  static Future<void> play(String assetPath) async {
    _ensureListener();
    await _player.stop();
    await _player.setPlaybackRate(1.0);
    await _player.play(AssetSource(assetPath.replaceFirst('assets/', '')));
  }

  static Future<void> stop() => _player.stop();

  static Future<void> dispose() => _player.dispose();
}
