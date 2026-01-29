import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../data/services/recent_projects_service.dart';
import '../providers/project_provider.dart';
import '../widgets/dialogs/new_project_dialog.dart';
import 'main_screen.dart';

/// アプリケーション起動時に表示されるスタート画面
///
/// 新規プロジェクト作成、既存プロジェクトを開く、
/// 最近使ったプロジェクト一覧を表示する
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectState = ref.watch(projectNotifierProvider);

    // プロジェクトが読み込まれたらメイン画面に遷移
    if (projectState is ProjectLoadedState) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainScreen(),
          ),
        );
      });
    }

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ロゴ・タイトル
              _buildHeader(theme),
              const SizedBox(height: 48),

              // アクションボタン
              _buildActionButtons(context, theme),
              const SizedBox(height: 48),

              // 最近使ったプロジェクト
              Expanded(
                child: _buildRecentProjects(theme),
              ),

              // ローディング表示
              if (projectState is ProjectLoadingState)
                const LinearProgressIndicator(),

              // エラー表示
              if (projectState is ProjectErrorState)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    projectState.message,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ヘッダー部分を構築
  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.map_outlined,
          size: 80,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          AppConstants.appName,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'イベント会場設計用3Dマップアプリケーション',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'v${AppConstants.appVersion}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// アクションボタンを構築
  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 新規プロジェクト
        _buildActionCard(
          context: context,
          theme: theme,
          icon: Icons.add_circle_outline,
          title: '新規プロジェクト',
          subtitle: '新しいプロジェクトを作成',
          onTap: _createNewProject,
        ),
        const SizedBox(width: 16),

        // プロジェクトを開く
        _buildActionCard(
          context: context,
          theme: theme,
          icon: Icons.folder_open_outlined,
          title: '開く',
          subtitle: '既存のプロジェクトを開く',
          onTap: _openProject,
        ),
        const SizedBox(width: 16),

        // インポート
        _buildActionCard(
          context: context,
          theme: theme,
          icon: Icons.upload_file_outlined,
          title: 'インポート',
          subtitle: 'ZIPファイルから読み込み',
          onTap: _importProject,
        ),
      ],
    );
  }

  /// アクションカードを構築
  Widget _buildActionCard({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 180,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 最近使ったプロジェクト一覧を構築
  Widget _buildRecentProjects(ThemeData theme) {
    List<RecentProject> recentProjects = [];
    try {
      recentProjects = ref.watch(recentProjectsProvider);
    } catch (_) {
      // SharedPreferencesがまだ初期化されていない場合
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '最近使ったプロジェクト',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (recentProjects.isNotEmpty)
              TextButton(
                onPressed: _clearRecentProjects,
                child: const Text('クリア'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: recentProjects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_off_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '最近使ったプロジェクトはありません',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: recentProjects.length,
                  itemBuilder: (context, index) {
                    final project = recentProjects[index];
                    return _buildRecentProjectTile(theme, project);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecentProjectTile(ThemeData theme, RecentProject project) {
    return ListTile(
      leading: const Icon(Icons.folder),
      title: Text(project.name),
      subtitle: Text(
        project.path,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(
        _formatDate(project.lastAccessedAt),
        style: theme.textTheme.bodySmall,
      ),
      onTap: () => _openProjectAt(project.path),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今日';
    } else if (diff.inDays == 1) {
      return '昨日';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  /// 新規プロジェクトを作成
  Future<void> _createNewProject() async {
    final result = await showDialog<NewProjectResult>(
      context: context,
      builder: (context) => const NewProjectDialog(),
    );

    if (result != null && mounted) {
      await ref.read(projectNotifierProvider.notifier).createProject(
            basePath: result.savePath,
            name: result.name,
            description: result.description,
            author: result.author,
          );
    }
  }

  /// 既存プロジェクトを開く
  Future<void> _openProject() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'プロジェクトフォルダを選択',
    );

    if (result != null && mounted) {
      await _openProjectAt(result);
    }
  }

  Future<void> _openProjectAt(String path) async {
    await ref.read(projectNotifierProvider.notifier).openProject(path);
  }

  /// プロジェクトをインポート
  void _importProject() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('インポート機能は工程12で実装します')),
    );
  }

  void _clearRecentProjects() async {
    try {
      await ref.read(recentProjectsServiceProvider).clearAll();
      ref.invalidate(recentProjectsProvider);
    } catch (_) {
      // エラーは無視
    }
  }
}
