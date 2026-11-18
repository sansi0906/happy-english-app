import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 音频播放封装：点读/单词发音，支持正常与慢速两种示范。
/// 慢速播放预生成的 _slow 音频（ffmpeg atempo），不使用 setPlaybackRate，
/// 避免安卓下降速连带降音调导致发音失真。
class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  /// 播放完成回调（UI 据此恢复播放按钮状态）
  static void Function()? onComplete;

  /// 全局默认是否慢速（跟读页切换时写入）
  static bool _slow = false;
  static bool get slowMode => _slow;
  static void setSlowMode(bool v) => _slow = v;

  /// 慢速资源存在性缓存：避免每次播放都用 rootBundle 读整个 mp3 探测
  static final Map<String, bool> _slowCache = {};

  static bool _listening = false;
  static void _ensureListener() {
    if (_listening) return;
    _listening = true;
    _player.onPlayerComplete.listen((_) => onComplete?.call());
  }

  static String _slowPath(String assetPath) =>
      assetPath.replaceFirst('.mp3', '_slow.mp3');

  static Future<bool> _hasSlow(String assetPath) async {
    final cached = _slowCache[assetPath];
    if (cached != null) return cached;
    var exists = false;
    try {
      await rootBundle.load(_slowPath(assetPath));
      exists = true;
    } catch (_) {
      exists = false;
    }
    _slowCache[assetPath] = exists;
    return exists;
  }

  /// 播放示范音。
  /// [slow] 传 null 时用全局 [slowMode]；显式传 false 的页面不受全局影响。
  /// 返回是否成功：失败不抛异常，调用方可据此给用户提示。
  static Future<bool> play(String assetPath, {bool? slow}) async {
    _ensureListener();
    var path = assetPath;
    final wantSlow = slow ?? _slow;
    if (wantSlow && await _hasSlow(assetPath)) {
      path = _slowPath(assetPath);
    }
    try {
      await _player.stop();
      await _player.play(AssetSource(path.replaceFirst('assets/', '')));
      return true;
    } catch (e, st) {
      // 素材缺失/解码失败时不要静默失败：留日志，并让 UI 有机会提示
      debugPrint('AudioService.play 失败 path=$path error=$e');
      debugPrintStack(stackTrace: st);
      return false;
    }
  }

  static Future<void> stop() => _player.stop();

  static Future<void> dispose() => _player.dispose();
}
