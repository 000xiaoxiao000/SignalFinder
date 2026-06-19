import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/network_provider.dart';
import 'screens/home_screen.dart';
import 'services/app_log_service.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      final logs = AppLogService.instance;

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        logs.error('Flutter 框架异常', details.exception, details.stack);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        logs.error('未处理的异步异常', error, stack);
        return true;
      };

      logs.info('APP 启动');
      runApp(
        ChangeNotifierProvider(
          create: (_) => NetworkProvider(),
          child: const NetBoostApp(),
        ),
      );
    },
    (error, stack) => AppLogService.instance.error('未捕获异常', error, stack),
  );
}

class NetBoostApp extends StatelessWidget {
  const NetBoostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignalFinder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
