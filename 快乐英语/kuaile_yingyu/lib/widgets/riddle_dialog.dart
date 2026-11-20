import 'package:flutter/material.dart';

import '../main.dart';

/// 满分奖励知识卡弹窗。
///
/// 跟读拿到 85 分以上时弹出，先给题目、再点「看答案」翻出答案。
/// 每个跟读项第一次达标才弹一次，是否已读过由调用方（ProgressDb）判断。
class RiddleDialog extends StatefulWidget {
  final int index;
  final int total;
  final String category;
  final String question;
  final String answer;
  final bool isLast;

  const RiddleDialog({
    super.key,
    required this.index,
    required this.total,
    required this.category,
    required this.question,
    required this.answer,
    required this.isLast,
  });

  @override
  State<RiddleDialog> createState() => _RiddleDialogState();
}

class _RiddleDialogState extends State<RiddleDialog> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.celebration, color: kOrange, size: 28),
                const SizedBox(width: 8),
                Text('满分奖励 · ${widget.category}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: kDark)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: kGreenSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(widget.question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: kDark,
                      height: 1.4)),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _showAnswer
                  ? Container(
                      key: const ValueKey('ans'),
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: kYellow.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('答案：${widget.answer}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: kDark)),
                    )
                  : const SizedBox(key: ValueKey('none'), height: 4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showAnswer ? kGreen : kOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  if (_showAnswer) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _showAnswer = true);
                  }
                },
                child: Text(
                  !_showAnswer ? '看答案' : (widget.isLast ? '完成' : '下一题'),
                  style: const TextStyle(
                      fontSize: 18, color: kWhite, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
