import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/layer.dart';
import '../../providers/tileset_provider.dart';
import '../dialogs/tileset_import_dialog.dart';

/// レイヤーパネル
///
/// レイヤー一覧の表示、並び替え、表示/非表示切り替えを行う。
/// 3D Tilesレイヤーの管理もサポート。
class LayerPanel extends ConsumerStatefulWidget {
  const LayerPanel({super.key});

  @override
  ConsumerState<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends ConsumerState<LayerPanel> {
  Layer? _selectedLayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tilesetState = ref.watch(tilesetProvider);

    // 基本レイヤー + 3D Tilesレイヤーを結合
    final baseLayers = _getBaseLayers(tilesetState);
    final tilesetLayers = tilesetState.layers.map((t) => t.toLayer()).toList();
    final allLayers = [...baseLayers, ...tilesetLayers];

    return Column(
      children: [
        // ツールバー
        _buildToolbar(theme),
        const Divider(height: 1),

        // レイヤーリスト
        Expanded(
          child: ListView.builder(
            itemCount: allLayers.length,
            itemBuilder: (context, index) {
              final layer = allLayers[index];
              final isCustomTileset = layer.type == LayerType.tiles3D &&
                  layer.id != 'google_3d' &&
                  tilesetState.layers.any((t) => t.id == layer.id);
              
              return _LayerTile(
                key: ValueKey(layer.id),
                index: index,
                layer: layer,
                isSelected: _selectedLayer?.id == layer.id ||
                    tilesetState.selectedTilesetId == layer.id,
                onTap: () {
                  setState(() => _selectedLayer = layer);
                  // カスタムTilesetの場合は選択状態にしてプロパティパネルを表示
                  if (isCustomTileset) {
                    ref.read(tilesetProvider.notifier).selectTileset(layer.id);
                  } else {
                    ref.read(tilesetProvider.notifier).selectTileset(null);
                  }
                },
                onVisibilityChanged: (visible) =>
                    _updateLayerVisibility(layer, visible),
                onOpacityChanged: (opacity) =>
                    _updateLayerOpacity(layer, opacity),
                onDelete: isCustomTileset
                    ? () => _deleteTilesetLayer(layer.id)
                    : null,
                onFlyTo: isCustomTileset
                    ? () => ref.read(tilesetProvider.notifier).flyToTileset(layer.id)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  /// 基本レイヤーを取得（状態に基づく）
  List<Layer> _getBaseLayers(TilesetState state) {
    return [
      const Layer(
        id: 'basemap',
        name: 'ベースマップ',
        type: LayerType.basemap,
        visible: true,
        locked: true,
      ),
      Layer(
        id: 'google_3d',
        name: 'Google 3D Tiles',
        type: LayerType.tiles3D,
        visible: state.showGoogleTileset,
        locked: false,
      ),
      Layer(
        id: 'terrain',
        name: '地形',
        type: LayerType.terrain,
        visible: state.showTerrain,
      ),
      const Layer(
        id: 'placements',
        name: '配置オブジェクト',
        type: LayerType.placements,
        visible: true,
      ),
      const Layer(
        id: 'measurements',
        name: '計測',
        type: LayerType.measurements,
        visible: true,
      ),
    ];
  }

  Widget _buildToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: '3Dモデルをインポート',
            onPressed: _showImportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '選択レイヤーを削除',
            onPressed: _selectedLayer != null &&
                    !_selectedLayer!.locked &&
                    _selectedLayer!.type == LayerType.tiles3D &&
                    _selectedLayer!.id != 'google_3d'
                ? () => _deleteTilesetLayer(_selectedLayer!.id)
                : null,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '更新',
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  /// 3Dモデルインポートダイアログを表示
  Future<void> _showImportDialog() async {
    final result = await showDialog<TilesetImportResult>(
      context: context,
      builder: (context) => const TilesetImportDialog(),
    );

    if (result != null && mounted) {
      // Tilesetを追加
      await ref.read(tilesetProvider.notifier).addTileset(
            name: result.name,
            tilesetJsonPath: result.tilesetJsonPath,
            folderPath: result.folderPath,
            flyTo: result.flyToAfterImport,
            clipGoogleTiles: result.clipGoogleTiles,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('3Dモデル「${result.name}」をインポートしました')),
        );
      }
    }
  }

  void _updateLayerVisibility(Layer layer, bool visible) {
    // 特殊レイヤーの処理
    if (layer.id == 'google_3d') {
      ref.read(tilesetProvider.notifier).setGoogleTilesetVisible(visible);
      return;
    }
    if (layer.id == 'terrain') {
      ref.read(tilesetProvider.notifier).setTerrainEnabled(visible);
      return;
    }

    // 3D Tilesレイヤー
    if (layer.type == LayerType.tiles3D) {
      ref.read(tilesetProvider.notifier).setTilesetVisible(layer.id, visible);
    }
  }

  void _updateLayerOpacity(Layer layer, double opacity) {
    // 3D Tilesレイヤー
    if (layer.type == LayerType.tiles3D && layer.id != 'google_3d') {
      ref.read(tilesetProvider.notifier).setTilesetOpacity(layer.id, opacity);
    }
  }

  void _deleteTilesetLayer(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('レイヤーを削除'),
        content: const Text('このレイヤーを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(tilesetProvider.notifier).removeTileset(id);
              Navigator.of(context).pop();
              setState(() => _selectedLayer = null);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

/// レイヤータイル
class _LayerTile extends StatefulWidget {
  final int index;
  final Layer layer;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<double> onOpacityChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onFlyTo;

  const _LayerTile({
    super.key,
    required this.index,
    required this.layer,
    required this.isSelected,
    required this.onTap,
    required this.onVisibilityChanged,
    required this.onOpacityChanged,
    this.onDelete,
    this.onFlyTo,
  });

  @override
  State<_LayerTile> createState() => _LayerTileState();
}

class _LayerTileState extends State<_LayerTile> {
  bool _showOpacitySlider = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layer = widget.layer;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: widget.isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          child: ListTile(
            dense: true,
            leading: Icon(
              _getLayerIcon(layer.type),
              size: 20,
              color: layer.visible
                  ? theme.colorScheme.primary
                  : theme.disabledColor,
            ),
            title: Text(
              layer.name,
              style: TextStyle(
                fontSize: 13,
                color: layer.visible ? null : theme.disabledColor,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 位置に飛ぶボタン（3D Tilesのみ）
                if (widget.onFlyTo != null)
                  IconButton(
                    icon: const Icon(Icons.my_location, size: 16),
                    tooltip: 'この位置に移動',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32),
                    onPressed: widget.onFlyTo,
                  ),
                // 不透明度ボタン
                IconButton(
                  icon: const Icon(Icons.opacity, size: 16),
                  tooltip: '不透明度',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                  onPressed: () {
                    setState(() {
                      _showOpacitySlider = !_showOpacitySlider;
                    });
                  },
                ),
                // 表示/非表示
                IconButton(
                  icon: Icon(
                    layer.visible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    size: 16,
                  ),
                  tooltip: layer.visible ? '非表示にする' : '表示する',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                  onPressed: () {
                    widget.onVisibilityChanged(!layer.visible);
                  },
                ),
                // ロック表示 or 削除ボタン
                if (layer.locked)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.lock, size: 14),
                  )
                else if (widget.onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    tooltip: '削除',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32),
                    onPressed: widget.onDelete,
                  ),
              ],
            ),
            onTap: widget.onTap,
          ),
        ),
        // 不透明度スライダー
        if (_showOpacitySlider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Text('不透明度', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: layer.opacity,
                    min: 0,
                    max: 1,
                    divisions: 10,
                    onChanged: widget.onOpacityChanged,
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(layer.opacity * 100).round()}%',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _getLayerIcon(LayerType type) {
    switch (type) {
      case LayerType.basemap:
        return Icons.map;
      case LayerType.pointCloud:
        return Icons.grain;
      case LayerType.mesh:
        return Icons.view_in_ar;
      case LayerType.tiles3D:
        return Icons.view_in_ar;
      case LayerType.terrain:
        return Icons.terrain;
      case LayerType.placements:
        return Icons.place;
      case LayerType.measurements:
        return Icons.straighten;
      case LayerType.annotations:
        return Icons.edit_note;
    }
  }
}
