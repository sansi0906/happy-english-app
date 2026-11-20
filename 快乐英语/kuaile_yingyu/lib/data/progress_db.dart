import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../services/app_log.dart';

/// 本地进度存储（SQLite，纯离线）。
///
/// 表结构（schema v3）：
/// - progress(item_id TEXT PRIMARY KEY, stars INTEGER, done INTEGER,
///            updated TEXT, star_mode TEXT, score REAL)
/// - settings(key TEXT PRIMARY KEY, value TEXT)
/// - riddles_seen(riddle_id TEXT PRIMARY KEY, seen_at TEXT)
///
/// V1.5.6 改动：
/// 1. 真正启用 schema 版本号（[schemaVersion]）。此前 `version` 一直是 1，
///    所有迁移都堆在 [_open] 里靠 `PRAGMA table_info` 每次启动重跑，
///    以后再加字段会越来越难维护。现在迁移只在 [onUpgrade] 里跑一次。
/// 2. 新增备份/恢复：本地自动备份（3 天一次，保留 5 份）+ 手动备份 +
///    从备份恢复（恢复前会先把当前数据再备份一份，避免误操作丢档）。
class ProgressDb {
  static Database? _db;

  /// 当前数据库结构版本。升级结构时：这里 +1，并在 [_upgrade] 补一条分支。
  /// v1：早期库，settings/riddles_seen/star_mode/score 全靠启动时手工补列
  /// v2：正式纳入 settings、riddles_seen，progress 增加 star_mode 列
  /// v3：progress 增加 score 列
  /// v4：新增 attempts 表（每次跟读留一条流水；progress 只存"最后一次"，
  ///    会把练习次数覆盖掉，家长周报需要真实次数）
  static const int schemaVersion = 4;

  /// 备份文件放在应用文档目录下的子目录（随 App 卸载而消失，不落公共目录）
  static const String _backupFolder = 'backup';
  static const int _keepBackups = 5;
  static const String _kLastBackupAt = 'last_backup_at';
  static const Duration _autoBackupInterval = Duration(days: 3);

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'kuaile_progress.db');
    final db = await openDatabase(
      dbPath,
      version: schemaVersion,
      onCreate: _createSchema,
      onUpgrade: _upgrade,
    );
    _db = db;
    // 升级结束后再核对一次真实版本号；只有不一致才记日志，避免每次启动刷屏
    try {
      final v = await db.rawQuery('PRAGMA user_version');
      final actual = v.isEmpty ? -1 : (v.first.values.first as int? ?? -1);
      if (actual != schemaVersion) {
        AppLog.append(
            'db', '结构版本异常：期望 $schemaVersion，实际 $actual');
      }
    } catch (e) {
      AppLog.append('db', '读取结构版本失败: $e');
    }
    // 自动备份：不阻塞启动，失败只记日志不影响使用
    unawaited(_autoBackup().catchError((Object _) {}));
    return db;
  }

  // ---- schema ----

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE progress(
        item_id TEXT PRIMARY KEY,
        stars INTEGER NOT NULL DEFAULT 0,
        done INTEGER NOT NULL DEFAULT 0,
        updated TEXT,
        star_mode TEXT DEFAULT "new3",
        score REAL DEFAULT -1
      )
    ''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE riddles_seen(
        riddle_id TEXT PRIMARY KEY,
        seen_at TEXT
      )
    ''');
    await _createAttemptsTable(db);
  }

  /// 每次跟读的流水表：谁、多少分、什么时候。只增不改。
  static Future<void> _createAttemptsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attempts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id TEXT NOT NULL,
        stars INTEGER NOT NULL DEFAULT 0,
        score REAL NOT NULL DEFAULT -1,
        at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_attempts_at ON attempts(at)');
  }

  /// 分组迁移：每段都写成幂等的，老设备（v1）与新设备都能一次性升到 [schemaVersion]。
  static Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _upgradeToV2(db);
    if (oldVersion < 3) await _upgradeToV3(db);
    if (oldVersion < 4) await _upgradeToV4(db);
    // 升级结果写进诊断日志，真机上可核对到底跑没跑
    AppLog.append('db', 'schema 升级 $oldVersion → $newVersion 完成');
  }

  /// v2：补 settings、riddles_seen 两张表，progress 补 star_mode 并把旧五档归一为三档。
  static Future<void> _upgradeToV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS riddles_seen(
        riddle_id TEXT PRIMARY KEY,
        seen_at TEXT
      )
    ''');
    final cols = await db.rawQuery('PRAGMA table_info(progress)');
    if (!cols.any((c) => c['name'] == 'star_mode')) {
      await db.execute(
          'ALTER TABLE progress ADD COLUMN star_mode TEXT DEFAULT "old5"');
      // 旧版把五档星级(1-5)直接存进来，列表会虚高。一次性归并成三档。
      await db.execute('''
        UPDATE progress
           SET stars = CASE WHEN stars >= 5 THEN 3
                            WHEN stars >= 3 THEN 2
                            ELSE 1 END,
               star_mode = 'new3'
         WHERE star_mode = 'old5'
      ''');
    }
  }

  /// v3：progress 补 score 列（旧数据 -1 表示"有星级但没有具体分数"）
  static Future<void> _upgradeToV3(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(progress)');
    if (!cols.any((c) => c['name'] == 'score')) {
      await db.execute(
          'ALTER TABLE progress ADD COLUMN score REAL DEFAULT -1');
    }
  }

  /// v4：建 attempts 流水表，并把老库里"最后一次练习"回填成一条流水，
  /// 这样升级后周报不会是空白（旧记录只有时间点，次数按 1 次算）。
  static Future<void> _upgradeToV4(Database db) async {
    await _createAttemptsTable(db);
    final cols = await db.rawQuery('PRAGMA table_info(progress)');
    final hasUpdated = cols.any((c) => c['name'] == 'updated');
    if (!hasUpdated) return;
    final rows = await db.query(
      'progress',
      columns: ['item_id', 'stars', 'score', 'updated'],
      where: 'updated IS NOT NULL AND updated <> ""',
    );
    final batch = db.batch();
    for (final r in rows) {
      batch.insert('attempts', {
        'item_id': r['item_id'],
        'stars': r['stars'] ?? 0,
        'score': (r['score'] as num?)?.toDouble() ?? -1,
        'at': r['updated'],
      });
    }
    await batch.commit(noResult: true);
  }

  // ---- 设置 ----

  /// 读取一条设置；无记录返回 [def]
  static Future<String> getSetting(String key, {String def = ''}) async {
    final db = await _open();
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? def : (rows.first['value'] as String? ?? def);
  }

  /// 写入一条设置
  static Future<void> setSetting(String key, String value) async {
    final db = await _open();
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- 进度 ----

  /// 保存一次跟读结果；星级 0 表示仅记录"已学"
  /// 统一存三档（1-3）+ 具体分数（score<0 表示旧数据无分数）
  static Future<void> saveResult(String itemId, int stars,
      {double score = -1}) async {
    final db = await _open();
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'progress',
      {
        'item_id': itemId,
        'stars': stars,
        'done': 1,
        'updated': now,
        'star_mode': 'new3',
        'score': score,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // 同时留一条流水；流水写失败不能影响成绩保存
    try {
      await db.insert('attempts', {
        'item_id': itemId,
        'stars': stars,
        'score': score,
        'at': now,
      });
    } catch (e) {
      AppLog.append('db', '写练习流水失败: $e');
    }
  }

  /// 读取 [from] 之后的所有跟读流水（周报用），按时间正序
  static Future<List<Map<String, dynamic>>> attemptsSince(DateTime from) async {
    final db = await _open();
    return db.query(
      'attempts',
      where: 'at >= ?',
      whereArgs: [from.toIso8601String()],
      orderBy: 'at ASC',
    );
  }

  /// 清空练习流水（清空进度时一起清，避免周报和进度不一致）
  static Future<void> clearAttempts() async {
    final db = await _open();
    await db.delete('attempts');
  }

  /// 读取某条进度；无记录返回 null
  static Future<Map<String, dynamic>?> getResult(String itemId) async {
    final db = await _open();
    final rows =
        await db.query('progress', where: 'item_id = ?', whereArgs: [itemId]);
    return rows.isEmpty ? null : rows.first;
  }

  /// 批量读取（页面初始化一次拿全）
  static Future<Map<String, dynamic>> getAll() async {
    final db = await _open();
    final rows = await db.query('progress');
    return {for (final r in rows) r['item_id'] as String: r};
  }

  /// 统计某册某单元完成数
  static Future<int> countDoneInUnit(List<String> itemIds) async {
    final all = await getAll();
    return itemIds.where((id) {
      final r = all[id];
      return r != null && (r['done'] as int? ?? 0) == 1;
    }).length;
  }

  /// 清空全部进度
  static Future<void> clearAll() async {
    final db = await _open();
    await db.delete('progress');
    // 进度清了，流水也要清，否则周报还会显示"本周练过"
    await db.delete('attempts');
  }

  // ---- 弱项复习（错题本）----

  /// 合格线 = 三星线。家长口径（2026-11-20 定）：
  /// 「有一次三星就从错题本移除」，所以低于三档三星的 85 分才算没练熟。
  static const double passScore = 85; // = starsForDisplay() 的三星门槛

  /// 取需要再练的项：练过（done=1）、有分数、最新分数低于 [below]，
  /// 且**从来没拿过三星**——只要流水里有一次三星，这条就永久出队。
  /// 返回按「分低的排前面、同分放得久的排前面」排好序。
  static Future<List<Map<String, dynamic>>> weakItems(
      {double below = passScore}) async {
    final db = await _open();
    return db.rawQuery(
      'SELECT p.* FROM progress p '
      'WHERE p.done = 1 AND p.score >= 0 AND p.score < ? '
      'AND NOT EXISTS (SELECT 1 FROM attempts a '
      '  WHERE a.item_id = p.item_id AND (a.stars >= 3 OR a.score >= ?)) '
      'ORDER BY p.score ASC, p.updated ASC',
      [below, below],
    );
  }

  /// 复习队列条数（首页角标用，不必拉全表）
  static Future<int> weakCount({double below = passScore}) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM progress p '
      'WHERE p.done = 1 AND p.score >= 0 AND p.score < ? '
      'AND NOT EXISTS (SELECT 1 FROM attempts a '
      '  WHERE a.item_id = p.item_id AND (a.stars >= 3 OR a.score >= ?))',
      [below, below],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // ---- 知识卡去重 ----

  /// 记录一道已出过的知识卡
  static Future<void> markRiddleSeen(String riddleId) async {
    final db = await _open();
    await db.insert(
      'riddles_seen',
      {'riddle_id': riddleId, 'seen_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 已出过的知识卡 id 集合
  static Future<Set<String>> getSeenRiddleIds() async {
    final db = await _open();
    final rows = await db.query('riddles_seen');
    return {for (final r in rows) r['riddle_id'] as String};
  }

  /// 题库看完一轮后重置记录
  static Future<void> clearSeenRiddles() async {
    final db = await _open();
    await db.delete('riddles_seen');
  }

  // ---- 备份 / 恢复 ----

  /// 导出为可读 JSON（进度 + 设置 + 知识卡记录 + 练习流水）。
  /// 也是"导出到下载目录"的数据源。
  static Future<String> exportJson() async {
    final db = await _open();
    final progress = await db.query('progress');
    final settings = await db.query('settings');
    final riddles = await db.query('riddles_seen');
    final attempts = await db.query('attempts');
    return const JsonEncoder.withIndent('  ').convert({
      'app': '快乐英语',
      'schema': schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'progress': progress,
      'settings': settings,
      'riddles_seen': riddles,
      'attempts': attempts,
    });
  }

  static Future<Directory> _backupDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, _backupFolder));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  static String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  /// 手动备份一次，返回备份文件名。
  static Future<String> backupNow() async {
    final json = await exportJson();
    final dir = await _backupDir();
    final name = 'progress_${_stamp()}.json';
    await File(p.join(dir.path, name)).writeAsString(json, flush: true);
    await setSetting(_kLastBackupAt, DateTime.now().toIso8601String());
    await _pruneBackups(dir);
    return name;
  }

  /// 只保留最近 [keepBackups] 份（文件名带时间戳，按名字排序即按时间排序）
  static Future<void> _pruneBackups(Directory dir,
      {int keepBackups = _keepBackups}) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('progress_'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    while (files.length > keepBackups) {
      final f = files.removeAt(0);
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  /// 距上次备份超过 3 天就自动备份一次；没有进度数据时跳过。
  static Future<void> _autoBackup() async {
    final db = _db;
    if (db == null) return;
    final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM progress')) ??
        0;
    if (count == 0) return;
    final rows =
        await db.query('settings', where: 'key = ?', whereArgs: [_kLastBackupAt]);
    final last = rows.isEmpty ? '' : (rows.first['value'] as String? ?? '');
    final lastAt = DateTime.tryParse(last);
    if (lastAt != null && DateTime.now().difference(lastAt) < _autoBackupInterval) {
      return;
    }
    await backupNow();
  }

  /// 最近一次备份时间；从未备份返回 null
  static Future<DateTime?> lastBackupAt() async {
    final v = await getSetting(_kLastBackupAt);
    return DateTime.tryParse(v);
  }

  /// 可用备份列表（新→旧）。[count] 是该份备份里的进度条数。
  static Future<List<({String name, DateTime time, int count})>> listBackups() async {
    final dir = await _backupDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('progress_'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    final out = <({String name, DateTime time, int count})>[];
    for (final f in files) {
      final name = p.basename(f.path);
      try {
        final data = jsonDecode(await f.readAsString());
        final list = (data is Map ? data['progress'] : null) as List?;
        out.add((name: name, time: f.lastModifiedSync(), count: list?.length ?? 0));
      } catch (_) {
        // 坏文件也列出来，但条数记 0，恢复时会明确报错
        out.add((name: name, time: f.lastModifiedSync(), count: 0));
      }
    }
    return out;
  }

  /// 从指定备份文件恢复。返回恢复的进度条数。
  /// 恢复前会先把当前数据另存一份（文件名带 before_restore 标记），可反悔。
  /// 备份内容非法时抛 [FormatException]。
  static Future<int> restoreFromBackup(String name) async {
    final dir = await _backupDir();
    final f = File(p.join(dir.path, name));
    if (!f.existsSync()) throw const FormatException('备份文件不存在');
    return restoreFromJson(await f.readAsString());
  }

  /// 从 JSON 文本恢复（[restoreFromBackup] 的底层实现，也便于测试）
  static Future<int> restoreFromJson(String json) async {
    final dynamic data = jsonDecode(json);
    if (data is! Map) throw const FormatException('备份文件格式不对');
    final schema = data['schema'];
    if (schema is num && schema > schemaVersion) {
      throw FormatException('这份备份来自更新的版本（v$schema），当前 App 读不了');
    }
    final progress = data['progress'];
    if (progress is! List) throw const FormatException('备份里没有进度数据');

    // 恢复前先保住当前状态
    final db = await _open();
    final currentCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM progress')) ?? 0;
    if (currentCount > 0) {
      try {
        final dir = await _backupDir();
        final name = 'progress_${_stamp()}_before_restore.json';
        await File(p.join(dir.path, name))
            .writeAsString(await exportJson(), flush: true);
        await _pruneBackups(dir);
      } catch (_) {}
    }

    await db.transaction((txn) async {
      await txn.delete('progress');
      for (final row in progress) {
        if (row is Map) {
          await txn.insert('progress', Map<String, dynamic>.from(row),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      final settings = data['settings'];
      if (settings is List) {
        await txn.delete('settings');
        for (final row in settings) {
          if (row is Map) {
            await txn.insert('settings', Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
      final riddles = data['riddles_seen'];
      if (riddles is List) {
        await txn.delete('riddles_seen');
        for (final row in riddles) {
          if (row is Map) {
            await txn.insert('riddles_seen', Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
      // 练习流水：备份里有就一起恢复；老备份没有这一段，
      // 就把当前流水清掉——否则恢复完周报会混着"恢复前"的练习记录。
      final attempts = data['attempts'];
      await txn.delete('attempts');
      if (attempts is List) {
        for (final row in attempts) {
          if (row is Map) {
            await txn.insert('attempts', Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    });

    // 不把 last_backup_at 改写成"现在"：那会让设置页显示一个并不存在的
    // "上次备份 14:37"，家长点「从备份恢复」时找不到这一份。
    // 恢复回来的 settings 里带着备份当时的 last_backup_at；
    // 若它已过期，下次启动 _autoBackup 会真的补一份，时间也是真的。
    return progress.length;
  }
}
