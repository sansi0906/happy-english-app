import 'package:flutter/material.dart';

import '../main.dart';
import '../services/scoring.dart';
import '../services/speech_service.dart';

/// 五档星级的小号展示（跟读列表用）。
///
/// 历史数据里 star5 是 0-5，但 V1.5.3 起统一存三档，
/// 这里按三颗星渲染，多出来的档位自动并到满星。
class StarRow extends StatelessWidget {
  final int star5; // 0-5，0 表示还没练过
  final double size;

  const StarRow({super.key, required this.star5, required this.size});

  @override
  Widget build(BuildContext context) {
    if (star5 <= 0) {
      return Icon(Icons.star_border, color: const Color(0xFFD8CFC0), size: size);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          i < star5 ? Icons.star : Icons.star_border,
          color: kYellow,
          size: size,
        ),
      ),
    );
  }
}

/// 跟读成绩卡：三颗星 + 鼓励语 + 分数（低分时给出怎么改进的提示）。
class ScoreResultCard extends StatelessWidget {
  final SpeakResult result;

  const ScoreResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
        boxShadow: kShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Icon(
                i < result.displayStars
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: i < result.displayStars ? kOrange : kLine,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // V1.2.1：没听到声音（0 分且无错误）时给明确提示，其余按星级给鼓励语
          Text(
              result.score <= 0
                  ? '没听到声音，靠近一点再试试！'
                  : encouragement(result.displayStars),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w700, color: kDark)),
          const SizedBox(height: 4),
          Text('${result.score.toStringAsFixed(0)} 分',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: kMuted)),
          if (result.score >= 35 && result.score <= 45)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('读慢一点、声音大一点，靠近手机再试一次',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: kMuted)),
            ),
        ],
      ),
    );
  }
}
