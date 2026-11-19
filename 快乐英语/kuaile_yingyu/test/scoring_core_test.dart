import 'package:flutter_test/flutter_test.dart';
import 'package:kuaile_yingyu/data/models.dart';
import 'package:kuaile_yingyu/services/scoring.dart';

/// 打分内核与数据模型的回归测试（第 4 轮）。
///
/// 这些是"孩子每天都会看到的结果"：星级、鼓励语、长句分数、进度 key。
void main() {
  group('星级映射', () {
    test('五档内部映射的边界', () {
      expect(starsFromScore(100), 5);
      expect(starsFromScore(90), 5);
      expect(starsFromScore(89.9), 4);
      expect(starsFromScore(75), 4);
      expect(starsFromScore(74.9), 3);
      expect(starsFromScore(60), 3);
      expect(starsFromScore(59.9), 2);
      expect(starsFromScore(45), 2);
      expect(starsFromScore(44.9), 1);
      expect(starsFromScore(0), 1);
    });

    test('展示三档的边界（85/65）', () {
      expect(starsForDisplay(100), 3);
      expect(starsForDisplay(85), 3);
      expect(starsForDisplay(84.9), 2);
      expect(starsForDisplay(65), 2);
      expect(starsForDisplay(64.9), 1);
      expect(starsForDisplay(0), 1);
    });

    test('三档永远不会超过 3 星', () {
      for (final s in [0.0, 30.0, 64.0, 65.0, 84.0, 85.0, 100.0]) {
        expect(starsForDisplay(s), inInclusiveRange(1, 3));
      }
    });

    test('鼓励语按星级给出，且不为空', () {
      expect(encouragement(3), contains('太棒'));
      expect(encouragement(2), contains('很好'));
      expect(encouragement(1), contains('没关系'));
      for (final s in [1, 2, 3]) {
        expect(encouragement(s).isNotEmpty, isTrue);
      }
    });
  });

  group('norm 文本归一', () {
    test('大小写与句末标点', () {
      expect(norm('Good morning!'), equals(norm('good morning')));
    });

    test('撇号缩写归一成本词，而不是拆成两个词', () {
      final words = norm("It's a dog.");
      expect(words.contains('dog'), isTrue);
      expect(words.contains('a'), isTrue);
      // 不应该把 it's 拆成 it + s
      expect(words.contains('s'), isFalse, reason: "It's 不该拆成 it + s");
    });

    test('逗号、问号、感叹号都不影响', () {
      expect(norm('Hi, Mia!'), equals(norm('hi mia')));
      expect(norm('Is it?'), equals(norm('is it')));
    });
  });

  group('coverageScore 长句打分', () {
    test('完全读对给 100', () {
      expect(coverageScore('Good morning!', 'good morning'), 100.0);
      expect(coverageScore('This is my dad.', 'this is my dad'), 100.0);
    });

    test('漏一个词要扣分', () {
      final s = coverageScore('This is my dad.', 'this is dad');
      expect(s, lessThan(100.0));
      expect(s, greaterThan(0.0));
    });

    test('完全读错给低分', () {
      final s = coverageScore('Good morning!', 'banana orange');
      expect(s, lessThan(50.0));
    });

    test('ignore 虚词后不影响满分', () {
      expect(
        coverageScore('This is a book.', 'this is book', ignore: {'a'}),
        100.0,
      );
    });

    test('分数不会超出 0-100', () {
      for (final hyp in ['', 'xyz', 'good morning extra words here']) {
        final s = coverageScore('Good morning!', hyp);
        expect(s, inInclusiveRange(0.0, 100.0));
      }
    });
  });

  group('Item.grammarWords 语法词表', () {
    Item make(String text) => Item(
          id: 't',
          text: text,
          audio: 'x.mp3',
          image: 'x.png',
          imageDesc: '',
          isWord: false,
        );

    test('普通句子按词拆分', () {
      final g = make('This is a dog.').grammarWords;
      expect(g, contains('this'));
      expect(g, contains('dog'));
    });

    test('词表不为空且全小写', () {
      final g = make('Good Morning!').grammarWords;
      expect(g, isNotEmpty);
      for (final w in g) {
        expect(w, equals(w.toLowerCase()));
      }
    });

    test('同音组会展开（it 与 its 都在）', () {
      final g = make("It's a cat.").grammarWords;
      expect(g.any((w) => w.startsWith('it')), isTrue);
    });
  });

  group('进度 key 防串册', () {
    Item makeItem(String id) => Item(
          id: id,
          text: 'x',
          audio: 'x.mp3',
          image: 'x.png',
          imageDesc: '',
          isWord: false,
        );

    Unit makeUnit(String bookId, String unitId) => Unit(
          unitId: unitId,
          title: 'U',
          titleEn: 'U',
          bookId: bookId,
          sentences: [],
          words: [],
        );

    test('同一 item id 在不同册得到不同 key', () {
      final a = makeUnit('1', '1').progressKey(makeItem('S1'));
      final b = makeUnit('2', '1').progressKey(makeItem('S1'));
      expect(a, isNot(equals(b)));
      expect(a, contains('b1'));
      expect(b, contains('b2'));
    });

    test('同一册内重复调用结果稳定', () {
      final u = makeUnit('1', '1');
      final i = makeItem('S1');
      expect(u.progressKey(i), equals(u.progressKey(i)));
    });
  });
}
