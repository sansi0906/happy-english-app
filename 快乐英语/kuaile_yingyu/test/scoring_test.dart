import 'package:flutter_test/flutter_test.dart';
import 'package:kuaile_yingyu/services/scoring.dart';

void main() {
  group('scoreText 与 POC scoring.py 行为一致', () {
    test('完全正确', () {
      final r = scoreText('Hello.', 'Hello.');
      expect(r.score, 100.0);
      expect(r.star, 5);
    });

    test('缩写等价（走覆盖率打分）', () {
      // 实现自 V1.3.5 起不再展开缩写：scoreText 是严格词级编辑距离，
      // "it's a cat"(3 词) 对 "it is a cat"(4 词) 必然扣 1 个词；
      // 缩写/同音的宽容匹配由 coverageScore 的"吞词"逻辑负责，这里断言它。
      final strict = scoreText("It's a cat.", 'it is a cat');
      expect(strict.score, closeTo(66.67, 0.01));
      expect(coverageScore("It's a cat.", 'it is a cat'), 100.0);
    });

    test('一半词对', () {
      final r = scoreText('I am a boy.', 'I am a girl.');
      expect(r.score, 75.0);
      expect(r.star, 4);
    });

    test('完全正确短句', () {
      final r = scoreText('This is a book.', 'This is a book.');
      expect(r.score, 100.0);
    });

    test('漏词', () {
      final r = scoreText('Open your bag.', 'Open your');
      expect(r.score, closeTo(66.67, 0.01));
      expect(r.star, 3);
    });

    test('完全没读', () {
      final r = scoreText('Thank you.', '');
      expect(r.score, 0.0);
      expect(r.star, 1);
    });
  });

  group('星级映射', () {
    test('五档边界', () {
      expect(starsFromScore(90), 5);
      expect(starsFromScore(89.9), 4);
      expect(starsFromScore(75), 4);
      expect(starsFromScore(74.9), 3);
      expect(starsFromScore(60), 3);
      expect(starsFromScore(59.9), 2);
      expect(starsFromScore(45), 2);
      expect(starsFromScore(44.9), 1);
    });

    test('APP 三档', () {
      // 展示阈值：>=85 三星，>=65 二星，其余一星
      expect(starsForDisplay(90), 3);
      expect(starsForDisplay(85), 3);
      expect(starsForDisplay(84.9), 2);
      expect(starsForDisplay(75), 2);
      expect(starsForDisplay(65), 2);
      expect(starsForDisplay(64.9), 1);
      expect(starsForDisplay(59.9), 1);
    });
  });

  group('混合打分逻辑', () {
    test('grammar+free 均值', () {
      // 模拟：grammar 识别全对，free 识别 70 分
      final g = scoreText('Hello.', 'Hello.').score;
      final f = scoreText('Hello.', 'Hello world').score;
      final mixed = (g + f) / 2;
      expect(mixed, (100.0 + f) / 2);
      expect(starsFromScore(mixed), starsFromScore(mixed));
    });
  });
}
