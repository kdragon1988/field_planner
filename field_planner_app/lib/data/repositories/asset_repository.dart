/// アセットリポジトリ
/// 
/// 内蔵アセットの管理、お気に入り・使用履歴の永続化を担当。
/// マニフェストファイルからアセット定義を読み込み、
/// SharedPreferencesでユーザーデータを保存する。
/// 
/// 主な機能:
/// - 内蔵アセットのマニフェスト読み込み
/// - カテゴリ別フィルタリング
/// - キーワード検索
/// - お気に入り管理
/// - 使用履歴（最近使用したアセット）
/// 
/// 制限事項:
/// - カスタムアセットの追加は将来の機能
/// - サムネイル画像の動的生成は未サポート

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset.dart';

/// アセットリポジトリ
class AssetRepository {
  /// マニフェストファイルのパス
  static const String _manifestPath = 'assets/models/assets_manifest.json';

  /// お気に入りアセットIDの保存キー
  static const String _favoritesKey = 'asset_favorites';

  /// 使用履歴の保存キー
  static const String _usageHistoryKey = 'asset_usage_history';

  /// キャッシュされたアセットリスト
  List<Asset>? _cachedAssets;

  /// SharedPreferencesインスタンス
  SharedPreferences? _prefs;

  /// SharedPreferencesを初期化
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 全アセットを取得
  /// 
  /// マニフェストファイルからアセットを読み込み、
  /// お気に入り・使用回数情報を付加して返す
  Future<List<Asset>> getAllAssets() async {
    if (_cachedAssets != null) {
      return _cachedAssets!;
    }

    try {
      // マニフェストを読み込み
      final manifestJson = await rootBundle.loadString(_manifestPath);
      final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;

      final assetsJson = manifest['assets'] as List<dynamic>;
      var assets = assetsJson
          .map((json) => _parseAssetJson(json as Map<String, dynamic>))
          .toList();

      // お気に入り・使用回数を反映
      assets = await _applyUserData(assets);

      _cachedAssets = assets;
      return assets;
    } catch (e) {
      // マニフェストファイルが存在しない場合はサンプルアセットを返す
      return SampleAssets.all;
    }
  }

  /// JSONからAssetオブジェクトを生成
  Asset _parseAssetJson(Map<String, dynamic> json) {
    // カテゴリを文字列からenumに変換
    final categoryStr = json['category'] as String? ?? 'other';
    final category = AssetCategory.values.firstWhere(
      (c) => c.id == categoryStr,
      orElse: () => AssetCategory.other,
    );

    // 寸法を解析
    final dimensionsJson = json['dimensions'] as Map<String, dynamic>?;
    final dimensions = dimensionsJson != null
        ? AssetDimensions(
            width: (dimensionsJson['width'] as num?)?.toDouble() ?? 1.0,
            depth: (dimensionsJson['depth'] as num?)?.toDouble() ?? 1.0,
            height: (dimensionsJson['height'] as num?)?.toDouble() ?? 1.0,
          )
        : const AssetDimensions(width: 1, depth: 1, height: 1);

    // タグをリストに変換
    final tagsJson = json['tags'] as List<dynamic>?;
    final tags = tagsJson?.map((t) => t.toString()).toList() ?? [];

    return Asset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: category,
      modelPath: json['modelPath'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String?,
      dimensions: dimensions,
      defaultScale: (json['defaultScale'] as num?)?.toDouble() ?? 1.0,
      tags: tags,
      isBuiltIn: json['isBuiltIn'] as bool? ?? true,
    );
  }

  /// カテゴリでアセットをフィルタ
  Future<List<Asset>> getAssetsByCategory(AssetCategory category) async {
    final assets = await getAllAssets();
    return assets.where((a) => a.category == category).toList();
  }

  /// キーワードでアセットを検索
  /// 
  /// 名前、説明、タグを対象に部分一致検索を行う
  Future<List<Asset>> searchAssets(String keyword) async {
    final assets = await getAllAssets();
    final lowerKeyword = keyword.toLowerCase();

    return assets.where((a) {
      return a.name.toLowerCase().contains(lowerKeyword) ||
          (a.description?.toLowerCase().contains(lowerKeyword) ?? false) ||
          a.tags.any((t) => t.toLowerCase().contains(lowerKeyword));
    }).toList();
  }

  /// お気に入りアセットを取得
  Future<List<Asset>> getFavoriteAssets() async {
    final assets = await getAllAssets();
    return assets.where((a) => a.isFavorite).toList();
  }

  /// 最近使用したアセットを取得
  /// 
  /// [limit] 取得する最大件数
  Future<List<Asset>> getRecentAssets({int limit = 10}) async {
    final assets = await getAllAssets();
    final sorted = assets.toList()
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return sorted.where((a) => a.usageCount > 0).take(limit).toList();
  }

  /// お気に入りを切り替え
  /// 
  /// [assetId] 対象アセットのID
  Future<void> toggleFavorite(String assetId) async {
    final prefs = await _getPrefs();
    final favorites = _getFavorites(prefs);

    if (favorites.contains(assetId)) {
      favorites.remove(assetId);
    } else {
      favorites.add(assetId);
    }

    await prefs.setStringList(_favoritesKey, favorites);

    // キャッシュを更新
    if (_cachedAssets != null) {
      final index = _cachedAssets!.indexWhere((a) => a.id == assetId);
      if (index != -1) {
        _cachedAssets![index] = _cachedAssets![index].copyWith(
          isFavorite: favorites.contains(assetId),
        );
      }
    }
  }

  /// 使用回数をインクリメント
  /// 
  /// [assetId] 対象アセットのID
  Future<void> incrementUsage(String assetId) async {
    final prefs = await _getPrefs();
    final usageMap = _getUsageMap(prefs);

    usageMap[assetId] = (usageMap[assetId] ?? 0) + 1;

    await prefs.setString(_usageHistoryKey, jsonEncode(usageMap));

    // キャッシュを更新
    if (_cachedAssets != null) {
      final index = _cachedAssets!.indexWhere((a) => a.id == assetId);
      if (index != -1) {
        _cachedAssets![index] = _cachedAssets![index].copyWith(
          usageCount: usageMap[assetId]!,
        );
      }
    }
  }

  /// アセットのモデルパスを取得（フルパス）
  String getModelFullPath(Asset asset) {
    if (asset.modelPath.startsWith('assets/')) {
      return asset.modelPath;
    }
    return 'assets/models/${asset.modelPath}';
  }

  /// アセットのサムネイルパスを取得（フルパス）
  String? getThumbnailFullPath(Asset asset) {
    if (asset.thumbnailPath == null) return null;
    if (asset.thumbnailPath!.startsWith('assets/')) {
      return asset.thumbnailPath;
    }
    return 'assets/models/${asset.thumbnailPath}';
  }

  /// キャッシュをクリア
  void clearCache() {
    _cachedAssets = null;
  }

  // ============================
  // プライベートメソッド
  // ============================

  /// ユーザーデータ（お気に入り・使用回数）をアセットに適用
  Future<List<Asset>> _applyUserData(List<Asset> assets) async {
    final prefs = await _getPrefs();
    final favorites = _getFavorites(prefs);
    final usageMap = _getUsageMap(prefs);

    return assets.map((a) => a.copyWith(
      isFavorite: favorites.contains(a.id),
      usageCount: usageMap[a.id] ?? 0,
    )).toList();
  }

  /// お気に入りリストを取得
  List<String> _getFavorites(SharedPreferences prefs) {
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  /// 使用回数マップを取得
  Map<String, int> _getUsageMap(SharedPreferences prefs) {
    final json = prefs.getString(_usageHistoryKey);
    if (json == null) return {};
    try {
      return Map<String, int>.from(jsonDecode(json) as Map);
    } catch (_) {
      return {};
    }
  }
}
