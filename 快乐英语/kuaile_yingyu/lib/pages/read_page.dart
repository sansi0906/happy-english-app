import 'package:flutter/material.dart';

import '../data/models.dart';
import '../main.dart';
import '../services/audio_service.dart';
import '../widgets/safe_tap.dart';

/// 课文点读 V2：改成"左图 + 右句"的紧凑行式列表。
///
/// 原来每条是一张半屏大卡（180 高配图 + 胶囊按钮），一屏只看得到一句，
/// 家长要滑十几下才读完一个单元。现在一行约 96 高，一屏 5-6 句，
/// 点击整行即播放，播放中行内高亮并显示停止图标。
class ReadPage extends StatefulWidget {
  final Unit unit;

  const ReadPage({super.key, required this.unit});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  String? _playingId;

  @override
  void initState() {
    super.initState();
    // 播放完成自动恢复为播放按钮
    AudioService.onComplete = () {
      if (mounted) setState(() => _playingId = null);
    };
  }

  @override
  void dispose() {
    AudioService.onComplete = null;
    AudioService.stop();
    super.dispose();
  }

  Future<void> _toggle(Item item) async {
    if (_playingId == item.id) {
      await AudioService.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    // 点读页固定正常语速：跟读页的"慢速"开关不应串到这里
    await AudioService.play(item.audioAsset);
    if (mounted) setState(() => _playingId = item.id);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.unit.sentences;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        // 首行提示
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Row(
              children: [
                const Icon(Icons.touch_app_outlined, size: 18, color: kMuted),
                const SizedBox(width: 6),
                Text('点任意一行听发音 · 共 ${items.length} 句',
                    style: const TextStyle(fontSize: 15, color: kMuted)),
              ],
            ),
          );
        }
        final it = items[i - 1];
        final playing = _playingId == it.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SafeTap(
            onTap: () => _toggle(it),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: playing ? kGreenSoft : kWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: playing ? kGreen : kLine,
                    width: playing ? 1.6 : 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 左侧缩略图
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      it.imageAsset,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: 64,
                        height: 64,
                        color: kGreenSoft,
                        child: const Icon(Icons.image_not_supported_outlined,
                            size: 26, color: kMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 中间句子
                  Expanded(
                    child: Text(
                      it.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: kDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 右侧播放/停止圆钮
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: playing ? kOrange : kGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: kWhite,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
