import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/measurement.dart';
import '../../../data/models/geo_position.dart';

/// 計測パネル
///
/// 距離、面積、高さの計測機能を提供
class MeasurementPanel extends ConsumerStatefulWidget {
  const MeasurementPanel({super.key});

  @override
  ConsumerState<MeasurementPanel> createState() => _MeasurementPanelState();
}

class _MeasurementPanelState extends ConsumerState<MeasurementPanel> {
  MeasurementType? _activeTool;
  final List<Measurement> _measurements = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ツールバー
        _buildToolbar(theme),
        const Divider(height: 1),

        // アクティブな計測表示
        if (_activeTool != null) _buildActiveMeasurement(theme),

        // 計測リスト
        Expanded(
          child: _measurements.isEmpty
              ? _buildEmptyState(theme)
              : _buildMeasurementList(theme),
        ),

        // エクスポートボタン
        if (_measurements.isNotEmpty) _buildExportButtons(theme),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _buildToolButton(
            theme: theme,
            icon: Icons.straighten,
            label: '距離',
            type: MeasurementType.distance,
          ),
          const SizedBox(width: 4),
          _buildToolButton(
            theme: theme,
            icon: Icons.square_foot,
            label: '面積',
            type: MeasurementType.area,
          ),
          const SizedBox(width: 4),
          _buildToolButton(
            theme: theme,
            icon: Icons.height,
            label: '高さ',
            type: MeasurementType.height,
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required MeasurementType type,
  }) {
    final isActive = _activeTool == type;

    return Expanded(
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          foregroundColor: isActive
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onPressed: () {
          setState(() {
            _activeTool = isActive ? null : type;
          });
        },
      ),
    );
  }

  Widget _buildActiveMeasurement(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getToolIcon(_activeTool!),
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${_activeTool!.displayName}計測中',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _cancelMeasurement,
                child: const Text('キャンセル'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getInstructions(_activeTool!),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _getInstructions(MeasurementType type) {
    switch (type) {
      case MeasurementType.distance:
        return 'マップ上でクリックして計測点を追加。ダブルクリックで完了。';
      case MeasurementType.area:
        return 'マップ上でクリックしてポリゴンの頂点を追加。ダブルクリックで完了。';
      case MeasurementType.height:
        return 'マップ上で2点をクリックして高低差を計測。';
      case MeasurementType.angle:
        return 'マップ上で3点をクリックして角度を計測。';
    }
  }

  IconData _getToolIcon(MeasurementType type) {
    switch (type) {
      case MeasurementType.distance:
        return Icons.straighten;
      case MeasurementType.area:
        return Icons.square_foot;
      case MeasurementType.height:
        return Icons.height;
      case MeasurementType.angle:
        return Icons.architecture;
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.straighten,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            '計測結果がありません',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '上のボタンで計測を開始',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementList(ThemeData theme) {
    return ListView.builder(
      itemCount: _measurements.length,
      itemBuilder: (context, index) {
        final measurement = _measurements[index];
        return _MeasurementTile(
          measurement: measurement,
          onVisibilityToggle: () {
            setState(() {
              _measurements[index] = measurement.copyWith(
                visible: !measurement.visible,
              );
            });
          },
          onDelete: () {
            setState(() {
              _measurements.removeAt(index);
            });
          },
        );
      },
    );
  }

  Widget _buildExportButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.table_chart, size: 16),
              label: const Text('CSV'),
              onPressed: _exportToCsv,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.map, size: 16),
              label: const Text('GeoJSON'),
              onPressed: _exportToGeoJson,
            ),
          ),
        ],
      ),
    );
  }

  void _cancelMeasurement() {
    setState(() => _activeTool = null);
  }

  void _addSampleMeasurement() {
    // デモ用のサンプル計測を追加
    final measurement = Measurement(
      id: const Uuid().v4(),
      type: _activeTool!,
      name: '${_activeTool!.displayName} ${_measurements.length + 1}',
      points: [
        const GeoPosition(longitude: 139.6917, latitude: 35.6895),
        const GeoPosition(longitude: 139.6920, latitude: 35.6900),
      ],
      value: 100.5,
      createdAt: DateTime.now(),
    );

    setState(() {
      _measurements.add(measurement);
      _activeTool = null;
    });
  }

  void _exportToCsv() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV出力機能は実装予定です')),
    );
  }

  void _exportToGeoJson() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GeoJSON出力機能は実装予定です')),
    );
  }
}

/// 計測結果タイル
class _MeasurementTile extends StatelessWidget {
  final Measurement measurement;
  final VoidCallback onVisibilityToggle;
  final VoidCallback onDelete;

  const _MeasurementTile({
    required this.measurement,
    required this.onVisibilityToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      leading: Icon(
        _getIcon(),
        size: 20,
        color: measurement.visible
            ? theme.colorScheme.primary
            : theme.disabledColor,
      ),
      title: Text(
        measurement.name,
        style: TextStyle(
          fontSize: 13,
          color: measurement.visible ? null : theme.disabledColor,
        ),
      ),
      subtitle: Text(
        measurement.formattedValue,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: measurement.visible
              ? theme.colorScheme.primary
              : theme.disabledColor,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              measurement.visible
                  ? Icons.visibility
                  : Icons.visibility_off,
              size: 18,
            ),
            onPressed: onVisibilityToggle,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (measurement.type) {
      case MeasurementType.distance:
        return Icons.straighten;
      case MeasurementType.area:
        return Icons.square_foot;
      case MeasurementType.height:
        return Icons.height;
      case MeasurementType.angle:
        return Icons.architecture;
    }
  }
}
