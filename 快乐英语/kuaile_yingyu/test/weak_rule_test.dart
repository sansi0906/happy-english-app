import 'package:flutter_test/flutter_test.dart';

import 'package:kuaile_yingyu/data/progress_db.dart';
import 'package:kuaile_yingyu/services/scoring.dart';

void main() {
  group('错题本口径', () {
    test('合格线必须正好是三档三星的门槛（家长口径：拿到三星才出队）', () {
      expect(ProgressDb.passScore, 85);
      expect(starsForDisplay(ProgressDb.passScore), 3,
          reason: '85 分必须显示三星，否则「练到三星就消失」对不上');
      expect(starsForDisplay(ProgressDb.passScore - 1), 2,
          reason: '84 分只能是两星，仍留在错题本');
    });

    test('三星门槛上下两侧的分档', () {
      expect(starsForDisplay(100), 3);
      expect(starsForDisplay(85), 3);
      expect(starsForDisplay(84.9), 2);
      expect(starsForDisplay(65), 2);
      expect(starsForDisplay(64.9), 1);
      expect(starsForDisplay(0), 1);
    });
  });
}
