import 'package:flutter/material.dart';

import '../data/models.dart';
import '../main.dart';
import '../services/audio_service.dart';

/// 单词学习 V2：
/// 顶部一条可点的单词索引（点哪个跳到哪个，当前页高亮），
/// 中部一张大卡（图 + 英文 + 中文 + 喇叭），底部保留左右翻页与进度。
class WordPage extends StatefulWidget {
  final Unit unit;

  const WordPage({super.key, required this.unit});

  @override
  State<WordPage> createState() => _WordPageState();
}

class _WordPageState extends State<WordPage> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final words = widget.unit.words;
    if (words.isEmpty) {
      return const Center(
        child: Text('本单元还没有单词', style: TextStyle(fontSize: 22, color: kMuted)),
      );
    }

    return Column(
      children: [
        // ---- 单词索引条 ----
        SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 56, 8),
            itemCount: words.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final active = i == _index;
              return GestureDetector(
                onTap: () => _controller.animateToPage(i,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? kGreen : kWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: active ? kGreen : kLine),
                  ),
                  child: Center(
                    child: Text(
                      words[i].text,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? kWhite : kDark,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ---- 单词大卡 ----
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: words.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final w = words[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(kRadius),
                    border: Border.all(color: kLine),
                    boxShadow: kShadow,
                  ),
                  child: Column(
                    children: [
                      // 图片区
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5EC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            w.imageAsset,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const Center(
                              child: Icon(Icons.image_not_supported_outlined,
                                  size: 40, color: kMuted),
                            ),
                          ),
                        ),
                      ),
                      Text(w.text,
                          style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: kDark,
                              height: 1.2)),
                      const SizedBox(height: 4),
                      Text(w.meaning ?? '',
                          style: const TextStyle(fontSize: 21, color: kMuted)),
                      const SizedBox(height: 40),
                      // 发音按钮
                      GestureDetector(
                        onTap: () => AudioService.play(w.audioAsset, slow: false),
                        child: Container(
                          width: 128,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: kGreen,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: kGreen.withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.volume_up_rounded,
                                  color: kWhite, size: 24),
                              SizedBox(width: 6),
                              Text('听发音',
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: kWhite)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ---- 底部翻页 ----
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                enabled: _index > 0,
                onTap: () => _controller.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut),
              ),
              const SizedBox(width: 18),
              Text('${_index + 1} / ${words.length}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, color: kMuted)),
              const SizedBox(width: 18),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                enabled: _index < words.length - 1,
                onTap: () => _controller.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    AudioService.stop();
    super.dispose();
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: enabled ? kWhite : kWhite.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? kLine : kLine.withValues(alpha: 0.4)),
        ),
        child: Icon(icon,
            size: 26, color: enabled ? kDark : kMuted.withValues(alpha: 0.45)),
      ),
    );
  }
}
