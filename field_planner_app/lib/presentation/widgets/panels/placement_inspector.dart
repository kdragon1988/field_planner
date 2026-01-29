/// 配置インスペクター
/// 
/// 選択された配置オブジェクトのプロパティを編集するパネル。
/// 通常の配置物（3Dモデル）とドローンフォーメーションの
/// 両方の設定に対応する。
/// 
/// 主な機能:
/// - 位置・回転・スケールの編集
/// - 表示/非表示・ロック設定
/// - 複製・削除操作
/// - ドローン固有設定（色、ポイントサイズ等）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/drone_formation.dart';
import '../../../data/models/placement.dart';
import '../../providers/asset_provider.dart';
import '../../providers/placement_provider.dart';
import '../../providers/project_provider.dart';

/// 配置インスペクター
class PlacementInspector extends ConsumerStatefulWidget {
  /// 選択中の配置オブジェクト
  final Placement? placement;

  /// 選択中のドローンフォーメーション
  final PlacedDroneFormation? droneFormation;

  /// 変更時のコールバック
  final void Function(Placement)? onPlacementChanged;

  /// ドローンフォーメーション変更時のコールバック
  final void Function(PlacedDroneFormation)? onDroneFormationChanged;

  /// 削除時のコールバック
  final VoidCallback? onDelete;

  const PlacementInspector({
    super.key,
    this.placement,
    this.droneFormation,
    this.onPlacementChanged,
    this.onDroneFormationChanged,
    this.onDelete,
  });

  @override
  ConsumerState<PlacementInspector> createState() => _PlacementInspectorState();
}

class _PlacementInspectorState extends ConsumerState<PlacementInspector> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 選択されている配置物を取得
    final selectedPlacement = ref.watch(selectedPlacementProvider);
    final placement = widget.placement ?? selectedPlacement;

    // ドローンフォーメーションの場合
    if (widget.droneFormation != null) {
      return _buildDroneInspector(theme, widget.droneFormation!);
    }

    // 配置物がない場合
    if (placement == null) {
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

    return _buildPlacementInspector(theme, placement);
  }

  Widget _buildPlacementInspector(ThemeData theme, Placement placement) {
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
                _updatePlacement(placement.copyWith(name: value));
              },
            ),
          ]),

          // 位置
          _buildSection('位置', [
            _buildCoordinateField(
              '経度',
              placement.position.longitude,
              (v) => _updatePosition(placement, longitude: v),
            ),
            _buildCoordinateField(
              '緯度',
              placement.position.latitude,
              (v) => _updatePosition(placement, latitude: v),
            ),
            _buildCoordinateField(
              '高さ',
              placement.position.height,
              (v) => _updatePosition(placement, height: v),
            ),
          ]),

          // 回転
          _buildSection('回転', [
            _buildSlider(
              '方位角',
              placement.rotation.heading,
              0,
              360,
              (value) {
                _updatePlacement(placement.copyWith(
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
                _updatePlacement(placement.copyWith(
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
                _updatePlacement(placement.copyWith(
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
                _updatePlacement(placement.copyWith(
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
                _updatePlacement(placement.copyWith(
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
                _updatePlacement(placement.copyWith(visible: value));
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            SwitchListTile(
              title: const Text('ロック'),
              value: placement.locked,
              onChanged: (value) {
                _updatePlacement(placement.copyWith(locked: value));
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ]),

          const SizedBox(height: 16),

          // アクションボタン
          _buildActions(theme, placement),
        ],
      ),
    );
  }

  Widget _buildDroneInspector(ThemeData theme, PlacedDroneFormation formation) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          _buildDroneHeader(theme, formation),
          const Divider(),

          // 名前
          _buildSection('名前', [
            TextField(
              decoration: const InputDecoration(
                isDense: true,
              ),
              controller: TextEditingController(text: formation.name),
              onChanged: (value) {
                _updateDroneFormation(formation.copyWith(name: value));
              },
            ),
          ]),

          // 位置
          _buildSection('基準位置', [
            _buildCoordinateField(
              '経度',
              formation.baseLongitude,
              (v) => _updateDroneFormation(formation.copyWith(baseLongitude: v)),
            ),
            _buildCoordinateField(
              '緯度',
              formation.baseLatitude,
              (v) => _updateDroneFormation(formation.copyWith(baseLatitude: v)),
            ),
          ]),

          // 高度
          _buildSection('高度', [
            _buildSlider(
              '高度',
              formation.altitude,
              10,
              200,
              (value) {
                _updateDroneFormation(formation.copyWith(altitude: value));
              },
              suffix: 'm',
            ),
          ]),

          // 回転・スケール
          _buildSection('変形', [
            _buildSlider(
              '方位角',
              formation.heading,
              0,
              360,
              (value) {
                _updateDroneFormation(formation.copyWith(heading: value));
              },
              suffix: '°',
            ),
            _buildSlider(
              'スケール',
              formation.scale,
              0.1,
              5.0,
              (value) {
                _updateDroneFormation(formation.copyWith(scale: value));
              },
              suffix: '×',
            ),
          ]),

          // 表示設定
          _buildSection('表示設定', [
            _buildSlider(
              'ポイントサイズ',
              formation.pointSize,
              5,
              30,
              (value) {
                _updateDroneFormation(formation.copyWith(pointSize: value));
              },
              suffix: 'px',
            ),
            SwitchListTile(
              title: const Text('個別色を使用'),
              subtitle: const Text('各ドローンのLED色を表示'),
              value: formation.useIndividualColors,
              onChanged: (value) {
                _updateDroneFormation(
                  formation.copyWith(useIndividualColors: value),
                );
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            if (!formation.useIndividualColors) ...[
              const SizedBox(height: 8),
              _buildColorPicker(
                '統一色',
                formation.customColor ?? '#FFFFFF',
                (color) {
                  _updateDroneFormation(formation.copyWith(customColor: color));
                },
              ),
            ],
          ]),

          // オプション
          _buildSection('オプション', [
            SwitchListTile(
              title: const Text('表示'),
              value: formation.visible,
              onChanged: (value) {
                _updateDroneFormation(formation.copyWith(visible: value));
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            SwitchListTile(
              title: const Text('ロック'),
              value: formation.locked,
              onChanged: (value) {
                _updateDroneFormation(formation.copyWith(locked: value));
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ]),

          const SizedBox(height: 16),

          // アクションボタン
          _buildDroneActions(theme, formation),
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
        IconButton(
          icon: Icon(
            placement.locked ? Icons.lock : Icons.lock_open,
            color: placement.locked ? Colors.red : null,
          ),
          onPressed: () {
            _updatePlacement(placement.copyWith(locked: !placement.locked));
          },
          tooltip: placement.locked ? 'ロック解除' : 'ロック',
        ),
      ],
    );
  }

  Widget _buildDroneHeader(ThemeData theme, PlacedDroneFormation formation) {
    return Row(
      children: [
        Icon(
          Icons.flight,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formation.name,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                'ドローンフォーメーション',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            formation.locked ? Icons.lock : Icons.lock_open,
            color: formation.locked ? Colors.red : null,
          ),
          onPressed: () {
            _updateDroneFormation(formation.copyWith(locked: !formation.locked));
          },
          tooltip: formation.locked ? 'ロック解除' : 'ロック',
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

  Widget _buildCoordinateField(
    String label,
    double value,
    Function(double) onChanged,
  ) {
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
              onSubmitted: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) onChanged(parsed);
              },
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
    ValueChanged<double> onChanged, {
    String? suffix,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
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
            '${value.toStringAsFixed(1)}${suffix ?? ''}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker(
    String label,
    String colorHex,
    Function(String) onChanged,
  ) {
    final colors = [
      '#FFFFFF',
      '#FF0000',
      '#00FF00',
      '#0000FF',
      '#FFFF00',
      '#00FFFF',
      '#FF00FF',
      '#FFA500',
    ];

    return Row(
      children: [
        SizedBox(width: 60, child: Text(label)),
        Expanded(
          child: Wrap(
            spacing: 4,
            children: colors.map((hex) {
              final isSelected = hex.toUpperCase() == colorHex.toUpperCase();
              return GestureDetector(
                onTap: () => onChanged(hex),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _hexToColor(hex),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  Widget _buildActions(ThemeData theme, Placement placement) {
    final controller = ref.read(placementControllerProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: placement.locked
              ? null
              : () {
                  controller?.duplicatePlacement(placement.id);
                },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('複製'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            controller?.zoomToPlacement(placement.id);
          },
          icon: const Icon(Icons.zoom_in, size: 18),
          label: const Text('ズーム'),
        ),
        OutlinedButton.icon(
          onPressed: placement.locked
              ? null
              : () => _confirmDelete(placement),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('削除'),
        ),
      ],
    );
  }

  Widget _buildDroneActions(ThemeData theme, PlacedDroneFormation formation) {
    final controller = ref.read(placementControllerProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            controller?.zoomToDroneFormation(formation.id);
          },
          icon: const Icon(Icons.zoom_in, size: 18),
          label: const Text('ズーム'),
        ),
        OutlinedButton.icon(
          onPressed: formation.locked
              ? null
              : () => _confirmDroneDelete(formation),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('削除'),
        ),
      ],
    );
  }

  void _updatePlacement(Placement placement) {
    widget.onPlacementChanged?.call(placement);
    ref.read(placementControllerProvider)?.updatePlacement(placement);
  }

  void _updatePosition(Placement placement, {
    double? longitude,
    double? latitude,
    double? height,
  }) {
    _updatePlacement(placement.copyWith(
      position: placement.position.copyWith(
        longitude: longitude,
        latitude: latitude,
        height: height,
      ),
    ));
  }

  void _updateDroneFormation(PlacedDroneFormation formation) {
    widget.onDroneFormationChanged?.call(formation);
    ref.read(placementControllerProvider)?.updatePlacedDroneFormation(formation);
  }

  void _confirmDelete(Placement placement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配置物を削除'),
        content: Text('「${placement.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDelete?.call();
      ref.read(placementControllerProvider)?.deletePlacement(placement.id);
    }
  }

  void _confirmDroneDelete(PlacedDroneFormation formation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ドローンフォーメーションを削除'),
        content: Text('「${formation.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDelete?.call();
      ref.read(placementControllerProvider)?.removePlacedDroneFormation(formation.id);
    }
  }
}
