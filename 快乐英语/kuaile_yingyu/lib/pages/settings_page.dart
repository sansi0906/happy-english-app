import 'package:flutter/material.dart';

import '../data/progress_db.dart';
import '../main.dart';
import '../services/recordings_store.dart';
import '../widgets/safe_tap.dart';
import 'recordings_page.dart';

/// 危险操作色（比主题橙更红，一眼能分辨"会删东西"）
const _kDanger = Color(0xFFE05B4B);
/// 辅助说明文字
const _kMuted = Color(0xFF8C8272);
const _kLine = Color(0xFFE8DFCF);
const _kFieldBg = Color(0xFFF7F2E8);

/// 设置页：孩子档案 / 学习设置 / 学习记录 / 跟读录音 / 关于
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameCtrl = TextEditingController();
  bool _nameLoaded = false;
  int _learned = 0;
  ({int count, int bytes}) _recStats = (count: 0, bytes: 0);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final name = await ProgressDb.getSetting('child_name', def: '小朋友');
    final rec = await RecordingsStore.stats();
    final all = await ProgressDb.getAll();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = name;
      _nameLoaded = true;
      _recStats = rec;
      _learned = all.length;
    });
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
        title: Text(title, style: const TextStyle(fontSize: 26, color: kDark)),
        content: Text(body,
            style: const TextStyle(fontSize: 20, color: kDark, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消',
                style: TextStyle(fontSize: 22, color: _kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okText,
                style: const TextStyle(
                    fontSize: 22, color: _kDanger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameText = _nameCtrl.text.trim();
    final avatarChar = nameText.isEmpty ? '宝' : nameText.substring(0, 1);

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        title: const Text('设置',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: kDark)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          // ---------- 孩子档案 ----------
          const _SectionTitle('孩子档案'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kGreen.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Text(avatarChar,
                          style: const TextStyle(
                              fontSize: 30, color: Color(0xFF5A9E55))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        enabled: _nameLoaded,
                        style: const TextStyle(fontSize: 24, color: kDark),
                        decoration: InputDecoration(
                          hintText: '孩子叫什么？',
                          hintStyle:
                              const TextStyle(fontSize: 20, color: _kMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: _kFieldBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _kLine),
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
                    style: TextStyle(fontSize: 17, color: _kMuted)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SafeTap(
                    onTap: _saveName,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('保存昵称',
                          style: TextStyle(
                              fontSize: 22,
                              color: kWhite,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------- 学习记录 ----------
          const _SectionTitle('学习记录'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconBadge(icon: Icons.insights, color: kOrange),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('已学内容',
                          style: TextStyle(fontSize: 24, color: kDark)),
                    ),
                    Text('$_learned 项',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: kOrange)),
                  ],
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: Text('课文点读、单词学习和跟读完成的合计',
                      style: TextStyle(fontSize: 17, color: _kMuted)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: SafeTap(
              onTap: _confirmClearProgress,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  _IconBadge(icon: Icons.delete_sweep, color: _kDanger),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('清空学习进度',
                            style: TextStyle(fontSize: 24, color: _kDanger)),
                        SizedBox(height: 2),
                        Text('删除全部星级和分数记录',
                            style: TextStyle(fontSize: 17, color: _kMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _kMuted, size: 28),
                ],
              ),
            ),
          ),

          // ---------- 跟读录音 ----------
          const _SectionTitle('跟读录音'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconBadge(icon: Icons.mic, color: kGreen),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('本机录音',
                          style: TextStyle(fontSize: 24, color: kDark)),
                    ),
                    Text(
                        '${_recStats.count} 条 · ${(_recStats.bytes / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: const TextStyle(fontSize: 18, color: _kMuted)),
                  ],
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: Text('只存在这台手机上，不会上传',
                      style: TextStyle(fontSize: 17, color: _kMuted)),
                ),
                if (_recStats.count > 0) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _OutlineButton(
                          label: '回听录音',
                          icon: Icons.play_circle_outline,
                          color: kGreen,
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const RecordingsPage(),
                            ));
                            await _loadAll();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OutlineButton(
                          label: '清空录音',
                          icon: Icons.delete_outline,
                          color: _kDanger,
                          onTap: _confirmClearRecordings,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ---------- 关于 ----------
          const _SectionTitle('关于'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('快乐英语 · 一年级上下册',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: kDark)),
                const SizedBox(height: 4),
                const Text('版本 1.0.0',
                    style: TextStyle(fontSize: 18, color: _kMuted)),
                const SizedBox(height: 12),
                const _AboutLine('新蕾《快乐英语》第 1–4 册 · 一、二年级'),
                const _AboutLine('人教精通版第 5–12 册 · 三至六年级'),
                const _AboutLine('纯离线 · 无账号 · 无广告 · 数据只在本机'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, color: _kMuted)),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kLine, width: 2),
      ),
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 19, color: color, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 17, color: kDark)),
    );
  }
}
