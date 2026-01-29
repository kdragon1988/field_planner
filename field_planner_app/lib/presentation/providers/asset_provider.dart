/// アセットプロバイダー
/// 
/// アセット管理に関する状態とロジックを提供。
/// AssetRepositoryとDroneFormationRepositoryを統合し、
/// UIからアセット操作を行うためのインターフェースを提供する。
/// 
/// 主な機能:
/// - アセット一覧の取得（カテゴリ別、検索）
/// - お気に入り・使用履歴の管理
/// - ドローンフォーメーションのインポート・管理

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/asset.dart';
import '../../data/models/drone_formation.dart';
import '../../data/repositories/asset_repository.dart';
import '../../data/repositories/drone_formation_repository.dart';
import 'project_provider.dart';

/// AssetRepositoryのプロバイダー
final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository();
});

/// DroneFormationRepositoryのプロバイダー
final droneFormationRepositoryProvider = Provider<DroneFormationRepository>((ref) {
  return DroneFormationRepository();
});

/// 全アセットのプロバイダー
final allAssetsProvider = FutureProvider<List<Asset>>((ref) async {
  final repository = ref.read(assetRepositoryProvider);
  return repository.getAllAssets();
});

/// カテゴリ別アセットのプロバイダー
final assetsByCategoryProvider = FutureProvider.family<List<Asset>, AssetCategory>(
  (ref, category) async {
    final repository = ref.read(assetRepositoryProvider);
    return repository.getAssetsByCategory(category);
  },
);

/// 検索結果のプロバイダー
final searchAssetsProvider = FutureProvider.family<List<Asset>, String>(
  (ref, keyword) async {
    if (keyword.isEmpty) {
      return [];
    }
    final repository = ref.read(assetRepositoryProvider);
    return repository.searchAssets(keyword);
  },
);

/// お気に入りアセットのプロバイダー
final favoriteAssetsProvider = FutureProvider<List<Asset>>((ref) async {
  final repository = ref.read(assetRepositoryProvider);
  return repository.getFavoriteAssets();
});

/// 最近使用したアセットのプロバイダー
final recentAssetsProvider = FutureProvider<List<Asset>>((ref) async {
  final repository = ref.read(assetRepositoryProvider);
  return repository.getRecentAssets();
});

/// プロジェクト内のドローンフォーメーション一覧のプロバイダー
final droneFormationsProvider = FutureProvider<List<DroneFormation>>((ref) async {
  final projectState = ref.watch(projectNotifierProvider);
  final repository = ref.read(droneFormationRepositoryProvider);
  
  if (projectState is! ProjectLoadedState) {
    return [];
  }
  
  return repository.loadFormations(projectState.projectPath);
});

/// プロジェクト内の配置済みドローンフォーメーション一覧のプロバイダー
final placedDroneFormationsProvider = FutureProvider<List<PlacedDroneFormation>>((ref) async {
  final projectState = ref.watch(projectNotifierProvider);
  final repository = ref.read(droneFormationRepositoryProvider);
  
  if (projectState is! ProjectLoadedState) {
    return [];
  }
  
  return repository.loadPlacedFormations(projectState.projectPath);
});

/// 選択中のアセットカテゴリ
final selectedAssetCategoryProvider = StateProvider<AssetCategory?>((ref) => null);

/// 検索キーワード
final assetSearchKeywordProvider = StateProvider<String>((ref) => '');

/// アセット管理用のNotifier
class AssetNotifier extends Notifier<void> {
  @override
  void build() {}

  /// お気に入りを切り替え
  Future<void> toggleFavorite(String assetId) async {
    final repository = ref.read(assetRepositoryProvider);
    await repository.toggleFavorite(assetId);
    
    // 関連するプロバイダーを無効化
    ref.invalidate(allAssetsProvider);
    ref.invalidate(favoriteAssetsProvider);
  }

  /// 使用回数をインクリメント
  Future<void> incrementUsage(String assetId) async {
    final repository = ref.read(assetRepositoryProvider);
    await repository.incrementUsage(assetId);
    
    // 関連するプロバイダーを無効化
    ref.invalidate(allAssetsProvider);
    ref.invalidate(recentAssetsProvider);
  }

  /// ドローンフォーメーションをインポート
  Future<DroneFormation> importDroneFormation(String filePath, {String? name}) async {
    final repository = ref.read(droneFormationRepositoryProvider);
    final formation = await repository.importFromFile(filePath, name: name);
    
    // プロジェクトに保存
    final projectState = ref.read(projectNotifierProvider);
    if (projectState is ProjectLoadedState) {
      await repository.saveFormation(projectState.projectPath, formation);
      ref.invalidate(droneFormationsProvider);
    }
    
    return formation;
  }

  /// ドローンフォーメーションを削除
  Future<void> deleteDroneFormation(String formationId) async {
    final repository = ref.read(droneFormationRepositoryProvider);
    final projectState = ref.read(projectNotifierProvider);
    
    if (projectState is ProjectLoadedState) {
      await repository.removeFormation(projectState.projectPath, formationId);
      ref.invalidate(droneFormationsProvider);
      ref.invalidate(placedDroneFormationsProvider);
    }
  }

  /// キャッシュをクリア
  void clearCache() {
    final repository = ref.read(assetRepositoryProvider);
    repository.clearCache();
    ref.invalidate(allAssetsProvider);
    ref.invalidate(favoriteAssetsProvider);
    ref.invalidate(recentAssetsProvider);
  }
}

/// アセット管理Notifierのプロバイダー
final assetNotifierProvider = NotifierProvider<AssetNotifier, void>(() {
  return AssetNotifier();
});
