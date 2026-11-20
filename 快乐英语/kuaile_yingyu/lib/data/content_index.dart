import '../data/content_loader.dart';
import '../data/models.dart';

/// 一个跟读项在教材里的位置
typedef ItemPos = ({Book book, Unit unit, Item item});

/// 教材位置索引：`progressKey` → (册, 单元, 句/词)
///
/// 进度库里只存 key（如 `b1_U1_S1`），要给家长看"这是哪一册哪一课"就得反查。
/// 复习页和周报页都要用，放这里避免各写一份。
Future<Map<String, ItemPos>> buildContentIndex() async {
  final data = await ContentLoader.load();
  final index = <String, ItemPos>{};
  for (final b in data.books) {
    for (final u in b.units) {
      for (final it in u.allItems) {
        index[u.progressKey(it)] = (book: b, unit: u, item: it);
      }
    }
  }
  return index;
}

/// 册号转中文：1 → 一（超出 1-12 返回空串）
String cnBookNum(String bookId) {
  const cn = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'];
  final n = int.tryParse(bookId);
  if (n == null || n < 1 || n > 12) return '';
  return cn[n - 1];
}

/// 年级码转中文名：'1' → 一年级
String gradeName(String g) {
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

/// 一行"在哪"的说明：一年级 第二册 · Toys
String whereLabel(ItemPos pos) {
  final vol = cnBookNum(pos.book.bookId);
  final unitTitle =
      pos.unit.titleEn.isNotEmpty ? pos.unit.titleEn : pos.unit.title;
  final head = vol.isEmpty ? gradeName(pos.book.grade) : '${gradeName(pos.book.grade)} 第$vol册';
  return '$head · $unitTitle';
}
