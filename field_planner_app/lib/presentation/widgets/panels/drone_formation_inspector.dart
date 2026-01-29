/// ドローンフォーメーションインスペクター
///
/// 配置済みドローンフォーメーションのプロパティを編集するパネル。
/// 右側のプロパティパネルに表示される。
///
/// 主な機能:
/// - 水平位置（経度・緯度）の編集
/// - 高度・方位角・チルトの調整
/// - スケール・ポイントサイズ・輝度の調整
/// - 個別LED色の切り替え
/// - マップクリックによる位置設定

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/drone_formation.dart';
import '../../../data/models/geo_position.dart';
import '../../providers/asset_provider.dart';
import '../../providers/placement_provider.dart';
import 'drone_show_panel.dart';

/// ドローンフォーメーションインスペクター
class DroneFormationInspector extends ConsumerStatefulWidget {
  final PlacedDroneFormation placedFormation;

  const DroneFormationInspector({
    super.key,
    required this.placedFormation,
  });

  @override
  ConsumerState<DroneFormationInspector> createState() => _DroneFormationInspectorState();
}

class _DroneFormationInspectorState extends ConsumerState<DroneFormationInspector> {
  // 現在の値を保持（UIとの同期用）
  late double _baseLongitude;
  late double _baseLatitude;
  late double _altitude;
  late double _heading;
  late double _tilt;
  late double _scale;
  late double _pointSize;
  late double _glowIntensity;
  late bool _useIndividualColors;

  // 初期化済みフラグ
  bool _initialized = false;
  String? _lastFormationId;

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  @override
  void didUpdateWidget(covariant DroneFormationInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // IDが変わった場合のみ初期化
    if (oldWidget.placedFormation.id != widget.placedFormation.id) {
      _initializeValues();
    }
  }

  void _initializeValues() {
    _baseLongitude = widget.placedFormation.baseLongitude;
    _baseLatitude = widget.placedFormation.baseLatitude;
    _altitude = widget.placedFormation.altitude;
    _heading = widget.placedFormation.heading;
    _tilt = widget.placedFormation.tilt; // モデルから読み込み
    _scale = widget.placedFormation.scale;
    _pointSize = widget.placedFormation.pointSize;
    _glowIntensity = widget.placedFormation.glowIntensity; // モデルから読み込み
    _useIndividualColors = widget.placedFormation.useIndividualColors;
    _lastFormationId = widget.placedFormation.id;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 元のフォーメーションを取得してサイズ情報を計算
    final formationsAsync = ref.watch(droneFormationsProvider);
    final DroneFormation? formation = formationsAsync.whenOrNull(
      data: (formations) => formations
          .where((f) => f.id == widget.placedFormation.formationId)
          .firstOrNull,
    );

    // サイズ情報（スケール適用後）
    final double formationWidth = (formation?.width ?? 0) * _scale;
    final double formationDepth = (formation?.depth ?? 0) * _scale;
    final int droneCount = formation?.droneCount ?? 0;

    // 高さ情報を計算（チルト適用後）
    final heightRange = _calculateHeightRange(formation);
    final double minHeight = _altitude + heightRange.$1 * _scale;
    final double maxHeight = _altitude + heightRange.$2 * _scale;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // フォーメーション名
          Row(
            children: [
              const Icon(Icons.flight, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.placedFormation.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // サイズ情報
          _buildInfoSection(
            droneCount: droneCount,
            width: formationWidth,
            depth: formationDepth,
            minHeight: minHeight,
            maxHeight: maxHeight,
          ),
          const SizedBox(height: 16),

          // アクションボタン
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _startPositionPickMode,
                  icon: const Icon(Icons.pin_drop, size: 16),
                  label: const Text('位置設定'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _zoomToFormation,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('移動'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 位置セクション
          _buildSectionHeader('位置'),
          const SizedBox(height: 8),
          _buildCoordinateField(
            label: '経度',
            value: _baseLongitude,
            onChanged: (v) {
              setState(() => _baseLongitude = v);
              _updateFormation();
            },
          ),
          const SizedBox(height: 8),
          _buildCoordinateField(
            label: '緯度',
            value: _baseLatitude,
            onChanged: (v) {
              setState(() => _baseLatitude = v);
              _updateFormation();
            },
          ),
          const SizedBox(height: 8),
          _buildSlider(
            label: '高度',
            value: _altitude,
            min: 10,
            max: 300,
            suffix: 'm',
            onChanged: (v) => setState(() => _altitude = v),
            onChangeEnd: (_) => _updateFormation(),
          ),
          const SizedBox(height: 16),

          // 回転セクション
          _buildSectionHeader('回転'),
          const SizedBox(height: 8),
          _buildSlider(
            label: '方位角',
            value: _heading,
            min: 0,
            max: 360,
            suffix: '°',
            onChanged: (v) => setState(() => _heading = v),
            onChangeEnd: (_) => _updateFormation(),
          ),
          _buildSlider(
            label: 'チルト',
            value: _tilt,
            min: -180,
            max: 180,
            suffix: '°',
            onChanged: (v) => setState(() => _tilt = v),
            onChangeEnd: (_) => _updateFormation(),
          ),
          const SizedBox(height: 16),

          // 表示セクション
          _buildSectionHeader('表示'),
          const SizedBox(height: 8),
          _buildSlider(
            label: 'スケール',
            value: _scale,
            min: 0.1,
            max: 5.0,
            suffix: '×',
            onChanged: (v) => setState(() => _scale = v),
            onChangeEnd: (_) => _updateFormation(),
          ),
          _buildSlider(
            label: 'サイズ',
            value: _pointSize,
            min: 1,
            max: 10,
            suffix: 'px',
            onChanged: (v) => setState(() => _pointSize = v),
            onChangeEnd: (_) => _updateStyle(),
          ),
          _buildSlider(
            label: '輝度',
            value: _glowIntensity,
            min: 0.2,
            max: 2.0,
            suffix: '',
            onChanged: (v) => setState(() => _glowIntensity = v),
            onChangeEnd: (_) => _updateStyle(),
          ),
          const SizedBox(height: 8),

          // 個別色
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('個別LED色を使用', style: TextStyle(fontSize: 13)),
            subtitle: const Text('JSONの各ドローンの色を使用', style: TextStyle(fontSize: 11)),
            value: _useIndividualColors,
            onChanged: (v) {
              setState(() => _useIndividualColors = v);
              _updateStyle();
            },
          ),
          const SizedBox(height: 16),

          // 削除ボタン
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _deleteFormation,
              icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
              label: Text('削除', style: TextStyle(color: theme.colorScheme.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildInfoSection({
    required int droneCount,
    required double width,
    required double depth,
    required double minHeight,
    required double maxHeight,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow('機体数', '$droneCount 機'),
          const SizedBox(height: 4),
          _buildInfoRow('横幅', '${width.toStringAsFixed(1)} m'),
          const SizedBox(height: 4),
          _buildInfoRow('奥行', '${depth.toStringAsFixed(1)} m'),
          const SizedBox(height: 4),
          _buildInfoRow(
            '最低機体', 
            '${minHeight.toStringAsFixed(1)} m',
            isWarning: minHeight < 10, // 10m未満は警告（地形を考慮すると危険）
            isError: minHeight < 0, // 0m未満はエラー
          ),
          const SizedBox(height: 4),
          _buildInfoRow('最高機体', '${maxHeight.toStringAsFixed(1)} m'),
          if (minHeight < 10)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                minHeight < 0 
                    ? '⚠️ 機体が地面より下にあります' 
                    : '⚠️ 低高度注意（地形考慮）',
                style: TextStyle(
                  fontSize: 10, 
                  color: minHeight < 0 ? Colors.red : Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// チルト適用後の高さ範囲を計算
  /// 戻り値: (最小Z, 最大Z) の相対高さ
  (double, double) _calculateHeightRange(DroneFormation? formation) {
    if (formation == null || formation.drones.isEmpty) {
      return (0.0, 0.0);
    }

    // チルト角度（ラジアン）
    final tiltRad = _tilt * math.pi / 180.0;
    final sinValue = math.sin(tiltRad);

    double minZ = double.infinity;
    double maxZ = double.negativeInfinity;

    for (final drone in formation.drones) {
      // チルト適用後のZ座標: z = y * sin(tilt)
      final z = drone.y * sinValue;
      if (z < minZ) minZ = z;
      if (z > maxZ) maxZ = z;
    }

    // チルトが0の場合、すべてのドローンは同じ高さ
    if (minZ == double.infinity) minZ = 0;
    if (maxZ == double.negativeInfinity) maxZ = 0;

    return (minZ, maxZ);
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false, bool isError = false}) {
    final color = isError ? Colors.red : (isWarning ? Colors.orange : null);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: 12, 
          color: color ?? Colors.grey,
        )),
        Text(value, style: TextStyle(
          fontSize: 12, 
          fontWeight: FontWeight.w500,
          color: color,
        )),
      ],
    );
  }

  Widget _buildCoordinateField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: TextFormField(
            key: ValueKey('${widget.placedFormation.id}_$label'),
            initialValue: value.toStringAsFixed(6),
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            onFieldSubmitted: (text) {
              final parsed = double.tryParse(text);
              if (parsed != null) {
                onChanged(parsed);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '${value.toStringAsFixed(value < 10 ? 1 : 0)}$suffix',
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _startPositionPickMode() {
    final controller = ref.read(placementControllerProvider);
    if (controller == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('マップ上をクリックして新しい位置を指定してください'),
        duration: Duration(seconds: 5),
      ),
    );

    controller.startDronePositionPickMode(
      widget.placedFormation.id,
      onPositionPicked: (position) {
        setState(() {
          _baseLongitude = position.longitude;
          _baseLatitude = position.latitude;
        });
        _updateFormation();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置を更新しました')),
        );
      },
    );
  }

  void _zoomToFormation() {
    ref.read(placementControllerProvider)?.zoomToDroneFormation(widget.placedFormation.id);
  }

  void _updateFormation() {
    final controller = ref.read(placementControllerProvider);
    if (controller == null) return;

    final updated = widget.placedFormation.copyWith(
      baseLongitude: _baseLongitude,
      baseLatitude: _baseLatitude,
      altitude: _altitude,
      heading: _heading,
      tilt: _tilt,
      scale: _scale,
      pointSize: _pointSize,
      glowIntensity: _glowIntensity,
      useIndividualColors: _useIndividualColors,
    );

    controller.updatePlacedDroneFormation(updated);
  }

  void _updateStyle() {
    final controller = ref.read(placementControllerProvider);
    if (controller == null) return;

    // スタイル更新と同時にモデルにも保存
    final updated = widget.placedFormation.copyWith(
      pointSize: _pointSize,
      glowIntensity: _glowIntensity,
      useIndividualColors: _useIndividualColors,
    );

    controller.updatePlacedDroneFormation(updated);
  }

  void _deleteFormation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配置を削除'),
        content: Text('「${widget.placedFormation.name}」の配置を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(placementControllerProvider)?.removePlacedDroneFormation(widget.placedFormation.id);
      // 選択を解除
      ref.read(selectedDroneFormationIdProvider.notifier).state = null;
    }
  }
}
