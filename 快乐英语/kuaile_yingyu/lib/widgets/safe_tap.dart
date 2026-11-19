import 'dart:async';

import 'package:flutter/material.dart';

/// 容错点击：按下后若 250ms 内没有等到正常的 onTap（部分机型/系统偶发丢 UP 事件），
/// 主动触发一次，避免用户感觉"点一下没反应、要点第二次"。
/// 正常点击时 onTap 会先到，定时器被取消，行为与普通 InkWell 完全一致。
/// 手指按住后滑动会让手势判定为拖动，触发 onTapCancel，定时器取消，不会误跳转。
class SafeTap extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final BorderRadius? borderRadius;

  const SafeTap({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius,
  });

  @override
  State<SafeTap> createState() => _SafeTapState();
}

class _SafeTapState extends State<SafeTap> {
  Timer? _fallback;
  bool _fired = false;

  void _startFallback() {
    _fired = false;
    _fallback?.cancel();
    _fallback = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _fired) return;
      _fired = true;
      widget.onTap();
    });
  }

  void _cancelFallback() {
    _fallback?.cancel();
    _fallback = null;
  }

  @override
  void dispose() {
    _fallback?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: widget.borderRadius,
      onTapDown: (_) => _startFallback(),
      onTapCancel: _cancelFallback,
      onTap: () {
        _cancelFallback();
        if (_fired) return; // 兜底已触发过，避免重复跳转
        _fired = true;
        widget.onTap();
      },
      child: widget.child,
    );
  }
}
