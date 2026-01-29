import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/asset.dart';

/// アセットパレット
///
/// カテゴリ別にアセットを表示し、選択・配置を行う
class AssetPalette extends ConsumerStatefulWidget {
  /// アセット選択時のコールバック
  final void Function(Asset asset)? onAssetSelected;

  const AssetPalette({
    super.key,
    this.onAssetSelected,
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
    _tabController = TabController(length: 3, vsync: this);
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
          tabs: const [
            Tab(text: 'カテゴリ'),
            Tab(text: 'お気に入り'),
            Tab(text: '最近使用'),
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
    if (_selectedCategory != null) {
      return _buildAssetGrid(_getFilteredAssets(_selectedCategory!));
    }

    return ListView(
      children: AssetCategory.values.map((category) {
        final count = SampleAssets.all
            .where((a) => a.category == category)
            .length;
        if (count == 0) return const SizedBox.shrink();

        return ListTile(
          leading: Icon(_getCategoryIcon(category)),
          title: Text(category.displayName),
          trailing: Text('$count'),
          onTap: () {
            setState(() => _selectedCategory = category);
          },
        );
      }).toList(),
    );
  }

  Widget _buildFavoritesView() {
    final favorites = SampleAssets.all.where((a) => a.isFavorite).toList();
    if (favorites.isEmpty) {
      return const Center(
        child: Text('お気に入りはありません'),
      );
    }
    return _buildAssetGrid(favorites);
  }

  Widget _buildRecentView() {
    // デモ用に全アセットを表示
    return _buildAssetGrid(SampleAssets.all);
  }

  List<Asset> _getFilteredAssets(AssetCategory category) {
    var assets = SampleAssets.all.where((a) => a.category == category);
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      assets = assets.where((a) =>
          a.name.toLowerCase().contains(query) ||
          a.tags.any((t) => t.toLowerCase().contains(query)));
    }
    
    return assets.toList();
  }

  Widget _buildAssetGrid(List<Asset> assets) {
    return Column(
      children: [
        if (_selectedCategory != null)
          ListTile(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() => _selectedCategory = null);
              },
            ),
            title: Text(_selectedCategory!.displayName),
          ),
        Expanded(
          child: GridView.builder(
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
                onTap: () => widget.onAssetSelected?.call(assets[index]),
              );
            },
          ),
        ),
      ],
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
      case AssetCategory.other:
        return Icons.more_horiz;
    }
  }
}

/// アセットカード
class _AssetCard extends StatelessWidget {
  final Asset asset;
  final VoidCallback onTap;

  const _AssetCard({
    required this.asset,
    required this.onTap,
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
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(
                  Icons.view_in_ar,
                  size: 48,
                ),
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
