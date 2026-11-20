import 'package:flutter/material.dart';

import '../data/content_index.dart';
import '../data/models.dart';
import '../data/progress_db.dart';
import '../main.dart';
import '../services/app_log.dart';
import '../widgets/safe_tap.dart';
import 'speak_page.dart';

/// 一位家长的视角：这周孩子练了几次、分数怎么样、哪些句子还得再补。
/// 数据全部来自本机 attempts 流水表，不联网。
class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  bool _loading = true;
  String? _error;

  /// 本周一 00:00
  DateTime _monday = DateTime.now();

  List<_DayBar> _days = const [];
  int _totalAttempts = 0;
  int _distinctItems = 0;
  int _passItems = 0;
  double? _avgScore;
  int _weak = 0;
  List<_WeakRow> _needWork = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  static DateTime mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final monday = mondayOf(now);
      final rows = await ProgressDb.attemptsSince(monday);
      final index = await buildContentIndex();
      final weakRows = await ProgressDb.weakItems();

      // 7 天柱子（周一 → 周日）
      final counts = List<int>.filled(7, 0);
      final bestScoreOfItem = <String, double>{};
      final practicedItems = <String>{};
      final passItems = <String>{};
      var scoreSum = 0.0;
      var scoreCount = 0;

      for (final r in rows) {
        final at = DateTime.tryParse(r['at'] as String? ?? '');
        if (at == null) continue;
        final d = DateTime(at.year, at.month, at.day);
        final diff = d.difference(monday).inDays;
        if (diff < 0 || diff > 6) continue;
        counts[diff]++;

        final id = r['item_id'] as String? ?? '';
        if (id.isEmpty) continue;
        practicedItems.add(id);
        final score = (r['score'] as num?)?.toDouble() ?? -1;
        if (score >= 0) {
          scoreSum += score;
          scoreCount++;
          if (score >= ProgressDb.passScore) passItems.add(id);
          final prev = bestScoreOfItem[id];
          if (prev == null || score > prev) bestScoreOfItem[id] = score;
        }
      }

      final days = <_DayBar>[
        for (var i = 0; i < 7; i++)
          _DayBar(
            label: const ['一', '二', '三', '四', '五', '六', '日'][i],
            date: monday.add(Duration(days: i)),
            count: counts[i],
            isToday: DateTime(now.year, now.month, now.day)
                .difference(monday)
                .inDays ==
                i,
            isFuture: monday.add(Duration(days: i)).isAfter(
                DateTime(now.year, now.month, now.day)),
          ),
      ];

      // 最需要补的 3 句：从错题本里取最靠前的几个
      final needWork = <_WeakRow>[];
      for (final r in weakRows.take(3)) {
        final id = r['item_id'] as String? ?? '';
        final pos = index[id];
        if (pos == null) continue;
        needWork.add((
          book: pos.book,
          unit: pos.unit,
          item: pos.item,
          score: (r['score'] as num?)?.toDouble() ?? 0,
        ));
      }

      if (!mounted) return;
      setState(() {
        _monday = monday;
        _days = days;
        _totalAttempts = rows.length;
        _distinctItems = practicedItems.length;
        _passItems = passItems.length;
        _avgScore = scoreCount == 0 ? null : scoreSum / scoreCount;
        _weak = weakRows.length;
        _needWork = needWork;
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

  Future<void> _practice(_WeakRow w) async {
    final grade = int.tryParse(w.book.grade) ?? 1;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpeakDetailPage(unit: w.unit, item: w.item, grade: grade),
      ),
    );
    if (mounted) await _load();
  }

  String get _rangeText {
    String md(DateTime d) => '${d.month}/${d.day}';
    final end = _monday.add(const Duration(days: 6));
    return '${md(_monday)} – ${md(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        title: const Text('本周学习报告',
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
              const Text('报告读取失败',
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      children: [
        _heroCard(),
        const SizedBox(height: 14),
        _chartCard(),
        const SizedBox(height: 14),
        _metricsRow(),
        const SizedBox(height: 20),
        if (_needWork.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最需要补的几句',
                    style: TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700, color: kDark),
                ),
                SizedBox(height: 2),
                Text('按已练过的分数排的，不限本周',
                    style: TextStyle(fontSize: 13, color: kMuted)),
              ],
            ),
          ),
          for (final w in _needWork)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WeakCard(
                data: w,
                where: whereLabel(
                    (book: w.book, unit: w.unit, item: w.item)),
                onTap: () => _practice(w),
              ),
            ),
        ],
        const SizedBox(height: 6),
        _footNote(),
      ],
    );
  }

  Widget _heroCard() {
    final practicedDays = _days.where((d) => d.count > 0).length;
    final title = _totalAttempts == 0
        ? '这周还没有跟读练习'
        : '这周练了 $_totalAttempts 次';
    final sub = _totalAttempts == 0
        ? '带孩子读一句，这里就会有记录'
        : '一共 $_distinctItems 句 · $practicedDays 天有练习';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kGreenSoft,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.insights_rounded, color: kGreen, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: kDark)),
                const SizedBox(height: 4),
                Text(sub, style: const TextStyle(fontSize: 15, color: kMuted)),
                const SizedBox(height: 2),
                Text('$_rangeText（周一至周日）',
                    style: const TextStyle(fontSize: 13, color: kMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard() {
    final maxCount =
        _days.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('每天练了几次',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: kDark)),
          const SizedBox(height: 14),
          SizedBox(
            height: 118,
            child: Row(
              children: [
                for (final d in _days)
                  Expanded(
                    child: _DayColumn(day: d, maxCount: maxCount),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsRow() {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.star_rounded,
            color: kOrange,
            label: '平均分',
            value: _avgScore == null ? '—' : _avgScore!.round().toString(),
            sub: _avgScore == null ? '还没有分数' : '满分 100 · 三星 85',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.check_circle_rounded,
            color: kGreen,
            label: '本周达标',
            value: '$_passItems',
            sub: '句',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            icon: Icons.replay_rounded,
            color: kBlue,
            label: '待复习',
            value: '$_weak',
            sub: '句',
          ),
        ),
      ],
    );
  }

  Widget _footNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 4),
      child: Text(
        '统计只保存在这台手机上，不上传。\n'
        '每次跟读都会记一次；更早之前的练习只按最后一次的成绩计入。',
        style: const TextStyle(fontSize: 13, color: kMuted, height: 1.6),
      ),
    );
  }
}

/// 柱子里的一天
class _DayBar {
  final String label;
  final DateTime date;
  final int count;
  final bool isToday;
  final bool isFuture;

  const _DayBar({
    required this.label,
    required this.date,
    required this.count,
    required this.isToday,
    required this.isFuture,
  });
}

class _DayColumn extends StatelessWidget {
  final _DayBar day;
  final int maxCount;

  const _DayColumn({required this.day, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    // 最高的一天占满 76 高的柱子，其余按比例，最少 6（有练习才显示）
    final barH = day.count == 0
        ? 0.0
        : (maxCount <= 1 ? 76.0 : 76.0 * (day.count / maxCount)).clamp(10.0, 76.0);
    final color = day.isToday ? kOrange : kGreen;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          day.count > 0 ? '${day.count}' : '',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: day.isToday ? kOrange : kGreen),
        ),
        const SizedBox(height: 4),
        Container(
          width: 18,
          height: barH,
          decoration: BoxDecoration(
            color: day.isFuture ? Colors.transparent : color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        const SizedBox(height: 8),
        Text(day.label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
                color: day.isToday ? kOrange : kMuted)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;

  const _MetricCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: kDark)),
          const SizedBox(height: 2),
          Text('$label · $sub',
              maxLines: 2,
              style: const TextStyle(fontSize: 12.5, color: kMuted, height: 1.3)),
        ],
      ),
    );
  }
}

typedef _WeakRow = ({Book book, Unit unit, Item item, double score});

class _WeakCard extends StatelessWidget {
  final _WeakRow data;
  final String where;
  final VoidCallback onTap;

  const _WeakCard({
    required this.data,
    required this.where,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final score = data.score.round();
    return SafeTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadius),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                data.item.imageAsset,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(Icons.image_not_supported_outlined,
                      size: 20, color: kMuted),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.item.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: kDark)),
                  const SizedBox(height: 2),
                  Text(where,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: kMuted)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('$score 分',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kOrange)),
          ],
        ),
      ),
    );
  }
}
