import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/utils/logger.dart';
import '../models/project.dart';

/// プロジェクトリポジトリ
///
/// プロジェクトの読み書き、フォルダ構造管理を担当
class ProjectRepository with LoggableMixin {
  static const String projectFileName = 'project.json';
  static const String projectExtension = AppConstants.projectExtension;

  /// 新規プロジェクトを作成
  ///
  /// [basePath] 保存先ディレクトリ
  /// [project] プロジェクトデータ
  ///
  /// Returns: 作成されたプロジェクトフォルダのパス
  Future<String> createProject(String basePath, Project project) async {
    final projectDirName = '${project.name}$projectExtension';
    final projectPath = p.join(basePath, projectDirName);

    logInfo('Creating project at: $projectPath');

    // プロジェクトフォルダ構造を作成
    await _createProjectStructure(projectPath);

    // project.jsonを保存
    await _saveProjectJson(projectPath, project);

    // 空のplacements.jsonを作成
    await _createEmptyJson(p.join(projectPath, 'placements.json'), []);

    // 空のmeasurements.jsonを作成
    await _createEmptyJson(p.join(projectPath, 'measurements.json'), []);

    logInfo('Project created successfully');
    return projectPath;
  }

  /// プロジェクトを開く
  ///
  /// [projectPath] プロジェクトフォルダのパス
  ///
  /// Returns: プロジェクトデータ
  /// Throws: [ProjectLoadException] 読み込みエラー時
  Future<Project> openProject(String projectPath) async {
    final projectFile = File(p.join(projectPath, projectFileName));

    if (!await projectFile.exists()) {
      throw ProjectLoadException(
        'project.json が見つかりません',
        projectPath: projectPath,
      );
    }

    try {
      final content = await projectFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // スキーマバージョンチェックとマイグレーション
      final project = _migrateIfNeeded(json);

      logInfo('Project opened: ${project.name}');
      return project;
    } catch (e) {
      throw ProjectLoadException(
        'プロジェクトの読み込みに失敗しました: $e',
        projectPath: projectPath,
        cause: e,
      );
    }
  }

  /// プロジェクトを保存
  Future<void> saveProject(String projectPath, Project project) async {
    final updatedProject = project.copyWith(updatedAt: DateTime.now());
    await _saveProjectJson(projectPath, updatedProject);
    logInfo('Project saved: ${project.name}');
  }

  /// プロジェクトを別名で保存
  ///
  /// [sourcePath] 元のプロジェクトパス
  /// [destPath] 保存先パス
  /// [newName] 新しいプロジェクト名
  Future<String> saveProjectAs(
    String sourcePath,
    String destPath,
    String newName,
  ) async {
    final newProjectPath = p.join(destPath, '$newName$projectExtension');

    // フォルダをコピー
    await _copyDirectory(Directory(sourcePath), Directory(newProjectPath));

    // プロジェクト情報を更新
    final project = await openProject(newProjectPath);
    final renamedProject = project.copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
    await saveProject(newProjectPath, renamedProject);

    logInfo('Project saved as: $newName');
    return newProjectPath;
  }

  /// プロジェクトの整合性をチェック
  Future<ProjectValidationResult> validateProject(String projectPath) async {
    final errors = <String>[];
    final warnings = <String>[];

    // project.json存在チェック
    if (!await File(p.join(projectPath, projectFileName)).exists()) {
      errors.add('project.json が見つかりません');
    }

    // 必須フォルダチェック
    final requiredDirs = ['layers', 'imports', 'thumbnails'];
    for (final dir in requiredDirs) {
      if (!await Directory(p.join(projectPath, dir)).exists()) {
        warnings.add('$dir フォルダが見つかりません');
      }
    }

    // データレイヤー参照チェック
    try {
      final project = await openProject(projectPath);
      for (final layer in project.dataLayers) {
        final layerPath = p.join(projectPath, layer.path);
        if (!await Directory(layerPath).exists() &&
            !await File(layerPath).exists()) {
          errors.add('レイヤー "${layer.name}" のデータが見つかりません: ${layer.path}');
        }
      }
    } catch (e) {
      errors.add('プロジェクト設定の読み込みに失敗: $e');
    }

    return ProjectValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// プロジェクトが存在するかチェック
  Future<bool> projectExists(String projectPath) async {
    final projectFile = File(p.join(projectPath, projectFileName));
    return projectFile.exists();
  }

  // プライベートメソッド

  Future<void> _createProjectStructure(String projectPath) async {
    await Directory(projectPath).create(recursive: true);
    await Directory(p.join(projectPath, 'layers')).create();
    await Directory(p.join(projectPath, 'imports')).create();
    await Directory(p.join(projectPath, 'thumbnails')).create();
    await Directory(p.join(projectPath, 'backups')).create();
  }

  Future<void> _saveProjectJson(String projectPath, Project project) async {
    final file = File(p.join(projectPath, projectFileName));
    final encoder = const JsonEncoder.withIndent('  ');
    final json = encoder.convert(project.toJson());
    await file.writeAsString(json, flush: true);
  }

  Future<void> _createEmptyJson(String path, dynamic initialData) async {
    final file = File(path);
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(initialData));
  }

  Project _migrateIfNeeded(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as String? ?? '1.0.0';

    // バージョンに応じたマイグレーション処理
    // 現在は1.0.0のみなのでそのまま返す
    logDebug('Project schema version: $version');
    return Project.fromJson(json);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);

    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(
        destination.path,
        p.basename(entity.path),
      );

      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }
}

/// プロジェクト検証結果
class ProjectValidationResult {
  /// 検証成功フラグ
  final bool isValid;

  /// エラー一覧
  final List<String> errors;

  /// 警告一覧
  final List<String> warnings;

  ProjectValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}
