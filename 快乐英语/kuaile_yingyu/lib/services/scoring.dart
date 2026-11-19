/// 文本比对打分：POC 结论采用的核心算法（与 POC/scripts/scoring.py 一致）
/// norm → 词级 Levenshtein → WER → 0-100 分 → 五档星级
library;

/// 同音/缩略等价组（跟读打分宽容匹配用）
/// 孩子读 "it's a dog"，ASR 可能输出 its / it is / it，都算标准。
const List<Set<String>> _soundGroups = [
  {'it\'s', 'its', 'it', 'is'},
  {'you\'re', 'your', 'you', 'are'},
  {'they\'re', 'their', 'there', 'they', 'are'},
  {'we\'re', 'we', 'are'},
  {'he\'s', 'his', 'he', 'is'},
  {'she\'s', 'she', 'is'},
  {'who\'s', 'whose', 'who', 'is'},
  {'where\'s', 'where', 'is'},
  {'what\'s', 'what', 'is'},
  {'there\'s', 'there', 'is'},
  {'here\'s', 'here', 'is'},
  {'that\'s', 'thats', 'that', 'is'},
  {'how\'s', 'hows', 'how', 'is'},
  {'mustn\'t', 'mustnt', 'must', 'not'},
  {'i\'m', 'im', 'i', 'am', 'eye'},
  {'i\'ve', 'i', 'have'},
  {'we\'ve', 'we', 'have'},
  {'you\'ve', 'you', 'have'},
  {'they\'ve', 'they', 'have'},
  {'don\'t', 'dont', 'do', 'not'},
  {'doesn\'t', 'doesnt', 'does', 'not'},
  {'can\'t', 'cant', 'can', 'not'},
  {'won\'t', 'wont', 'will', 'not'},
  {'isn\'t', 'isnt', 'is', 'not'},
  {'aren\'t', 'arent', 'are', 'not'},
  {'wasn\'t', 'wasnt', 'was', 'not'},
  {'weren\'t', 'werent', 'were', 'not'},
  {'didn\'t', 'didnt', 'did', 'not'},
  {'couldn\'t', 'couldnt', 'could', 'not'},
  {'wouldn\'t', 'wouldnt', 'would', 'not'},
  {'shouldn\'t', 'shouldnt', 'should', 'not'},
  {'let\'s', 'lets', 'let', 'us'},
  {'i\'ll', 'ill', 'i', 'will'},
  {'you\'ll', 'youll', 'you', 'will'},
  {'we\'ll', 'well', 'we', 'will'},
  {'they\'ll', 'theyll', 'they', 'will'},
  {'he\'ll', 'hell', 'he', 'will'},
  {'she\'ll', 'shell', 'she', 'will'},
  // 小学教材常见同音词（V1.3.5）
  {'to', 'two', 'too'},
  {'for', 'four'},
  {'red', 'read'},
  {'no', 'know'},
  {'nose', 'knows'},
  {'see', 'sea'},
  {'by', 'buy', 'bye'},
  {'our', 'hour'},
  {'one', 'won'},
  {'son', 'sun'},
  {'right', 'write'},
  {'new', 'knew'},
  {'hi', 'high'},
  {'be', 'bee'},
  {'here', 'hear'},
  {'meet', 'meat'},
  {'week', 'weak'},
  {'pair', 'pear'},
  {'blue', 'blew'},
  {'ate', 'eight'},
  // V1.3.5 补扫：题库出现的其余同音/所有格场景
  {'aunt', 'aren\'t', 'arent'},
  {'are', 'our'},
  {'you', 'ewe', 'yew'},
  {'where', 'wear'},
  {'way', 'weigh'},
  {'flower', 'flour'},
  {'wait', 'weight'},
  {'hair', 'hare'},
  {'tail', 'tale'},
  {'plane', 'plain'},
  {'weather', 'whether'},
  {'bear', 'bare'},
  {'break', 'brake'},
  {'morning', 'mourning'},
  {'children\'s', 'children', 'childrens'},
  {'father\'s', 'father', 'fathers'},
  {'mother\'s', 'mother', 'mothers'},
  {'women\'s', 'women', 'womens'},
];

/// 两个词是否发音等价（同组即等价）
bool sameGroup(String a, String b) {
  if (a == b) return true;
  for (final g in _soundGroups) {
    if (g.contains(a) && g.contains(b)) return true;
  }
  return false;
}

/// 返回词所在同音组的全部成员（含自身）；无组则只有自身
Set<String> soundGroupMembers(String w) {
  for (final g in _soundGroups) {
    if (g.contains(w)) return g;
  }
  return {w};
}

/// lowercase + 弯引号归一 + 去标点 + 分词
/// V1.3.5：不再展开缩写，保留原词（it's 保持 it's），
/// 等价匹配交给 sameGroup（it's/its/it is 互相算对）。
List<String> norm(String s) {
  s = s.toLowerCase();
  // 弯引号（教材文本常用 ’ ‘）归一为 ASCII 撇号
  s = s.replaceAll('’', "'").replaceAll('‘', "'");
  // V1.4.0：grammar 识别器的 [unk] 是"没识别出目标词"的占位符，
  // 不是孩子读出的词，必须剔除，否则会被当成无关词扣分。
  s = s.replaceAll('[unk]', ' ');
  s = s.replaceAll(RegExp(r"[^a-z0-9' ]"), ' ');
  return s
      .split(RegExp(r'\s+'))
      // V1.4.1：去掉词首尾残留的引号（教材里的 'No Feeding' 会被拆成 'no / feeding'）
      .map((w) => w.replaceAll(RegExp(r"^'+|'+$"), ''))
      .where((w) => w.isNotEmpty && w != 'unk')
      .toList();
}

/// 词级编辑距离（DP）
int levenshtein(List<String> a, List<String> b) {
  final m = a.length, n = b.length;
  final dp = List.generate(m + 1, (i) => List.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= n; j++) {
    dp[0][j] = j;
  }
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      final cost = sameGroup(a[i - 1], b[j - 1]) ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
  }
  return dp[m][n];
}

/// 词级对齐：返回 ref 每词是否被匹配（读对）
List<bool> levAlign(List<String> ref, List<String> hyp) {
  final m = ref.length, n = hyp.length;
  final dp = List.generate(m + 1, (i) => List.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= n; j++) {
    dp[0][j] = j;
  }
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      final cost = sameGroup(ref[i - 1], hyp[j - 1]) ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
  }
  var i = m, j = n;
  final matched = List<bool>.filled(m, false);
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + (sameGroup(ref[i - 1], hyp[j - 1]) ? 0 : 1)) {
      if (sameGroup(ref[i - 1], hyp[j - 1])) matched[i - 1] = true;
      i--;
      j--;
    } else if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
      i--;
    } else {
      j--;
    }
  }
  return matched;
}

/// 返回 (分数, 星级, WER, 编辑距离, 目标词数, 识别词数)
/// [ignore]：ASR 词表里根本不存在的词（人名/合成词），不参与评测（V1.4.0）
({double score, int star, double wer, int dist, int refLen, int hypLen})
    scoreText(String ref, String hyp, {Set<String> ignore = const {}}) {
  final raw = norm(ref);
  if (raw.isEmpty) {
    return (score: 100.0, star: 5, wer: 0.0, dist: 0, refLen: 0, hypLen: norm(hyp).length);
  }
  final r = ignore.isEmpty ? raw : raw.where((w) => !ignore.contains(w)).toList();
  if (r.isEmpty) {
    // 目标词全部是模型词表外的词，无法按文本评测，交给上层走保底分
    return (score: -1.0, star: 1, wer: 0.0, dist: 0, refLen: 0, hypLen: norm(hyp).length);
  }
  final h = norm(hyp);
  final dist = levenshtein(r, h);
  final wer = dist / r.length;
  final score = (1.0 - wer) * 100.0 < 0 ? 0.0 : (1.0 - wer) * 100.0;
  return (
    score: score,
    star: starsFromScore(score),
    wer: wer,
    dist: dist,
    refLen: r.length,
    hypLen: h.length,
  );
}

/// 覆盖率打分（V1.1.1 修复）：hyp 全局去重后按序匹配 ref 词，
/// 修复 grammar 识别重复词导致严格编辑距离误判 0 分的问题。
/// V1.3.5：匹配用 sameGroup，支持三种情况：
///   1) 吞词：hyp 一个词吃掉 ref 连续多个同组词（we're 吃掉 "we are"）
///   2) 漏读：ref 词没读（跳过最多 2 个不匹配 ref 词继续找）
///   3) 多读：hyp 多出的词直接跳过
/// V1.3.7（测试审计修复）：多读/乱读的无关词不再白送，每个无关词扣 10 分，
///   消除"目标词全读对后乱读一堆词仍 100 分"的漏洞。
/// 完全乱读（[unk] 占位）覆盖率为 0 → 0 分；目标词全部命中且无乱读 → 100 分。
/// [ignore]：Vosk 词表外的词（人名/合成词）不计入分母，否则孩子读对也永远少一个词（V1.4.0）。
double coverageScore(String ref, String hyp, {Set<String> ignore = const {}}) {
  final raw = norm(ref);
  if (raw.isEmpty) return 100.0;
  final r0 = ignore.isEmpty ? raw : raw.where((w) => !ignore.contains(w)).toList();
  if (r0.isEmpty) return -1.0; // 目标词全在词表外，无法按文本评测
  // V1.4.1：连续重复词合并（ha ha ha ha 这类拟声/叠词，识别器常并成一个，
  // 合并后不再因"模型少认一个"扣分）
  final r = <String>[];
  for (final w in r0) {
    if (r.isNotEmpty && r.last == w) continue;
    r.add(w);
  }
  // V1.4.1：hyp 里的 OOV 词（人名等）直接忽略，不能再被当成"多读"扣 10 分
  final h0 = norm(hyp);
  final h = ignore.isEmpty ? h0 : h0.where((w) => !ignore.contains(w)).toList();
  final uniq = <String>[];
  // V1.4.1：去重时按 ref 中的出现次数放宽（"for you, for you" 这类重复短语
  // 不能被并成一次，否则后半段永远匹配不上）
  for (final w in h) {
    final refCount = r.where((x) => sameGroup(x, w)).length;
    final used = uniq.where((u) => sameGroup(u, w)).length;
    if (used < refCount) uniq.add(w);
  }
  final hit = List<bool>.filled(r.length, false); // 记录 ref 哪些位置命中
  var matched = 0;
  var bad = 0; // 无关词（多读/乱读）数量，每个扣 10 分
  var rp = 0;
  var wp = 0;
  while (wp < uniq.length) {
    final wh = uniq[wp];
    // ref 词已全部匹配完，剩余 hyp 词全是无关词（V1.3.7 修复：此前循环提前退出漏计）
    if (rp >= r.length) {
      bad++;
      wp++;
      continue;
    }
    // 1) 先试单字匹配（V1.4.1：原实现从 k=3 贪心吞词，is/it 同组时
    //    一个 is 会吃掉 "is it" 两个目标词，多出的 it 反被判多读）；单字不成再吞词
    var consumed = 0;
    for (final k in const [1, 2, 3]) {
      if (rp + k <= r.length) {
        var allSame = true;
        for (var t = 0; t < k; t++) {
          if (!sameGroup(r[rp + t], wh)) {
            allSame = false;
            break;
          }
        }
        if (allSame) {
          consumed = k;
          break;
        }
      }
    }
    if (consumed > 0) {
      for (var t = 0; t < consumed; t++) {
        hit[rp + t] = true;
      }
      matched += consumed;
      rp += consumed;
      wp++;
      continue;
    }
    // 2) 漏读：wh 与当前 ref 词不同组，允许跳过最多 2 个漏读词再匹配
    var found = false;
    for (var skip = 1; skip <= 2 && rp + skip < r.length; skip++) {
      if (sameGroup(r[rp + skip], wh)) {
        rp += skip; // 跳过的 ref 词视为漏读，不计分
        hit[rp] = true;
        matched++;
        rp++;
        wp++;
        found = true;
        break;
      }
    }
    if (!found) {
      // 2.5) 合并读（V1.4.0）：识别器把合成词拆成两段（class room → classroom、
      // good bye → goodbye、snow man → snowman、black board → blackboard 等），
      // 孩子读的是完整的合成词，应算命中，而不是扣 20 分。
      if (wp + 1 < uniq.length) {
        final merged = wh + uniq[wp + 1];
        if (sameGroup(r[rp], merged) || sameGroup(r[rp], uniq[wp + 1] + wh)) {
          hit[rp] = true;
          matched++;
          rp++;
          wp += 2;
          continue;
        }
      }
      // 3) 多读/错词：wh 无法匹配，记为无关词（去重后计数），跳过该 hyp 词
      bad++;
      wp++;
    }
  }
  // V1.4.1：虚词漏读不计入分母。正常语速下 a/an/the/and/of 会弱读，
  // 识别器常直接漏掉，不能让孩子为模型的能力边界买单。
  const weak = {'a', 'an', 'the', 'and', 'of'};
  var denom = r.length;
  for (var i = 0; i < r.length; i++) {
    if (!hit[i] && weak.contains(r[i])) denom--;
  }
  if (denom <= 0) denom = r.length;
  var base = matched / denom * 100.0;
  var score = base - bad * 10.0;
  return score < 0 ? 0.0 : score;
}

/// POC 五档映射：>=90 5星；75-89 4星；60-74 3星；45-59 2星；<45 1星
int starsFromScore(double score) {
  if (score >= 90) return 5;
  if (score >= 75) return 4;
  if (score >= 60) return 3;
  if (score >= 45) return 2;
  return 1;
}

/// APP 内展示用简化三档（需求文档：不打击孩子）
int starsForDisplay(double score) {
  if (score >= 85) return 3;
  if (score >= 65) return 2;
  return 1;
}

/// 鼓励语（按星级）
String encouragement(int displayStars) {
  switch (displayStars) {
    case 3:
      return '太棒了！读得非常标准！';
    case 2:
      return '很好！再读一遍会更棒！';
    default:
      return '没关系，听一听再试试！';
  }
}

/// 字符级编辑距离
int _charDistance(String a, String b) {
  final m = a.length, n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (j) => j);
  var cur = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    cur[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  return prev[n];
}

/// 拼音化的子音归并：孩子把 th 读成 t/d/f、把 ph 读成 f、把 ck 读成 k 很常见
String _soundCanon(String s) {
  var w = s;
  w = w.replaceAll('th', 't');
  w = w.replaceAll('ph', 'f');
  w = w.replaceAll('ck', 'k');
  w = w.replaceAll('wh', 'w');
  w = w.replaceAll('sh', 's');
  w = w.replaceAll('ch', 'c');
  w = w.replaceAll('ou', 'u');
  w = w.replaceAll('ee', 'i');
  w = w.replaceAll('oo', 'u');
  return w;
}

/// 近音判定：完全相同、1 个字符差、或归并后相同/1 个字符差
bool nearSound(String a, String b) {
  if (a == b) return true;
  if (_charDistance(a, b) <= 1) return true;
  final ca = _soundCanon(a);
  final cb = _soundCanon(b);
  if (ca == cb) return true;
  return _charDistance(ca, cb) <= 1;
}

/// 短题宽松分（V1.5.0）
///
/// 教材里大量"单词题"（Three. / Five. / Apple. / Thank you.），Vosk 小模型对
/// 童声单字识别经常直接吐空或吐近音词，导致孩子读对也 0 分。
/// 这里对 ≤2 词的短题改用字符级近音匹配：
///   - 全部近音命中 → 100
///   - 命中一部分     → 按命中比例给分
///   - 一个都没命中   → 30（说明听见了但不像，给鼓励分）
/// 返回 -1 表示"不适用"（长句交给 coverageScore）。
double shortItemScore(String ref, String hyp, {Set<String> ignore = const {}}) {
  final r = norm(ref).where((w) => !ignore.contains(w)).toList();
  // V1.5.1：教材三词短句（I am Mia. / This is me. / Come here, please.）
  // 同样会被小模型识别错，兜底范围从 2 词扩到 3 词。
  if (r.isEmpty || r.length > 3) return -1;
  final h = norm(hyp).where((w) => !ignore.contains(w)).toList();
  // 识别为空：上层按"有声音但没识别"的规则给分
  if (h.isEmpty) return -1;
  var hit = 0;
  for (final rw in r) {
    if (h.any((hw) => nearSound(rw, hw))) hit++;
  }
  if (hit == r.length) return 100.0;
  if (hit == 0) return 30.0;
  final raw = hit / r.length * 100.0;
  // 三词句部分命中封顶 90，避免"读对一半也满分"的观感
  return r.length >= 3 ? (raw > 90 ? 90.0 : raw) : raw;
}

