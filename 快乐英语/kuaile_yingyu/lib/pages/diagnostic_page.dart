import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/app_log.dart';
import '../widgets/safe_tap.dart';

/// 诊断日志页（V1.5.5）
/// 家长把这里的内容整段复制发过来，就能定位"录音没存上""音频没声音"这类问题。
class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  String _text = '加载中…';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final t = await AppLog.read();
    if (!mounted) return;
    setState(() {
      _text = t;
      _loading = false;
    });
  }

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _text));
    messenger.showSnackBar(const SnackBar(content: Text('已复制，可以粘贴发给我')));
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空诊断日志？'),
        content: const Text('清空后之前的错误记录就找不回了。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('清空')),
        ],
      ),
    );
    if (ok != true) return;
    await AppLog.clear();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        title: const Text('诊断日志',
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, color: kDark)),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded, color: kDark),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Text(
              '这里记录的是音频播放失败、录音没存上这类问题。'
              '遇到异常时点「复制全部」整段发我，就能查原因。',
              style: TextStyle(fontSize: 13.5, color: kMuted, height: 1.5),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kLine),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _text,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: kDark,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Row(
              children: [
                Expanded(
                  child: SafeTap(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _loading ? () {} : _copy,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kLine),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.copy_rounded, size: 18, color: kGreen),
                          SizedBox(width: 6),
                          Text('复制全部',
                              style: TextStyle(fontSize: 15, color: kGreen)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SafeTap(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _loading ? () {} : _clear,
                  child: Container(
                    width: 96,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kLine),
                    ),
                    child: const Text('清空',
                        style: TextStyle(fontSize: 15, color: kMuted)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
