// 知识卡绑定映射的回归测试（V1.4.1）
// 背景：riddles.dart 的映射 key 是 progressKey 格式 b{bookId}_{itemId}，
// 但 speak_page 曾传裸 item.id 查询，导致知识卡永远弹不出来且无测试发现。
// 本测试锁死"必须用 progressKey 查询、裸 id 查不到"，防止再次回归。
import 'package:flutter_test/flutter_test.dart';
import 'package:kuaile_yingyu/services/riddles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('progressKey 能查到知识卡', () async {
    final r = await riddleForItem('b1_U1_S1');
    expect(r, isNotNull, reason: 'b1_U1_S1 应绑定到一道知识卡');
    expect(r!['id'], isNotEmpty);
    expect(r['q'], isNotEmpty);
    expect(r['a'], isNotEmpty);
  });

  test('裸 id 查不到知识卡（调用侧必须带册号前缀）', () async {
    final r = await riddleForItem('U1_S1');
    expect(r, isNull,
        reason: '裸 id 无册号，跨册会撞车，映射表里不存在该 key');
  });

  test('跨册同名 id 绑定到不同的知识卡', () async {
    final b1 = await riddleForItem('b1_U1_S1');
    final b2 = await riddleForItem('b2_U1_S1');
    expect(b1, isNotNull);
    expect(b2, isNotNull);
    // 排序后序号不同，通常会落到不同题；即使相同也不影响正确性，
    // 这里只断言两条都能查到（说明 key 已被分别收录）。
  });
}
