import 'package:flutter/material.dart';

import '../data/content_index.dart';
import '../data/models.dart';
import '../data/progress_db.dart';
import '../main.dart';
import '../services/app_log.dart';
import '../widgets/score_widgets.dart';
import '../widgets/safe_tap.dart';
import 'speak_page.dart';

/// 一条待复习记录：进度表里捞出来的弱项 + 反查到的教材位置
typedef _Weak = ({
  Book book,
  Unit unit,
  Item item,
  double score,
  int stars,
});

/// 再练一遍（错题本）：把「练过但分数没到合格线」的句子集中起来，
/// 点进去直接进跟读页，练到合格线以上就会从这个列表里消失。
///
/// 数据完全来自本机进度表，不联网、不上传。
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _loading = true;
  String? _error;
  List<_Weak> _list = const [];
  /// 进度表里有、但教材内容里找不到的 key 数量（内容换版后会这样）
  int _missing = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final index = await buildContentIndex();
      final rows = await ProgressDb.weakItems();

      final out = <_Weak>[];
      var missing = 0;
      for (final r in rows) {
        final key = r['item_id'] as String? ?? '';
        final pos = index[key];
        if (pos == null) {
          missing++;
          continue;
        }
        out.add((
          book: pos.book,
          unit: pos.unit,
          item: pos.item,
          score: (r['score'] as num?)?.toDouble() ?? 0,
          stars: (r['stars'] as int?) ?? 0,
        ));
      }
      if (!mounted) return;
      setState(() {
        _list = out;
        _missing = missing;
        _error = null;
        _loading = false;
      });
    } catch (e, st) {
      AppLog.error(e, st);
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _practice(_Weak w) async {
    final grade = int.tryParse(w.book.grade) ?? 1;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpeakDetailPage(
            unit: w.unit, item: w.item, grade: grade),
      ),
    );
    // 回来重新拉一次：练到达标的会自己消失
    if (mounted) await _load();
  }

  static String _where(_Weak w) => whereLabel((
        book: w.book,
        unit: w.unit,
        item: w.item,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        title: const Text('再练一遍',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: kDark)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: kOrange, size: 52),
              const SizedBox(height: 14),
              const Text('读取复习列表失败',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: kDark)),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: kMuted)),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: kGreenSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: kGreen, size: 40),
              ),
              const SizedBox(height: 18),
              const Text('没有要补的句子',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: kDark)),
              const SizedBox(height: 8),
              const Text(
                '跟读分数低于 70 分的句子会自动收到这里，\n练到 70 分以上就会消失。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: kMuted, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 2),
          child: Text(
            '共 ${_list.length} 句待加强${_missing > 0 ? '（另有 $_missing 条旧记录找不到对应课文）' : ''}',
            style: const TextStyle(fontSize: 15, color: kMuted),
          ),
        ),
        for (final w in _list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WeakTile(
              data: w,
              where: _where(w),
              onTap: () => _practice(w),
            ),
          ),
      ],
    );
  }
}

class _WeakTile extends StatelessWidget {
  final _Weak data;
  final String where;
  final VoidCallback onTap;

  const _WeakTile({
    required this.data,
    required this.where,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final score = data.score.round();
    // 分数越低越显眼：<50 用橙，50-69 用浅一些的橙
    final scoreColor = score < 50 ? kOrange : const Color(0xFFD79A4A);
    return SafeTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                data.item.imageAsset,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => SizedBox(
                  width: 56,
                  height: 56,
                  child: const Icon(Icons.image_not_supported_outlined,
                      size: 24, color: kMuted),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.item.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w700, color: kDark)),
                  const SizedBox(height: 3),
                  Text(where,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: kMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StarRow(star5: data.stars, size: 20),
                      const SizedBox(width: 8),
                      Text('$score 分',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: scoreColor)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: kGreenSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('再练',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kGreen)),
            ),
          ],
        ),
      ),
    );
  }
}
