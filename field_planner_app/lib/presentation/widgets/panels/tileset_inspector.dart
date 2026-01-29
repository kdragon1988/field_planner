import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tileset_provider.dart';

/// Tilesetインスペクター
///
/// 選択された3D Tilesetのプロパティを編集
/// - 高さオフセット
/// - 画質（LOD）設定
/// - クリッピング設定
class TilesetInspector extends ConsumerStatefulWidget {
  const TilesetInspector({super.key});

  @override
  ConsumerState<TilesetInspector> createState() => _TilesetInspectorState();
}

class _TilesetInspectorState extends ConsumerState<TilesetInspector> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tilesetState = ref.watch(tilesetProvider);
    final selectedTileset = tilesetState.selectedTileset;

    if (selectedTileset == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.view_in_ar,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              '3Dモデルを選択',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'レイヤーパネルでモデルを\nクリックして選択',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          _buildHeader(theme, selectedTileset),
          const Divider(),

          // 中心座標情報
          if (selectedTileset.center != null)
            _buildSection('位置情報', [
              _buildInfoRow('緯度', '${selectedTileset.center!.latitude.toStringAsFixed(6)}°'),
              _buildInfoRow('経度', '${selectedTileset.center!.longitude.toStringAsFixed(6)}°'),
              _buildInfoRow('高度', '${selectedTileset.center!.height.toStringAsFixed(1)} m'),
              if (selectedTileset.radius != null)
                _buildInfoRow('半径', '${selectedTileset.radius!.toStringAsFixed(1)} m'),
            ]),

          // 高さ調整
          _buildSection('高さ調整', [
            _buildSliderWithInput(
              value: selectedTileset.heightOffset,
              min: -100,
              max: 100,
              label: 'オフセット',
              unit: 'm',
              onChanged: (value) {
                ref.read(tilesetProvider.notifier).adjustTilesetHeight(
                      selectedTileset.id,
                      value,
                    );
              },
            ),
          ]),

          // 画質設定
          _buildSection('画質設定', [
            _buildQualitySlider(selectedTileset),
            const SizedBox(height: 8),
            Text(
              '値が小さいほど高画質（メモリ使用量増加）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ]),

          // Google 3D Tiles表示設定
          _buildSection('Google 3D Tiles', [
            SwitchListTile(
              title: const Text('非表示にする'),
              subtitle: const Text('モデルが埋まらないようにする'),
              value: selectedTileset.clipGoogleTiles,
              onChanged: (value) {
                if (value) {
                  ref.read(tilesetProvider.notifier).setGoogleTilesetClipping(
                        selectedTileset.id,
                      );
                } else {
                  ref.read(tilesetProvider.notifier).removeGoogleTilesetClipping();
                }
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '※ Google 3D Tilesは部分的なクリッピングに対応していないため、全体を非表示にします',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ),
          ]),

          // 表示設定
          _buildSection('表示', [
            _buildSliderWithInput(
              value: selectedTileset.opacity * 100,
              min: 0,
              max: 100,
              label: '不透明度',
              unit: '%',
              onChanged: (value) {
                ref.read(tilesetProvider.notifier).setTilesetOpacity(
                      selectedTileset.id,
                      value / 100,
                    );
              },
            ),
          ]),

          const SizedBox(height: 16),

          // アクションボタン
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('この位置へ'),
                  onPressed: () {
                    ref.read(tilesetProvider.notifier).flyToTileset(
                          selectedTileset.id,
                        );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('削除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () => _confirmDelete(selectedTileset),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, TilesetLayer tileset) {
    return Row(
      children: [
        Icon(
          Icons.view_in_ar,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tileset.name,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                '3D Tiles',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () {
            ref.read(tilesetProvider.notifier).selectTileset(null);
          },
          tooltip: '選択解除',
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderWithInput({
    required double value,
    required double min,
    required double max,
    required String label,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text('$label:', style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildQualitySlider(TilesetLayer tileset) {
    // Screen Space Error: 1（最高品質）〜 64（最低品質）
    // UIでは逆にする（スライダー右が高品質）
    final quality = (64 - tileset.screenSpaceError).clamp(0.0, 63.0);

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(
              width: 70,
              child: Text('画質:', style: TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: Slider(
                value: quality,
                min: 0,
                max: 63,
                divisions: 63,
                onChanged: (value) {
                  // スライダー値をSSEに変換（逆転）
                  final sse = 64 - value;
                  ref.read(tilesetProvider.notifier).adjustTilesetQuality(
                        tileset.id,
                        sse.clamp(1.0, 64.0),
                      );
                },
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                _getQualityLabel(quality),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('低', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            Text('高', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  String _getQualityLabel(double quality) {
    if (quality >= 58) return '最高';
    if (quality >= 48) return '高';
    if (quality >= 32) return '中';
    if (quality >= 16) return '低';
    return '最低';
  }

  void _confirmDelete(TilesetLayer tileset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('3Dモデルを削除'),
        content: Text('「${tileset.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(tilesetProvider.notifier).removeTileset(tileset.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
