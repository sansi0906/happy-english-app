import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuaile_yingyu/data/content_loader.dart';

/// 内容与媒资完整性测试。
///
/// 这类问题只有用户点到"某个句子点了没声音"才会发现，
/// 所以在单元测试阶段就把 12 册全部扫一遍。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('content.json 可解析，册数与单元数合理', () async {
    final data = await ContentLoader.load();
    expect(data.books.length, greaterThan(0));
    expect(data.books.length, 12, reason: '一至六年级共 12 册');

    for (final b in data.books) {
      expect(b.units.isNotEmpty, isTrue, reason: '第 ${b.bookId} 册没有单元');
      for (final u in b.units) {
        expect(u.allItems.isNotEmpty, isTrue,
            reason: '第 ${b.bookId} 册 ${u.title} 没有内容');
      }
    }
  });

  test('每个条目都有非空 text / audio / image', () async {
    final data = await ContentLoader.load();
    final bad = <String>[];
    for (final b in data.books) {
      for (final u in b.units) {
        for (final it in u.allItems) {
          if (it.text.trim().isEmpty) bad.add('${b.bookId}/${it.id} text 为空');
          if (it.audio.trim().isEmpty) bad.add('${b.bookId}/${it.id} audio 为空');
          if (it.image.trim().isEmpty) bad.add('${b.bookId}/${it.id} image 为空');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.take(10).join('; '));
  });

  test('音频文件在磁盘上全部存在', () async {
    final data = await ContentLoader.load();
    final missing = <String>[];
    var total = 0;
    for (final b in data.books) {
      for (final u in b.units) {
        for (final it in u.allItems) {
          total++;
          final f = File(it.audioAsset);
          if (!f.existsSync() || f.lengthSync() == 0) {
            missing.add(it.audioAsset);
          }
        }
      }
    }
    expect(total, greaterThan(0));
    expect(missing, isEmpty,
        reason: '缺失 ${missing.length} 条音频，例如 ${missing.take(5).join(', ')}');
  });

  test('图片文件在磁盘上全部存在', () async {
    final data = await ContentLoader.load();
    final missing = <String>[];
    for (final b in data.books) {
      for (final u in b.units) {
        for (final it in u.allItems) {
          final f = File(it.imageAsset);
          if (!f.existsSync() || f.lengthSync() == 0) {
            missing.add(it.imageAsset);
          }
        }
      }
    }
    expect(missing, isEmpty,
        reason: '缺失 ${missing.length} 张图，例如 ${missing.take(5).join(', ')}');
  });

  test('条目 id 在同一册内唯一', () async {
    final data = await ContentLoader.load();
    for (final b in data.books) {
      final ids = <String>{};
      final dup = <String>[];
      for (final u in b.units) {
        for (final it in u.allItems) {
          if (!ids.add('${u.unitId}/${it.id}')) dup.add('${u.unitId}/${it.id}');
        }
      }
      expect(dup, isEmpty, reason: '第 ${b.bookId} 册重复 id: ${dup.take(5)}');
    }
  });

  test('content.json 是合法 JSON 且体积在合理范围', () {
    final f = File('assets/data/content.json');
    expect(f.existsSync(), isTrue);
    final bytes = f.lengthSync();
    expect(bytes, greaterThan(10 * 1024), reason: '内容文件过小，疑似被截断');
    expect(bytes, lessThan(20 * 1024 * 1024));
    expect(() => jsonDecode(f.readAsStringSync()), returnsNormally);
  });
}
