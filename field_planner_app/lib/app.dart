import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'presentation/themes/app_theme.dart';
import 'presentation/screens/start_screen.dart';

/// アプリケーションのルートウィジェット
///
/// MaterialAppを構成し、テーマ設定とルーティングを管理する
class FieldPlannerApp extends ConsumerWidget {
  const FieldPlannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const StartScreen(),
    );
  }
}
