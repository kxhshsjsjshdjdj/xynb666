import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===== 全局崩溃捕获，自动上报到服务器 =====
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _reportCrashSync(
      details.exceptionAsString(),
      details.stack?.toString() ?? '无堆栈',
      'FlutterError',
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _reportCrashSync(error.toString(), stack.toString(), 'PlatformError');
    return true;
  };

  runZonedGuarded(() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F1A),
    ));

    runApp(const ScreenShareApp());
  }, (error, stack) {
    _reportCrashSync(error.toString(), stack.toString(), 'ZoneError');
  });
}

// 全局可调用的上报函数
Future<void> reportError(String error, String stack, String type) async {
  await _reportCrashSync(error, stack, type);
}

// 同步阻塞上报，确保请求发出后再继续
Future<void> _reportCrashSync(String error, String stack, String type) async {
  try {
    final url = '${AppConfig.signalServer}/crash-report';
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    final request = await client.postUrl(Uri.parse(url));
    request.headers.contentType = ContentType.json;

    final body = jsonEncode({
      'type': type,
      'error': error,
      'stack': stack,
      'time': DateTime.now().toIso8601String(),
      'device': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
    });

    request.write(body);
    final response = await request.close();
    await response.drain();
    client.close();

    await Future.delayed(const Duration(milliseconds: 500));
    print('[CrashReport] 已上报: $type');
  } catch (e) {
    print('[CrashReport] 上报失败: $e');
  }
}

class ScreenShareApp extends StatelessWidget {
  const ScreenShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScreenShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFFFF6584),
          surface: Color(0xFF1A1A2E),
          background: Color(0xFF0F0F1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        fontFamily: 'sans-serif',
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFE8E8F0)),
          bodyLarge: TextStyle(color: Color(0xFFE8E8F0)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
