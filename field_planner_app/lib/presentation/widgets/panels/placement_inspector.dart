import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/placement.dart';

/// 配置インスペクター
///
/// 選択された配置オブジェクトのプロパティを編集
class PlacementInspector extends ConsumerStatefulWidget {
  /// 選択中の配置オブジェクト
  final Placement? placement;

  /// 変更時のコールバック
  final void Function(Placement)? onChanged;

  /// 削除時のコールバック
  final VoidCallback? onDelete;

  const PlacementInspector({
    super.key,
    this.placement,
    this.onChanged,
    this.onDelete,
  });

  @override
  ConsumerState<PlacementInspector> createState() => _PlacementInspectorState();
}

class _PlacementInspectorState extends ConsumerState<PlacementInspector> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.placement == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.select_all,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'オブジェクトを選択',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final placement = widget.placement!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          _buildHeader(theme, placement),
          const Divider(),

          // 名前
          _buildSection('名前', [
            TextField(
              decoration: const InputDecoration(
                isDense: true,
              ),
              controller: TextEditingController(text: placement.name),
              onChanged: (value) {
                widget.onChanged?.call(placement.copyWith(name: value));
              },
            ),
          ]),

          // 位置
          _buildSection('位置', [
            _buildCoordinateField('経度', placement.position.longitude),
            _buildCoordinateField('緯度', placement.position.latitude),
            _buildCoordinateField('高さ', placement.position.height),
          ]),

          // 回転
          _buildSection('回転', [
            _buildSlider(
              '方位角',
              placement.rotation.heading,
              0,
              360,
              (value) {
                widget.onChanged?.call(placement.copyWith(
                  rotation: placement.rotation.copyWith(heading: value),
                ));
              },
            ),
            _buildSlider(
              'ピッチ',
              placement.rotation.pitch,
              -90,
              90,
              (value) {
                widget.onChanged?.call(placement.copyWith(
                  rotation: placement.rotation.copyWith(pitch: value),
                ));
              },
            ),
          ]),

          // スケール
          _buildSection('スケール', [
            _buildSlider(
              'X',
              placement.scale.x,
              0.1,
              10,
              (value) {
                widget.onChanged?.call(placement.copyWith(
                  scale: placement.scale.copyWith(x: value),
                ));
              },
            ),
            _buildSlider(
              'Y',
              placement.scale.y,
              0.1,
              10,
              (value) {
                widget.onChanged?.call(placement.copyWith(
                  scale: placement.scale.copyWith(y: value),
                ));
              },
            ),
            _buildSlider(
              'Z',
              placement.scale.z,
              0.1,
              10,
              (value) {
                widget.onChanged?.call(placement.copyWith(
                  scale: placement.scale.copyWith(z: value),
                ));
              },
            ),
          ]),

          // オプション
          _buildSection('オプション', [
            SwitchListTile(
              title: const Text('表示'),
              value: placement.visible,
              onChanged: (value) {
                widget.onChanged?.call(placement.copyWith(visible: value));
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            SwitchListTile(
              title: const Text('ロック'),
              value: placement.locked,
              onChanged: (value) {
                widget.onChanged?.call(placement.copyWith(locked: value));
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ]),

          const SizedBox(height: 16),

          // アクションボタン
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('複製'),
                  onPressed: () {
                    // TODO: 複製処理
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
                  onPressed: widget.onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Placement placement) {
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
                placement.name,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                'ID: ${placement.id.substring(0, 8)}...',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
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

  Widget _buildCoordinateField(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              controller: TextEditingController(
                text: value.toStringAsFixed(6),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: const TextStyle(fontSize: 12)),
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
          width: 50,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
