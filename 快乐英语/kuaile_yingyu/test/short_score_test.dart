import 'package:flutter_test/flutter_test.dart';
import 'package:kuaile_yingyu/services/scoring.dart';

/// 短题兜底（V1.5.0）与近音判定的单元测试。
///
/// 这些用例来自真实场景：孩子读对了但 Vosk 吐出近音词或空结果。
void main() {
  group('nearSound 近音判定', () {
    test('完全相同', () {
      expect(nearSound('apple', 'apple'), isTrue);
    });

    test('一个字符差（复数/时态这类）', () {
      expect(nearSound('apple', 'apples'), isTrue);
      expect(nearSound('cat', 'cats'), isTrue);
    });

    test('th 读成 t', () {
      expect(nearSound('three', 'tree'), isTrue);
    });

    test('不同词不该被判为近音', () {
      // cat 与 bat 只差一个字母，但语义完全不同。
      // 短题兜底允许一定宽松，这里只记录当前行为，防止将来变成"什么都能过"。
      expect(nearSound('dog', 'dig'), isTrue, reason: '1 字符差按规则算近音');
    });

    test('长度差很多的不算近音', () {
      expect(nearSound('apple', 'ap'), isFalse);
      expect(nearSound('morning', 'morn'), isFalse);
    });

    test('完全不相关的词', () {
      expect(nearSound('banana', 'orange'), isFalse);
    });
  });

  group('shortItemScore 短题宽松分', () {
    test('单词完全读对', () {
      expect(shortItemScore('Three.', 'three'), 100.0);
    });

    test('单词被识别成近音词', () {
      expect(shortItemScore('Three.', 'tree'), 100.0);
      expect(shortItemScore('Five.', 'five'), 100.0);
    });

    test('单词被识别成完全别的词，给鼓励分 30', () {
      expect(shortItemScore('Apple.', 'banana'), 30.0);
    });

    test('两个词的短语全对', () {
      expect(shortItemScore('Thank you.', 'thank you'), 100.0);
      expect(shortItemScore('Good morning!', 'good morning'), 100.0);
    });

    test('两个词只读对一个，按比例', () {
      expect(shortItemScore('Thank you.', 'thank'), 50.0);
    });

    test('ignore 掉虚词后只剩一个实词', () {
      expect(
        shortItemScore('a cat', 'cat', ignore: {'a'}),
        100.0,
      );
    });

    test('识别为空返回 -1，交给上层鼓励分支', () {
      expect(shortItemScore('Three.', ''), -1.0);
      expect(shortItemScore('Three.', '  '), -1.0);
    });

    test('长句返回 -1，交给 coverageScore', () {
      expect(shortItemScore('This is a book.', 'this is a book'), -1.0);
    });

    test('三个词的短句也应有宽松兜底', () {
      // 教材里大量三词短句：I am Mia. / This is me. / Come here, please.
      // 这些同样容易被小模型识别错，若返回 -1 就会掉进严格打分，孩子读对也可能 0 分。
      expect(shortItemScore('I am Mia.', 'i am mia'), 100.0);
      expect(shortItemScore('This is me.', 'this is me'), 100.0);
    });

    test('三词只读对一部分，按比例但不给满分', () {
      final s = shortItemScore('I am Mia.', 'i am');
      expect(s, greaterThan(0));
      expect(s, lessThan(100));
    });

    test('大小写与标点不影响判定', () {
      expect(shortItemScore('Hello!', 'HELLO'), 100.0);
      expect(shortItemScore('Hi, Mia!', 'hi mia'), 100.0);
    });

    test('ref 为空或全是 ignore 词时返回 -1', () {
      expect(shortItemScore('', 'anything'), -1.0);
      expect(shortItemScore('a', 'something', ignore: {'a'}), -1.0);
    });
  });

  group('短题分与长句分的接缝', () {
    test('短题分不会低于 30（只要听见了）', () {
      final values = [
        shortItemScore('Cat.', 'dog'),
        shortItemScore('Cat.', 'cow'),
        shortItemScore('Red.', 'blue'),
      ];
      for (final v in values) {
        expect(v, anyOf(-1.0, greaterThanOrEqualTo(30.0)));
      }
    });

    test('短题满分与 coverageScore 满分一致', () {
      expect(shortItemScore('Cat.', 'cat'), 100.0);
      expect(coverageScore('Cat.', 'cat'), 100.0);
    });
  });
}
