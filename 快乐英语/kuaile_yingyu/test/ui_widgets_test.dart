import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kuaile_yingyu/services/speech_service.dart';
import 'package:kuaile_yingyu/widgets/riddle_dialog.dart';
import 'package:kuaile_yingyu/widgets/score_widgets.dart';
import 'package:kuaile_yingyu/widgets/safe_tap.dart';

/// UI 层回归测试：只测纯展示组件（不碰数据库、不碰音频），
/// 目的是防止拆分/改样式时把孩子看到的关键信息（星级、分数、鼓励语）弄丢。
void main() {
  group('StarRow 星级渲染', () {
    testWidgets('没练过（0）只显示一颗空心星', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: StarRow(star5: 0, size: 20))),
      ));
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('满分（3）三颗实心', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: StarRow(star5: 3, size: 20))),
      ));
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border), findsNothing);
    });

    testWidgets('两颗星：2 实心 + 1 空心', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: StarRow(star5: 2, size: 20))),
      ));
      expect(find.byIcon(Icons.star), findsNWidgets(2));
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('老数据 5 档（star5=5）也只画三颗，不会溢出', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: StarRow(star5: 5, size: 20))),
      ));
      expect(find.byIcon(Icons.star), findsNWidgets(3));
    });
  });

  group('ScoreResultCard 成绩卡', () {
    SpeakResult make(double score, int stars) => SpeakResult(
          score: score,
          star: stars,
          displayStars: stars,
          grammarText: '',
          freeText: '',
        );

    testWidgets('0 分给“没听到声音”提示，而不是鼓励语', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ScoreResultCard(result: make(0, 1))),
      ));
      expect(find.text('没听到声音，靠近一点再试试！'), findsOneWidget);
      expect(find.text('没关系，听一听再试试！'), findsNothing);
      expect(find.text('0 分'), findsOneWidget);
    });

    testWidgets('三颗星显示满分鼓励语和分数', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ScoreResultCard(result: make(88, 3))),
      ));
      expect(find.text('太棒了！读得非常标准！'), findsOneWidget);
      expect(find.text('88 分'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border_rounded), findsNothing);
    });

    testWidgets('35–45 分额外给“读慢一点”的具体建议', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ScoreResultCard(result: make(40, 1))),
      ));
      expect(find.text('读慢一点、声音大一点，靠近手机再试一次'), findsOneWidget);
      expect(find.text('没关系，听一听再试试！'), findsOneWidget);
    });

    testWidgets('60 分不给“读慢一点”建议（只在 35–45 区间提示）', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ScoreResultCard(result: make(60, 1))),
      ));
      expect(find.text('读慢一点、声音大一点，靠近手机再试一次'), findsNothing);
      expect(find.text('60 分'), findsOneWidget);
    });
  });

  group('RiddleDialog 满分知识卡', () {
    Widget host({bool isLast = false}) => MaterialApp(
          home: Scaffold(
            body: RiddleDialog(
              index: 1,
              total: 3,
              category: '动物',
              question: '什么动物最爱问为什么？',
              answer: '猪（因为总是哼哼“为什么”）',
              isLast: isLast,
            ),
          ),
        );

    testWidgets('先出题目，答案要自己点出来', (tester) async {
      await tester.pumpWidget(host());
      expect(find.text('满分奖励 · 动物'), findsOneWidget);
      expect(find.text('什么动物最爱问为什么？'), findsOneWidget);
      expect(find.textContaining('答案：'), findsNothing);
      expect(find.text('看答案'), findsOneWidget);
    });

    testWidgets('点“看答案”后翻出答案，按钮变“下一题”', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('看答案'));
      await tester.pumpAndSettle();
      expect(find.textContaining('答案：猪'), findsOneWidget);
      expect(find.text('下一题'), findsOneWidget);
      expect(find.text('看答案'), findsNothing);
    });

    testWidgets('最后一题按钮写“完成”', (tester) async {
      await tester.pumpWidget(host(isLast: true));
      await tester.tap(find.text('看答案'));
      await tester.pumpAndSettle();
      expect(find.text('完成'), findsOneWidget);
    });
  });

  group('SafeTap 容错点击', () {
    testWidgets('正常单击只触发一次', (tester) async {
      var n = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SafeTap(onTap: () => n++, child: const Text('点我')),
          ),
        ),
      ));
      await tester.tap(find.text('点我'));
      await tester.pumpAndSettle();
      expect(n, 1);
    });

    testWidgets('按住不退（模拟丢 UP 事件）250ms 后兜底触发，且只一次', (tester) async {
      var n = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SafeTap(onTap: () => n++, child: const Text('点我')),
          ),
        ),
      ));
      final g = await tester.startGesture(tester.getCenter(find.text('点我')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(n, 1, reason: '兜底定时器应在 250ms 后触发');
      // 之后抬起手指，onTap 也不应再触发第二次
      await g.up();
      await tester.pumpAndSettle();
      expect(n, 1, reason: '_fired 去重，避免重复跳转');
    });
  });
}
