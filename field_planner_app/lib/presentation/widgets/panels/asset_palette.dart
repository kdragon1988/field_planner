/// アセットパレット
/// 
/// カテゴリ別にアセットを表示し、選択・配置を行うパネル。
/// 通常のアセットに加えて、ドローンフォーメーションの
/// インポート・配置機能も提供する。
/// 
/// 主な機能:
/// - カテゴリ別アセット一覧
/// - お気に入り・最近使用したアセット
/// - ドローンフォーメーションタブ
/// - 検索機能

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/asset.dart';
import '../../../data/models/drone_formation.dart';
import '../../providers/asset_provider.dart';
import '../../providers/placement_provider.dart';
import '../dialogs/drone_import_dialog.dart';

/// アセットパレット
class AssetPalette extends ConsumerStatefulWidget {
  /// アセット選択時のコールバック
  final void Function(Asset asset)? onAssetSelected;

  /// ドローンフォーメーション選択時のコールバック
  final void Function(DroneFormation formation)? onDroneFormationSelected;

  const AssetPalette({
    super.key,
    this.onAssetSelected,
    this.onDroneFormationSelected,
  });

  @override
  ConsumerState<AssetPalette> createState() => _AssetPaletteState();
}

class _AssetPaletteState extends ConsumerState<AssetPalette>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  AssetCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 検索バー
        _buildSearchBar(),

        // タブ
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'カテゴリ'),
            Tab(text: 'お気に入り'),
            Tab(text: '最近使用'),
            Tab(text: 'ドローン'),
          ],
        ),

        // タブビュー
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryView(),
              _buildFavoritesView(),
              _buildRecentView(),
              _buildDroneFormationView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'アセットを検索...',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildCategoryView() {
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    if (_selectedCategory != null) {
      return _buildCategoryAssets(_selectedCategory!);
    }

    return _buildCategoryList();
  }

  Widget _buildCategoryList() {
    final assetsAsync = ref.watch(allAssetsProvider);

    return assetsAsync.when(
      data: (assets) {
        // ドローンショーを除いたカテゴリ一覧
        final categories = AssetCategory.values
            .where((c) => c != AssetCategory.droneShow)
            .toList();

        return ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final count = assets.where((a) => a.category == category).length;

            return ListTile(
              leading: Icon(_getCategoryIcon(category)),
              title: Text(category.displayName),
              trailing: Text('$count'),
              onTap: () {
                setState(() => _selectedCategory = category);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }

  Widget _buildCategoryAssets(AssetCategory category) {
    final assetsAsync = ref.watch(assetsByCategoryProvider(category));

    return Column(
      children: [
        // 戻るヘッダ
        ListTile(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() => _selectedCategory = null);
            },
          ),
          title: Text(category.displayName),
        ),
        const Divider(height: 1),
        // アセットグリッド
        Expanded(
          child: assetsAsync.when(
            data: (assets) {
              if (assets.isEmpty) {
                return const Center(child: Text('アセットがありません'));
              }
              return _buildAssetGrid(assets);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('エラー: $error')),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final assetsAsync = ref.watch(searchAssetsProvider(_searchQuery));

    return assetsAsync.when(
      data: (assets) {
        if (assets.isEmpty) {
          return const Center(
            child: Text('該当するアセットがありません'),
          );
        }
        return _buildAssetGrid(assets);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }

  Widget _buildFavoritesView() {
    final assetsAsync = ref.watch(favoriteAssetsProvider);

    return assetsAsync.when(
      data: (assets) {
        if (assets.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('お気に入りがありません'),
                Text(
                  'ハートをタップして追加してください',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return _buildAssetGrid(assets);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }

  Widget _buildRecentView() {
    final assetsAsync = ref.watch(recentAssetsProvider);

    return assetsAsync.when(
      data: (assets) {
        if (assets.isEmpty) {
          return const Center(
            child: Text('最近使用したアセットがありません'),
          );
        }
        return _buildAssetGrid(assets);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }

  Widget _buildDroneFormationView() {
    final formationsAsync = ref.watch(droneFormationsProvider);

    return Column(
      children: [
        // インポートボタン
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showImportDialog,
              icon: const Icon(Icons.upload_file),
              label: const Text('JSONからインポート'),
            ),
          ),
        ),
        const Divider(height: 1),
        // フォーメーション一覧
        Expanded(
          child: formationsAsync.when(
            data: (formations) {
              if (formations.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flight, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('ドローンフォーメーションがありません'),
                      Text(
                        'JSONファイルをインポートしてください',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }
              return _buildDroneFormationList(formations);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('エラー: $error')),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetGrid(List<Asset> assets) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        return _AssetCard(
          asset: assets[index],
          onTap: () => _onAssetTap(assets[index]),
          onFavoriteToggle: () => _onFavoriteToggle(assets[index]),
        );
      },
    );
  }

  Widget _buildDroneFormationList(List<DroneFormation> formations) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: formations.length,
      itemBuilder: (context, index) {
        final formation = formations[index];
        return _DroneFormationCard(
          formation: formation,
          onTap: () => _onDroneFormationTap(formation),
          onDelete: () => _onDroneFormationDelete(formation),
        );
      },
    );
  }

  void _onAssetTap(Asset asset) {
    widget.onAssetSelected?.call(asset);

    // 配置モードを開始
    final repository = ref.read(assetRepositoryProvider);
    final modelUrl = repository.getModelFullPath(asset);
    ref.read(placementControllerProvider)?.startPlacementMode(asset.id, modelUrl);
  }

  void _onFavoriteToggle(Asset asset) {
    ref.read(assetNotifierProvider.notifier).toggleFavorite(asset.id);
  }

  void _onDroneFormationTap(DroneFormation formation) {
    widget.onDroneFormationSelected?.call(formation);
    
    // ドローン配置ダイアログを表示
    _showDronePlacementDialog(formation);
  }

  void _onDroneFormationDelete(DroneFormation formation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('フォーメーションを削除'),
        content: Text('「${formation.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(assetNotifierProvider.notifier).deleteDroneFormation(formation.id);
    }
  }

  void _showImportDialog() async {
    final result = await showDialog<DroneFormation>(
      context: context,
      builder: (context) => const DroneImportDialog(),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${result.name}」をインポートしました（${result.droneCount}機）'),
        ),
      );
    }
  }

  void _showDronePlacementDialog(DroneFormation formation) async {
    // 配置設定ダイアログを表示
    final settings = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DronePlacementSettingsDialog(formation: formation),
    );

    if (settings == null || !mounted) return;

    // 地図上でのクリック待ちモードを開始
    final controller = ref.read(placementControllerProvider);
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('マップが初期化されていません')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('地図上をクリックして「${formation.name}」の配置位置を指定してください'),
        duration: const Duration(seconds: 5),
      ),
    );

    // 配置位置が指定されるまで待機するためのリスナーを設定
    controller.startDronePlacementMode(
      formation: formation,
      altitude: settings['altitude'] as double,
      scale: settings['scale'] as double,
      pointSize: settings['pointSize'] as double,
      useIndividualColors: settings['useIndividualColors'] as bool,
      customColor: settings['customColor'] as String?,
    );
  }

  IconData _getCategoryIcon(AssetCategory category) {
    switch (category) {
      case AssetCategory.tent:
        return Icons.home;
      case AssetCategory.stage:
        return Icons.music_note;
      case AssetCategory.barrier:
        return Icons.fence;
      case AssetCategory.table:
        return Icons.table_restaurant;
      case AssetCategory.chair:
        return Icons.chair;
      case AssetCategory.lighting:
        return Icons.light;
      case AssetCategory.signage:
        return Icons.signpost;
      case AssetCategory.droneShow:
        return Icons.flight;
      case AssetCategory.other:
        return Icons.more_horiz;
    }
  }
}

/// アセットカード
class _AssetCard extends StatelessWidget {
  final Asset asset;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _AssetCard({
    required this.asset,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // サムネイル
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(
                      Icons.view_in_ar,
                      size: 48,
                    ),
                  ),
                  // お気に入りボタン
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: Icon(
                        asset.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: asset.isFavorite ? Colors.red : Colors.white,
                        size: 20,
                      ),
                      onPressed: onFavoriteToggle,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 情報
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    asset.dimensions.toString(),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ドローンフォーメーションカード
class _DroneFormationCard extends StatelessWidget {
  final DroneFormation formation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DroneFormationCard({
    required this.formation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // アイコン
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.flight,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              // 情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formation.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${formation.droneCount}機 · ${formation.width.toStringAsFixed(1)}m × ${formation.depth.toStringAsFixed(1)}m',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // 削除ボタン
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
