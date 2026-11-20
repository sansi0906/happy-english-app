import 'package:flutter_test/flutter_test.dart';

import 'package:kuaile_yingyu/data/content_index.dart';
import 'package:kuaile_yingyu/data/models.dart';

/// 错题本/周报共用的小工具函数：册号、年级名、"在哪"文案。
/// 这些字符串会直接显示给孩子家长，所以边界要固定住。
void main() {
  group('cnBookNum 册号转中文', () {
    test('1-12 正常', () {
      expect(cnBookNum('1'), '一');
      expect(cnBookNum('2'), '二');
      expect(cnBookNum('10'), '十');
      expect(cnBookNum('12'), '十二');
    });

    test('越界或非数字返回空，不抛异常', () {
      expect(cnBookNum('0'), '');
      expect(cnBookNum('13'), '');
      expect(cnBookNum('abc'), '');
      expect(cnBookNum(''), '');
    });
  });

  group('gradeName 年级名', () {
    test('1-6 正常', () {
      const expectNames = ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级'];
      for (var i = 1; i <= 6; i++) {
        expect(gradeName('$i'), expectNames[i - 1]);
      }
    });

    test('未知年级兜底不崩', () {
      expect(gradeName('7'), '7 年级');
      expect(gradeName(''), ' 年级');
    });
  });

  group('whereLabel 位置文案', () {
    Item item({String text = 'I have a toy car.', bool isWord = false}) => Item(
          id: 'S1',
          text: text,
          audio: 'b1_u1_s1.mp3',
          image: 'b1_u1_s1.png',
          imageDesc: '',
          isWord: isWord,
        );

    Unit unit({String titleEn = 'Toys'}) => Unit(
          unitId: '1',
          title: '玩具',
          titleEn: titleEn,
          bookId: '2',
          sentences: const [],
          words: const [],
        );

    test('一年级第二册 + 英文单元名', () {
      final pos = (
        book: Book(
          bookId: '2',
          bookName: '下册',
          bookNameEn: 'Book 1B',
          grade: '1',
          units: const [],
        ),
        unit: unit(),
        item: item(),
      );
      expect(whereLabel(pos), '一年级 第二册 · Toys');
    });

    test('单元没有英文名时退回中文标题', () {
      final pos = (
        book: Book(
          bookId: '1',
          bookName: '上册',
          bookNameEn: 'Book 1',
          grade: '1',
          units: const [],
        ),
        unit: unit(titleEn: ''),
        item: item(),
      );
      expect(whereLabel(pos), '一年级 第一册 · 玩具');
    });

    test('册号异常时不拼接空"第册"，仍能显示年级', () {
      final pos = (
        book: Book(
          bookId: 'x',
          bookName: '上册',
          bookNameEn: '',
          grade: '2',
          units: const [],
        ),
        unit: unit(titleEn: 'Food'),
        item: item(),
      );
      expect(whereLabel(pos), '二年级 · Food');
    });
  });
}
