import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'pages/home_page.dart';
import 'services/app_log.dart';
import 'services/audio_service.dart';

/// 主题色板（UI V2.0）
/// 暖米白底 + 柔和主绿 + 暖橙强调；文字用柔和的深灰，避免纯黑刺眼。
const kBgColor = Color(0xFFFDF8F1); // 暖米白背景
const kGreen = Color(0xFF4CAF7D); // 主绿
const kGreenSoft = Color(0xFFE4F3EA); // 主绿浅底
const kOrange = Color(0xFFF4984A); // 橙
const kOrangeSoft = Color(0xFFFCEBDA); // 橙浅底
const kYellow = Color(0xFFFFCF5C); // 黄
const kBlue = Color(0xFF5B9BD5); // 辅助蓝
const kBlueSoft = Color(0xFFE3EFF9);
const kDark = Color(0xFF3D3D3D); // 主文字
const kMuted = Color(0xFF8C8C8C); // 次要文字
const kWhite = Color(0xFFFFFFFF);
const kLine = Color(0xFFEFE5D8); // 分割线/描边

/// 统一圆角与阴影
const kRadius = 22.0;
const kShadow = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 6)),
];

/// 异常落盘：真机没有连接 ide 时，靠这个文件定位闪退/异常
Future<void> _logFatal(Object error, StackTrace stack) async {
  debugPrint('[APP-ERROR] $error\n$stack');
  await AppLog.error(error, stack);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logFatal(details.exception, details.stack ?? StackTrace.current);
  };
  // 引擎层未捕获异常（平台通道、异步任务等）
  PlatformDispatcher.instance.onError = (error, stack) {
    _logFatal(error, stack);
    return true;
  };
  // release 下 build 异常不再整屏红，给一个可读的兜底提示
  ErrorWidget.builder = (details) => const Material(
        color: kBgColor,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('这里出了点小问题，返回上一页再试一次吧',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, color: kDark)),
          ),
        ),
      );
  runZonedGuarded(() => runApp(const KuaileApp()),
      (error, stack) => _logFatal(error, stack));
}

class KuaileApp extends StatelessWidget {
  const KuaileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '快乐英语',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // 安卓也支持 iOS 风格的左边缘滑动返回
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: kGreen,
          primary: kGreen,
          secondary: kOrange,
          surface: kBgColor,
        ),
        scaffoldBackgroundColor: kBgColor,
        fontFamily: 'sans-serif',
        splashFactory: InkSparkle.splashFactory,
        appBarTheme: const AppBarTheme(
          backgroundColor: kBgColor,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle:
              TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kDark),
          iconTheme: IconThemeData(color: kDark, size: 26),
        ),
        cardTheme: CardThemeData(
          color: kWhite,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadius),
            side: const BorderSide(color: kLine),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kGreen,
            foregroundColor: kWhite,
            elevation: 0,
            minimumSize: const Size(88, 60),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadius),
            ),
            textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kDark,
            side: const BorderSide(color: kLine, width: 1.5),
            minimumSize: const Size(88, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadius),
            ),
            textStyle: const TextStyle(fontSize: 21),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kGreen,
            textStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: kDark,
          contentTextStyle: const TextStyle(fontSize: 18, color: kWhite),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadius),
          ),
          titleTextStyle:
              const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: kDark),
          contentTextStyle: const TextStyle(fontSize: 20, color: kDark),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontSize: 46, fontWeight: FontWeight.bold, color: kDark),
          headlineLarge: TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: kDark),
          titleLarge: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w600, color: kDark),
          bodyLarge: TextStyle(fontSize: 24, color: kDark),
          bodyMedium: TextStyle(fontSize: 22, color: kDark),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// 统一的"回到主页"动作：停止播放
void backToHome(BuildContext context) {
  AudioService.stop();
  Navigator.of(context).popUntil((r) => r.isFirst);
}
