import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/logger.dart';
import 'presentation/providers/project_provider.dart';

/// アプリケーションのエントリーポイント
///
/// ウィンドウ設定、ロギング初期化を行い、アプリを起動する
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ロギングを初期化
  AppLogger.initialize();

  // SharedPreferencesを初期化
  final prefs = await SharedPreferences.getInstance();

  // ウィンドウ設定（デスクトップ用）
  await _initializeWindow();

  // アプリケーションを起動
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FieldPlannerApp(),
    ),
  );
}

/// ウィンドウを初期化
Future<void> _initializeWindow() async {
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1440, 900),
    minimumSize: Size(1024, 768),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: AppConstants.appName,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
