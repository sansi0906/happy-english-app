import 'package:flutter/material.dart';

import '../data/content_loader.dart';
import '../data/models.dart';
import '../main.dart';
import '../widgets/safe_tap.dart';
import 'book_page.dart';
import 'settings_page.dart';

/// 首页 V2：年级选择改成两列网格，一屏看全，不再让家长滚半天。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ContentData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ContentLoader.load();
      if (mounted) {
        setState(() {
          _data = d;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: kBgColor,
        body: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: kBgColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: kOrange, size: 60),
                const SizedBox(height: 16),
                const Text('内容加载失败',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: kDark)),
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(fontSize: 16, color: kMuted),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _load();
                  },
                  child: const Text('重新加载'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data!;
    final grades = [
      for (final g in data.gradeSupport)
        (g, _gradeName(g), _booksLabel(data, g), _gradeColor(g), _gradeIcon(g)),
    ];

    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：标题 + 设置
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: kGreenSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('快乐英语',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: kGreen)),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '设置',
                    icon: const Icon(Icons.settings_outlined,
                        color: kDark, size: 28),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('今天学哪一册？',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: kDark,
                      height: 1.2)),
              const SizedBox(height: 6),
              const Text('点年级，再选上册或下册',
                  style: TextStyle(fontSize: 17, color: kMuted)),
              const SizedBox(height: 22),

              // 年级网格：两列
              LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - 14) / 2;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final g in grades)
                        SizedBox(
                          width: w,
                          child: _GradeTile(
                            label: g.$2,
                            sub: g.$3,
                            color: g.$4,
                            icon: g.$5,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BookSelectorPage(grade: g.$1, data: data),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: kLine),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kOrangeSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lightbulb_outline,
                          color: kOrange, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        '每单元三步：先听读课文，再学单词，最后跟读打分。',
                        style: TextStyle(fontSize: 17, color: kDark, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _gradeName(String g) {
    const names = {
      '1': '一年级',
      '2': '二年级',
      '3': '三年级',
      '4': '四年级',
      '5': '五年级',
      '6': '六年级',
    };
    return names[g] ?? '$g 年级';
  }

  static String _booksLabel(ContentData data, String g) {
    final ids = data.booksOfGrade(g).map((b) => b.bookId).toList();
    if (ids.isEmpty) return '暂无内容';
    const cn = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'];
    final labels = ids.map((id) {
      final n = int.tryParse(id);
      return (n != null && n >= 1 && n <= 12) ? cn[n - 1] : id;
    }).join('、');
    return '第 $labels 册';
  }

  static Color _gradeColor(String g) {
    switch (g) {
      case '1':
        return kGreen;
      case '2':
        return kOrange;
      case '3':
        return kBlue;
      case '4':
        return const Color(0xFF9B8BD9);
      case '5':
        return const Color(0xFFE08FB0);
      default:
        return const Color(0xFF4FBFC0);
    }
  }

  static IconData _gradeIcon(String g) {
    switch (g) {
      case '1':
        return Icons.looks_one_outlined;
      case '2':
        return Icons.looks_two_outlined;
      case '3':
        return Icons.looks_3_outlined;
      case '4':
        return Icons.looks_4_outlined;
      case '5':
        return Icons.looks_5_outlined;
      default:
        return Icons.looks_6_outlined;
    }
  }
}

/// 册选择页：独立路由，支持边缘滑动返回年级选择
class BookSelectorPage extends StatelessWidget {
  final String grade;
  final ContentData data;

  const BookSelectorPage(
      {super.key, required this.grade, required this.data});

  static const _cnNum = [
    '一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'
  ];

  String _cnBookLabel(String bookId) {
    final n = int.tryParse(bookId);
    if (n != null && n >= 1 && n <= 12) return '第 ${_cnNum[n - 1]} 册';
    return bookId;
  }

  @override
  Widget build(BuildContext context) {
    final books = data.booksOfGrade(grade);
    final gradeName = {
          '1': '一年级',
          '2': '二年级',
          '3': '三年级',
          '4': '四年级',
          '5': '五年级',
          '6': '六年级',
        }[grade] ??
        '$grade 年级';

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: Text(gradeName),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Text('选择一册开始学习',
                style: TextStyle(fontSize: 18, color: kMuted)),
            const SizedBox(height: 16),
            for (final b in books)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _BookCard(
                  title: _cnBookLabel(b.bookId),
                  sub: '${b.units.length} 个单元 · ${b.bookNameEn}',
                  unitCount: b.units.length,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookPage(book: b),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(color: kLine),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kGreenSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule_rounded,
                        color: kGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '一册 6 个单元，一个单元大约 10 分钟。\n建议每天一个单元，跟着课本顺序走。',
                      style: TextStyle(
                          fontSize: 15, color: kMuted, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 年级瓦片：两列网格中的一块
class _GradeTile extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _GradeTile({
    required this.label,
    required this.sub,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadius),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kLine),
          boxShadow: kShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: kDark)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 15, color: kMuted)),
          ],
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final String title;
  final String sub;
  final int unitCount;
  final VoidCallback onTap;

  const _BookCard({
    required this.title,
    required this.sub,
    required this.unitCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kLine),
          boxShadow: kShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: kGreenSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: kGreen, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: kDark)),
                  const SizedBox(height: 4),
                  Text(sub, style: const TextStyle(fontSize: 15, color: kMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kMuted, size: 30),
          ],
        ),
      ),
    );
  }
}
