/// 配置物リポジトリ
/// 
/// 配置物データの永続化を担当。
/// プロジェクトディレクトリ内のplacements.jsonファイルに
/// 配置物情報を保存・読み込みする。
/// 
/// 主な機能:
/// - 配置物一覧の読み込み・保存
/// - 個別配置物の追加・更新・削除
/// - グループ情報の管理
/// 
/// 制限事項:
/// - ファイルロックは未実装（同時アクセス対策なし）
/// - 大量の配置物（数万件）でのパフォーマンスは未検証

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../models/placement.dart';

/// 配置物リポジトリ
class PlacementRepository {
  /// 配置物ファイル名
  static const String _fileName = 'placements.json';

  /// ファイルバージョン
  static const String _currentVersion = '1.0.0';

  /// 配置物一覧を読み込み
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// 
  /// ファイルが存在しない場合は空のリストを返す
  Future<List<Placement>> loadPlacements(String projectPath) async {
    final file = File(path.join(projectPath, _fileName));

    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content);

      if (json is List) {
        // 旧形式（配列のみ）
        return json
            .map((e) => Placement.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // 新形式（バージョン情報含む）
      final data = json as Map<String, dynamic>;
      final placementsJson = data['placements'] as List<dynamic>?;
      if (placementsJson == null) return [];

      return placementsJson
          .map((e) => Placement.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PlacementRepository: Failed to load placements: $e');
      return [];
    }
  }

  /// 配置物グループ一覧を読み込み
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  Future<List<PlacementGroup>> loadGroups(String projectPath) async {
    final file = File(path.join(projectPath, _fileName));

    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content);

      if (json is! Map<String, dynamic>) {
        return [];
      }

      final groupsJson = json['groups'] as List<dynamic>?;
      if (groupsJson == null) return [];

      return groupsJson
          .map((e) => PlacementGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PlacementRepository: Failed to load groups: $e');
      return [];
    }
  }

  /// 配置物一覧を保存
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [placements] 配置物リスト
  /// [groups] グループリスト（オプション）
  Future<void> savePlacements(
    String projectPath,
    List<Placement> placements, {
    List<PlacementGroup>? groups,
  }) async {
    final file = File(path.join(projectPath, _fileName));

    final data = {
      'version': _currentVersion,
      'savedAt': DateTime.now().toIso8601String(),
      'placements': placements.map((p) => p.toJson()).toList(),
      'groups': (groups ?? []).map((g) => g.toJson()).toList(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }

  /// 単一配置物を追加
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [placement] 追加する配置物
  Future<void> addPlacement(String projectPath, Placement placement) async {
    final placements = await loadPlacements(projectPath);
    final groups = await loadGroups(projectPath);
    placements.add(placement);
    await savePlacements(projectPath, placements, groups: groups);
  }

  /// 配置物を更新
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [placement] 更新する配置物
  Future<void> updatePlacement(String projectPath, Placement placement) async {
    final placements = await loadPlacements(projectPath);
    final groups = await loadGroups(projectPath);
    final index = placements.indexWhere((p) => p.id == placement.id);
    
    if (index != -1) {
      placements[index] = placement.copyWith(updatedAt: DateTime.now());
      await savePlacements(projectPath, placements, groups: groups);
    }
  }

  /// 配置物を削除
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [placementId] 削除する配置物のID
  Future<void> removePlacement(String projectPath, String placementId) async {
    final placements = await loadPlacements(projectPath);
    final groups = await loadGroups(projectPath);
    placements.removeWhere((p) => p.id == placementId);
    await savePlacements(projectPath, placements, groups: groups);
  }

  /// 複数の配置物を削除
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [placementIds] 削除する配置物のIDリスト
  Future<void> removePlacements(
    String projectPath,
    List<String> placementIds,
  ) async {
    final placements = await loadPlacements(projectPath);
    final groups = await loadGroups(projectPath);
    placements.removeWhere((p) => placementIds.contains(p.id));
    await savePlacements(projectPath, placements, groups: groups);
  }

  /// グループを追加
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [group] 追加するグループ
  Future<void> addGroup(String projectPath, PlacementGroup group) async {
    final placements = await loadPlacements(projectPath);
    final groups = await loadGroups(projectPath);
    groups.add(group);
    await savePlacements(projectPath, placements, groups: groups);
  }

  /// グループを削除
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [groupId] 削除するグループのID
  /// [removePlacements] グループ内の配置物も削除するか
  Future<void> removeGroup(
    String projectPath,
    String groupId, {
    bool removePlacements = false,
  }) async {
    var placements = await loadPlacements(projectPath);
    final groups = await loadGroups(projectPath);

    if (removePlacements) {
      // グループ内の配置物を削除
      placements = placements.where((p) => p.groupId != groupId).toList();
    } else {
      // グループIDをnullに設定
      placements = placements.map((p) {
        if (p.groupId == groupId) {
          return p.copyWith(groupId: null);
        }
        return p;
      }).toList();
    }

    groups.removeWhere((g) => g.id == groupId);
    await savePlacements(projectPath, placements, groups: groups);
  }

  /// 配置物をグループに追加
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [placementId] 配置物ID
  /// [groupId] グループID
  Future<void> addPlacementToGroup(
    String projectPath,
    String placementId,
    String groupId,
  ) async {
    final placements = await loadPlacements(projectPath);
    final groups = await loadGroups(projectPath);
    final index = placements.indexWhere((p) => p.id == placementId);
    
    if (index != -1) {
      placements[index] = placements[index].copyWith(
        groupId: groupId,
        updatedAt: DateTime.now(),
      );
      await savePlacements(projectPath, placements, groups: groups);
    }
  }

  /// 配置物ファイルが存在するか確認
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  Future<bool> exists(String projectPath) async {
    final file = File(path.join(projectPath, _fileName));
    return file.exists();
  }
}
