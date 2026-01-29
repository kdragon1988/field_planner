import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/services/recent_projects_service.dart';

/// プロジェクトリポジトリのProvider
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

/// SharedPreferencesのProvider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

/// RecentProjectsServiceのProvider
final recentProjectsServiceProvider = Provider<RecentProjectsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RecentProjectsService(prefs);
});

/// 最近使ったプロジェクトのProvider
final recentProjectsProvider = StateProvider<List<RecentProject>>((ref) {
  final service = ref.watch(recentProjectsServiceProvider);
  return service.getRecentProjects();
});

/// プロジェクト状態を管理するNotifier
class ProjectNotifier extends StateNotifier<ProjectState> {
  final ProjectRepository _repository;
  final RecentProjectsService _recentService;

  ProjectNotifier(this._repository, this._recentService)
      : super(const ProjectState.initial());

  /// 新規プロジェクトを作成
  Future<void> createProject({
    required String basePath,
    required String name,
    String? description,
    String? author,
  }) async {
    state = const ProjectState.loading();

    try {
      final project = Project.create(
        name: name,
        description: description,
        author: author,
      );

      final projectPath = await _repository.createProject(basePath, project);
      await _recentService.addProject(projectPath, name);

      state = ProjectState.loaded(
        project: project,
        projectPath: projectPath,
        isDirty: false,
      );
    } catch (e) {
      state = ProjectState.error(e.toString());
    }
  }

  /// プロジェクトを開く
  Future<void> openProject(String projectPath) async {
    state = const ProjectState.loading();

    try {
      final project = await _repository.openProject(projectPath);
      await _recentService.addProject(projectPath, project.name);

      state = ProjectState.loaded(
        project: project,
        projectPath: projectPath,
        isDirty: false,
      );
    } catch (e) {
      state = ProjectState.error(e.toString());
    }
  }

  /// プロジェクトを保存
  Future<void> saveProject() async {
    final currentState = state;
    if (currentState is! ProjectLoadedState) return;

    try {
      await _repository.saveProject(
        currentState.projectPath,
        currentState.project,
      );

      state = ProjectState.loaded(
        project: currentState.project.copyWith(updatedAt: DateTime.now()),
        projectPath: currentState.projectPath,
        isDirty: false,
      );
    } catch (e) {
      state = ProjectState.error(e.toString());
    }
  }

  /// プロジェクトを更新（変更をマーク）
  void updateProject(Project project) {
    final currentState = state;
    if (currentState is! ProjectLoadedState) return;

    state = ProjectState.loaded(
      project: project,
      projectPath: currentState.projectPath,
      isDirty: true,
    );
  }

  /// プロジェクトを閉じる
  void closeProject() {
    state = const ProjectState.initial();
  }
}

/// プロジェクト状態
sealed class ProjectState {
  const ProjectState();

  const factory ProjectState.initial() = ProjectInitialState;
  const factory ProjectState.loading() = ProjectLoadingState;
  const factory ProjectState.loaded({
    required Project project,
    required String projectPath,
    required bool isDirty,
  }) = ProjectLoadedState;
  const factory ProjectState.error(String message) = ProjectErrorState;
}

class ProjectInitialState extends ProjectState {
  const ProjectInitialState();
}

class ProjectLoadingState extends ProjectState {
  const ProjectLoadingState();
}

class ProjectLoadedState extends ProjectState {
  final Project project;
  final String projectPath;
  final bool isDirty;

  const ProjectLoadedState({
    required this.project,
    required this.projectPath,
    required this.isDirty,
  });
}

class ProjectErrorState extends ProjectState {
  final String message;

  const ProjectErrorState(this.message);
}

/// プロジェクトNotifierのProvider
final projectNotifierProvider =
    StateNotifierProvider<ProjectNotifier, ProjectState>((ref) {
  final repository = ref.watch(projectRepositoryProvider);
  final recentService = ref.watch(recentProjectsServiceProvider);
  return ProjectNotifier(repository, recentService);
});
