/// ドローンフォーメーションリポジトリ
/// 
/// ドローンフォーメーションデータの読み込み・保存を担当。
/// 外部JSONファイルからのインポートと、プロジェクト内での管理を行う。
/// 
/// 主な機能:
/// - JSONファイルからのインポート
/// - フォーメーションデータの保存・読み込み
/// - 配置済みフォーメーションの管理
/// 
/// 制限事項:
/// - 対応するJSONフォーマットはt2i_generated形式のみ
/// - 大量のドローン（数千機）の場合はメモリ使用量に注意

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../models/drone_formation.dart';

/// ドローンフォーメーションリポジトリ
class DroneFormationRepository {
  /// フォーメーション定義ファイル名
  static const String _formationsFileName = 'drone_formations.json';

  /// 配置済みフォーメーションファイル名
  static const String _placedFormationsFileName = 'placed_drone_formations.json';

  /// ファイルバージョン
  static const String _currentVersion = '1.0.0';

  /// UUIDジェネレータ
  final Uuid _uuid = const Uuid();

  /// 外部JSONファイルからドローンフォーメーションをインポート
  /// 
  /// [filePath] インポート元JSONファイルのパス
  /// [name] フォーメーション名（省略時はファイル名を使用）
  /// 
  /// JSONフォーマット例:
  /// ```json
  /// [
  ///   {"id": "drone-0", "x": 5.06, "y": 26.71, "r": 222, "g": 105, "b": 144, "a": 84, ...},
  ///   ...
  /// ]
  /// ```
  Future<DroneFormation> importFromFile(
    String filePath, {
    String? name,
  }) async {
    final file = File(filePath);
    
    if (!await file.exists()) {
      throw FileSystemException('ファイルが見つかりません', filePath);
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content);

      if (json is! List) {
        throw const FormatException('JSONは配列形式である必要があります');
      }

      final drones = <DronePosition>[];
      for (final item in json) {
        if (item is! Map<String, dynamic>) continue;
        
        final drone = DronePosition(
          id: item['id']?.toString() ?? 'drone-${drones.length}',
          x: (item['x'] as num?)?.toDouble() ?? 0.0,
          y: (item['y'] as num?)?.toDouble() ?? 0.0,
          r: (item['r'] as num?)?.toInt() ?? 255,
          g: (item['g'] as num?)?.toInt() ?? 255,
          b: (item['b'] as num?)?.toInt() ?? 255,
          a: (item['a'] as num?)?.toInt() ?? 255,
          detectionSource: item['detectionSource']?.toString(),
        );
        drones.add(drone);
      }

      if (drones.isEmpty) {
        throw const FormatException('有効なドローンデータがありません');
      }

      // ファイル名からデフォルト名を生成
      final fileName = path.basenameWithoutExtension(filePath);
      final formationName = name ?? fileName;

      return DroneFormation(
        id: _uuid.v4(),
        name: formationName,
        drones: drones,
        sourceFileName: path.basename(filePath),
        importedAt: DateTime.now(),
        metadata: {
          'originalPath': filePath,
          'importedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      if (e is FormatException || e is FileSystemException) {
        rethrow;
      }
      throw FormatException('JSONの解析に失敗しました: $e');
    }
  }

  /// プロジェクトにフォーメーションを保存
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [formation] 保存するフォーメーション
  Future<void> saveFormation(
    String projectPath,
    DroneFormation formation,
  ) async {
    final formations = await loadFormations(projectPath);
    
    // 既存のフォーメーションを更新または追加
    final index = formations.indexWhere((f) => f.id == formation.id);
    if (index != -1) {
      formations[index] = formation;
    } else {
      formations.add(formation);
    }

    await _saveFormations(projectPath, formations);
  }

  /// プロジェクトからフォーメーション一覧を読み込み
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  Future<List<DroneFormation>> loadFormations(String projectPath) async {
    final file = File(path.join(projectPath, _formationsFileName));

    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final formationsJson = json['formations'] as List<dynamic>?;
      if (formationsJson == null) return [];

      return formationsJson
          .map((e) => DroneFormation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('DroneFormationRepository: Failed to load formations: $e');
      return [];
    }
  }

  /// フォーメーションを削除
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [formationId] 削除するフォーメーションのID
  Future<void> removeFormation(String projectPath, String formationId) async {
    final formations = await loadFormations(projectPath);
    formations.removeWhere((f) => f.id == formationId);
    await _saveFormations(projectPath, formations);

    // 関連する配置済みフォーメーションも削除
    final placedFormations = await loadPlacedFormations(projectPath);
    final filtered = placedFormations
        .where((p) => p.formationId != formationId)
        .toList();
    await _savePlacedFormations(projectPath, filtered);
  }

  /// 配置済みフォーメーションを保存
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [placedFormation] 保存する配置済みフォーメーション
  Future<void> savePlacedFormation(
    String projectPath,
    PlacedDroneFormation placedFormation,
  ) async {
    final placedFormations = await loadPlacedFormations(projectPath);
    
    final index = placedFormations.indexWhere((p) => p.id == placedFormation.id);
    if (index != -1) {
      placedFormations[index] = placedFormation;
    } else {
      placedFormations.add(placedFormation);
    }

    await _savePlacedFormations(projectPath, placedFormations);
  }

  /// 配置済みフォーメーション一覧を読み込み
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  Future<List<PlacedDroneFormation>> loadPlacedFormations(
    String projectPath,
  ) async {
    final file = File(path.join(projectPath, _placedFormationsFileName));

    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final placedJson = json['placedFormations'] as List<dynamic>?;
      if (placedJson == null) return [];

      return placedJson
          .map((e) => PlacedDroneFormation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint(
        'DroneFormationRepository: Failed to load placed formations: $e',
      );
      return [];
    }
  }

  /// 配置済みフォーメーションを更新
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [placedFormation] 更新する配置済みフォーメーション
  Future<void> updatePlacedFormation(
    String projectPath,
    PlacedDroneFormation placedFormation,
  ) async {
    final placedFormations = await loadPlacedFormations(projectPath);
    final index = placedFormations.indexWhere((p) => p.id == placedFormation.id);

    if (index != -1) {
      placedFormations[index] = placedFormation.copyWith(
        updatedAt: DateTime.now(),
      );
      await _savePlacedFormations(projectPath, placedFormations);
    }
  }

  /// 配置済みフォーメーションを削除
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [placedFormationId] 削除する配置済みフォーメーションのID
  Future<void> removePlacedFormation(
    String projectPath,
    String placedFormationId,
  ) async {
    final placedFormations = await loadPlacedFormations(projectPath);
    placedFormations.removeWhere((p) => p.id == placedFormationId);
    await _savePlacedFormations(projectPath, placedFormations);
  }

  /// IDでフォーメーションを取得
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [formationId] フォーメーションID
  Future<DroneFormation?> getFormationById(
    String projectPath,
    String formationId,
  ) async {
    final formations = await loadFormations(projectPath);
    try {
      return formations.firstWhere((f) => f.id == formationId);
    } catch (_) {
      return null;
    }
  }

  /// IDで配置済みフォーメーションを取得
  /// 
  /// [projectPath] プロジェクトディレクトリのパス
  /// [placedFormationId] 配置済みフォーメーションID
  Future<PlacedDroneFormation?> getPlacedFormationById(
    String projectPath,
    String placedFormationId,
  ) async {
    final placedFormations = await loadPlacedFormations(projectPath);
    try {
      return placedFormations.firstWhere((p) => p.id == placedFormationId);
    } catch (_) {
      return null;
    }
  }

  // ============================
  // プライベートメソッド
  // ============================

  /// フォーメーション一覧をファイルに保存
  Future<void> _saveFormations(
    String projectPath,
    List<DroneFormation> formations,
  ) async {
    final file = File(path.join(projectPath, _formationsFileName));

    final data = {
      'version': _currentVersion,
      'savedAt': DateTime.now().toIso8601String(),
      'formations': formations.map((f) => f.toJson()).toList(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }

  /// 配置済みフォーメーション一覧をファイルに保存
  Future<void> _savePlacedFormations(
    String projectPath,
    List<PlacedDroneFormation> placedFormations,
  ) async {
    final file = File(path.join(projectPath, _placedFormationsFileName));

    final data = {
      'version': _currentVersion,
      'savedAt': DateTime.now().toIso8601String(),
      'placedFormations': placedFormations.map((p) => p.toJson()).toList(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }
}
