import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 音频播放封装：点读/单词发音，支持正常与慢速两种示范。
/// 慢速播放预生成的 _slow 音频（ffmpeg atempo），不使用 setPlaybackRate，
/// 避免安卓下降速连带降音调导致发音失真。
class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  /// 播放完成回调（UI 据此恢复播放按钮状态）
  static void Function()? onComplete;

  /// 是否使用慢速示范
  static bool _slow = false;
  static bool get slowMode => _slow;
  static void setSlowMode(bool v) => _slow = v;

  static bool _listening = false;
  static void _ensureListener() {
    if (_listening) return;
    _listening = true;
    _player.onPlayerComplete.listen((_) => onComplete?.call());
  }

  static String _slowPath(String assetPath) =>
      assetPath.replaceFirst('.mp3', '_slow.mp3');

  static Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> play(String assetPath) async {
    _ensureListener();
    await _player.stop();
    var path = assetPath;
    if (_slow) {
      final slow = _slowPath(assetPath);
      if (await _assetExists(slow)) path = slow;
    }
    await _player.play(AssetSource(path.replaceFirst('assets/', '')));
  }

  static Future<void> stop() => _player.stop();

  static Future<void> dispose() => _player.dispose();
}
