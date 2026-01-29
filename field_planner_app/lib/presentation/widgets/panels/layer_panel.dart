import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/layer.dart';

/// レイヤーパネル
///
/// レイヤー一覧の表示、並び替え、表示/非表示切り替えを行う
class LayerPanel extends ConsumerStatefulWidget {
  const LayerPanel({super.key});

  @override
  ConsumerState<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends ConsumerState<LayerPanel> {
  // デモ用のサンプルレイヤー
  final List<Layer> _layers = [
    const Layer(
      id: 'basemap',
      name: 'ベースマップ',
      type: LayerType.basemap,
      visible: true,
      locked: true,
    ),
    const Layer(
      id: 'terrain',
      name: '地形',
      type: LayerType.terrain,
      visible: true,
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

  Layer? _selectedLayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ツールバー
        _buildToolbar(theme),
        const Divider(height: 1),

        // レイヤーリスト
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: _layers.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final layer = _layers[index];
              return _LayerTile(
                key: ValueKey(layer.id),
                index: index,
                layer: layer,
                isSelected: _selectedLayer?.id == layer.id,
                onTap: () => setState(() => _selectedLayer = layer),
                onVisibilityChanged: (visible) => _updateLayerVisibility(layer, visible),
                onOpacityChanged: (opacity) => _updateLayerOpacity(layer, opacity),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'レイヤーを追加',
            onPressed: _addLayer,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '選択レイヤーを削除',
            onPressed: _selectedLayer != null && !_selectedLayer!.locked
                ? _removeSelectedLayer
                : null,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.unfold_more, size: 20),
            tooltip: 'すべて展開',
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final layer = _layers.removeAt(oldIndex);
      _layers.insert(newIndex, layer);
    });
  }

  void _updateLayerVisibility(Layer layer, bool visible) {
    setState(() {
      final index = _layers.indexWhere((l) => l.id == layer.id);
      if (index >= 0) {
        _layers[index] = layer.copyWith(visible: visible);
      }
    });
  }

  void _updateLayerOpacity(Layer layer, double opacity) {
    setState(() {
      final index = _layers.indexWhere((l) => l.id == layer.id);
      if (index >= 0) {
        _layers[index] = layer.copyWith(opacity: opacity);
      }
    });
  }

  void _addLayer() {
    // TODO: レイヤー追加ダイアログを表示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('レイヤー追加機能は3Dデータインポートから実行します')),
    );
  }

  void _removeSelectedLayer() {
    if (_selectedLayer != null) {
      setState(() {
        _layers.removeWhere((l) => l.id == _selectedLayer!.id);
        _selectedLayer = null;
      });
    }
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

  const _LayerTile({
    super.key,
    required this.index,
    required this.layer,
    required this.isSelected,
    required this.onTap,
    required this.onVisibilityChanged,
    required this.onOpacityChanged,
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
            leading: ReorderableDragStartListener(
              index: widget.index,
              child: Icon(
                _getLayerIcon(layer.type),
                size: 20,
                color: layer.visible
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
              ),
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
                // 不透明度ボタン
                IconButton(
                  icon: const Icon(Icons.opacity, size: 18),
                  tooltip: '不透明度',
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
                    size: 18,
                  ),
                  tooltip: layer.visible ? '非表示にする' : '表示する',
                  onPressed: () {
                    widget.onVisibilityChanged(!layer.visible);
                  },
                ),
                // ロック表示
                if (layer.locked)
                  const Icon(Icons.lock, size: 16),
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
