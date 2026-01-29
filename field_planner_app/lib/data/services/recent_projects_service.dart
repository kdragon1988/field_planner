import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

/// 最近使ったプロジェクト情報
class RecentProject {
  /// プロジェクトパス
  final String path;

  /// プロジェクト名
  final String name;

  /// 最終アクセス日時
  final DateTime lastAccessedAt;

  const RecentProject({
    required this.path,
    required this.name,
    required this.lastAccessedAt,
  });

  factory RecentProject.fromJson(Map<String, dynamic> json) {
    return RecentProject(
      path: json['path'] as String,
      name: json['name'] as String,
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
      };
}

/// 最近使ったプロジェクトサービス
///
/// MRUリストの管理を行う
class RecentProjectsService with LoggableMixin {
  static const String _prefsKey = 'recent_projects';

  final SharedPreferences _prefs;

  RecentProjectsService(this._prefs);

  /// 最近使ったプロジェクト一覧を取得
  List<RecentProject> getRecentProjects() {
    final jsonString = _prefs.getString(_prefsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final list = jsonDecode(jsonString) as List;
      return list
          .map((e) => RecentProject.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logError('Failed to parse recent projects', e);
      return [];
    }
  }

  /// プロジェクトを開いた際に記録
  Future<void> addProject(String path, String name) async {
    final projects = getRecentProjects().toList();

    // 既存エントリを削除
    projects.removeWhere((p) => p.path == path);

    // 新規エントリを先頭に追加
    projects.insert(
      0,
      RecentProject(
        path: path,
        name: name,
        lastAccessedAt: DateTime.now(),
      ),
    );

    // 最大件数を超えた分を削除
    while (projects.length > AppConstants.maxRecentProjects) {
      projects.removeLast();
    }

    await _saveProjects(projects);
    logDebug('Added to recent projects: $name');
  }

  /// プロジェクトをリストから削除
  Future<void> removeProject(String path) async {
    final projects = getRecentProjects().toList();
    projects.removeWhere((p) => p.path == path);
    await _saveProjects(projects);
    logDebug('Removed from recent projects: $path');
  }

  /// リストをクリア
  Future<void> clearAll() async {
    await _prefs.remove(_prefsKey);
    logDebug('Cleared all recent projects');
  }

  Future<void> _saveProjects(List<RecentProject> projects) async {
    final json = jsonEncode(projects.map((p) => p.toJson()).toList());
    await _prefs.setString(_prefsKey, json);
  }
}
