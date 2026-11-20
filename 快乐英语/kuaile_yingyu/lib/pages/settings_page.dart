import 'package:flutter/material.dart';

import '../data/progress_db.dart';
import '../main.dart';
import '../services/app_log.dart';
import '../services/backup_service.dart';
import '../services/recordings_store.dart';
import '../widgets/safe_tap.dart';
import 'diagnostic_page.dart';
import 'recordings_page.dart';

/// 危险操作色（比主题橙更红，一眼能分辨"会删东西"）
const _kDanger = Color(0xFFE05B4B);
const _kFieldBg = Color(0xFFF7F2E8);

/// 设置页 V2：孩子档案 → 学习记录 → 跟读录音 → 关于。
/// 字号收敛到 19/14，行高统一，卡片用主题的细边框与阴影。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameCtrl = TextEditingController();
  bool _nameLoaded = false;
  int _learned = 0;
  ({int count, int bytes, bool error}) _recStats =
      (count: 0, bytes: 0, error: false);
  DateTime? _lastBackup;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final name = await ProgressDb.getSetting('child_name', def: '小朋友');
    final rec = await RecordingsStore.stats();
    final all = await ProgressDb.getAll();
    final lb = await ProgressDb.lastBackupAt();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = name;
      _nameLoaded = true;
      _recStats = rec;
      _learned = all.length;
      _lastBackup = lb;
    });
  }

  /// "3 天前" / "今天 09:12" 这类人话时间
  String _agoText(DateTime? t) {
    if (t == null) return '还没备份过';
    final now = DateTime.now();
    final days = now.difference(t).inDays;
    if (days <= 0) {
      final two = t.minute.toString().padLeft(2, '0');
      return '今天 ${t.hour}:$two';
    }
    if (days == 1) return '昨天';
    if (days < 30) return '$days 天前';
    return '${t.year}/${t.month}/${t.day}';
  }

  /// 备份一次：本地留档 + 导出到下载目录（方便转发/换机）
  Future<void> _backupNow() async {
    try {
      await ProgressDb.backupNow();
      final path = await BackupService.exportToDownloads();
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path == null
              ? '已备份到本机（导出到下载目录失败，请看诊断日志）'
              : '已备份，文件在 $path'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, st) {
      AppLog.error(e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('备份失败：$e')),
      );
    }
  }

  /// 从备份恢复：先选一份，再确认，恢复后重新加载
  Future<void> _restoreFlow() async {
    List<({String name, DateTime time, int count})> backups;
    try {
      backups = await ProgressDb.listBackups();
    } catch (e, st) {
      AppLog.error(e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取备份列表失败：$e')),
      );
      return;
    }
    if (!mounted) return;
    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本机还没有备份，先点一次「备份学习记录」')),
      );
      return;
    }
    final picked = await showDialog<({String name, DateTime time, int count})>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgColor,
        title: const Text('选择要恢复的备份',
            style: TextStyle(
                fontSize: 21, fontWeight: FontWeight.w700, color: kDark)),
        content: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final b in backups)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${b.time.year}/${b.time.month}/${b.time.day} '
                        '${b.time.hour}:${b.time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 17, color: kDark)),
                    subtitle: Text('${b.count} 条记录',
                        style: const TextStyle(fontSize: 14, color: kMuted)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: kMuted),
                    onTap: () => Navigator.pop(ctx, b),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消',
                style: TextStyle(fontSize: 17, color: kMuted)),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    final ok = await _confirm(
      title: '恢复到这份备份？',
      body: '当前 $_learned 条学习记录会被替换成备份里的 ${picked.count} 条。'
          '恢复前会先把现在的状态自动存一份，后悔还能找回。',
      okText: '恢复',
    );
    if (ok != true) return;

    try {
      final n = await ProgressDb.restoreFromBackup(picked.name);
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢复 $n 条学习记录')),
      );
    } catch (e, st) {
      AppLog.error(e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败：$e')),
      );
    }
  }

  Future<void> _saveName() async {
    final v = _nameCtrl.text.trim();
    final name = v.isEmpty ? '小朋友' : v;
    await ProgressDb.setSetting('child_name', name);
    if (!mounted) return;
    setState(() => _nameCtrl.text = name);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存，之后录音会带上这个名字')),
    );
  }

  Future<void> _confirmClearProgress() async {
    final ok = await _confirm(
      title: '清空学习进度？',
      body: '孩子已学的 $_learned 条记录会全部删除，星级和分数都会归零，且无法恢复。',
      okText: '清空',
    );
    if (ok != true) return;
    await ProgressDb.clearAll();
    if (!mounted) return;
    setState(() => _learned = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('学习进度已清空')),
    );
  }

  Future<void> _confirmClearRecordings() async {
    final s = _recStats;
    final ok = await _confirm(
      title: '清空跟读录音？',
      body: '手机里保存的 ${s.count} 条录音会被删除，删除后无法找回。',
      okText: '清空',
    );
    if (ok != true) return;
    await RecordingsStore.clearAll();
    final rec = await RecordingsStore.stats();
    if (!mounted) return;
    setState(() => _recStats = rec);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('录音已清空')),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String okText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgColor,
        title: Text(title,
            style: const TextStyle(
                fontSize: 21, fontWeight: FontWeight.w700, color: kDark)),
        content: Text(body,
            style: const TextStyle(fontSize: 16, color: kDark, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消',
                style: TextStyle(fontSize: 17, color: kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okText,
                style: const TextStyle(
                    fontSize: 17,
                    color: _kDanger,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameText = _nameCtrl.text.trim();
    final avatarChar = nameText.isEmpty ? '宝' : nameText.substring(0, 1);
    final recMb = (_recStats.bytes / 1024 / 1024).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
        children: [
          // ---------- 孩子档案 ----------
          const _SectionLabel('孩子档案'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kGreenSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(avatarChar,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: kGreen)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        enabled: _nameLoaded,
                        style: const TextStyle(fontSize: 20, color: kDark),
                        decoration: InputDecoration(
                          hintText: '孩子叫什么？',
                          hintStyle:
                              const TextStyle(fontSize: 18, color: kMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          filled: true,
                          fillColor: _kFieldBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kLine),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kLine),
                          ),
                        ),
                        onSubmitted: (_) => _saveName(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('录音会按这个名字分开保存，方便区分两个孩子',
                    style: TextStyle(fontSize: 14, color: kMuted)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveName,
                    child: const Text('保存昵称'),
                  ),
                ),
              ],
            ),
          ),

          // ---------- 学习记录 ----------
          const _SectionLabel('学习记录'),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _StatRow(
                  icon: Icons.insights_rounded,
                  color: kOrange,
                  title: '已学内容',
                  sub: '课文点读、单词和跟读的合计',
                  value: '$_learned 项',
                ),
                const Divider(height: 1, color: kLine),
                _StatRow(
                  icon: Icons.shield_outlined,
                  color: kGreen,
                  title: '上次备份',
                  sub: '每 3 天自动备一次，换机前手动备一次',
                  value: _agoText(_lastBackup),
                ),
                const Divider(height: 1, color: kLine),
                _ActionRow(
                  icon: Icons.backup_outlined,
                  color: kGreen,
                  title: '备份学习记录',
                  sub: '存到本机和下载目录，换机、重装都能找回',
                  onTap: _backupNow,
                ),
                const Divider(height: 1, color: kLine),
                _ActionRow(
                  icon: Icons.restore_rounded,
                  color: kBlue,
                  title: '从备份恢复',
                  sub: '用之前存下的记录覆盖当前进度',
                  onTap: _restoreFlow,
                ),
                const Divider(height: 1, color: kLine),
                _ActionRow(
                  icon: Icons.delete_sweep_rounded,
                  color: _kDanger,
                  title: '清空学习进度',
                  sub: '删除全部星级和分数记录',
                  onTap: _confirmClearProgress,
                ),
              ],
            ),
          ),

          // ---------- 跟读录音 ----------
          const _SectionLabel('跟读录音'),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _StatRow(
                  icon: Icons.mic_rounded,
                  color: kGreen,
                  title: '本机录音',
                  sub: _recStats.error
                      ? '读取失败：${RecordingsStore.lastError ?? "未知原因"}'
                      : '只存在这台手机上，不会上传',
                  value: _recStats.error
                      ? '读取失败'
                      : '${_recStats.count} 条 · $recMb MB',
                ),
                if (_recStats.count > 0) ...[
                  const Divider(height: 1, color: kLine),
                  _ActionRow(
                    icon: Icons.play_circle_outline,
                    color: kGreen,
                    title: '回听录音',
                    sub: '按孩子、按单元查看，也能导出',
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RecordingsPage(),
                      ));
                      await _loadAll();
                    },
                  ),
                  const Divider(height: 1, color: kLine),
                  _ActionRow(
                    icon: Icons.delete_outline_rounded,
                    color: _kDanger,
                    title: '清空录音',
                    sub: '删除全部已录制的音频',
                    onTap: _confirmClearRecordings,
                  ),
                ],
              ],
            ),
          ),

          // ---------- 关于 ----------
          const _SectionLabel('关于'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: kGreen, size: 22),
                    SizedBox(width: 8),
                    Text('快乐英语',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: kDark)),
                    SizedBox(width: 8),
                    Text('v1.0.0',
                        style: TextStyle(fontSize: 14, color: kMuted)),
                  ],
                ),
                const SizedBox(height: 10),
                const _AboutLine('新蕾《快乐英语》第 1–4 册 · 一、二年级'),
                const _AboutLine('人教精通版第 5–12 册 · 三至六年级'),
                const _AboutLine('纯离线 · 无账号 · 无广告 · 数据只在本机'),
              ],
            ),
          ),
          const _SectionLabel('诊断'),
          _Card(
            padding: EdgeInsets.zero,
            child: _ActionRow(
              icon: Icons.bug_report_outlined,
              color: kBlue,
              title: '诊断日志',
              sub: '音频、录音出问题时，把这里的内容发我',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiagnosticPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kMuted,
              letterSpacing: 1.2)),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kLine),
        boxShadow: kShadow,
      ),
      child: child,
    );
  }
}

/// 统计行：图标 + 标题 + 副标题 + 右侧数值
class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final String value;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: kDark)),
              ),
              const SizedBox(width: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Text(sub,
                style: const TextStyle(fontSize: 14, color: kMuted, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// 操作行：整行可点，右侧箭头
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: color == _kDanger ? _kDanger : kDark)),
                  const SizedBox(height: 3),
                  Text(sub,
                      style: const TextStyle(fontSize: 14, color: kMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

class _AboutLine extends StatelessWidget {
  final String text;
  const _AboutLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('·  ', style: TextStyle(fontSize: 14, color: kMuted)),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14, color: kMuted, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
