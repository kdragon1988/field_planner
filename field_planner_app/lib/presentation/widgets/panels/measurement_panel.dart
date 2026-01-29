import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/measurement.dart';
import '../../providers/measurement_provider.dart';

/// 計測パネル
///
/// 距離、面積、高さの計測機能を提供し、
/// 計測結果の一覧表示、編集、エクスポートを行う
class MeasurementPanel extends ConsumerWidget {
  const MeasurementPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final measurementState = ref.watch(measurementProvider);

    return Column(
      children: [
        // ツールバー
        _buildToolbar(context, ref, theme, measurementState),
        const Divider(height: 1),

        // アクティブな計測表示
        if (measurementState.isMeasuring)
          _buildActiveMeasurement(context, ref, theme, measurementState),

        // 編集モード表示
        if (measurementState.isEditing)
          _buildEditingIndicator(context, ref, theme, measurementState),

        // 計測リスト
        Expanded(
          child: measurementState.measurements.isEmpty
              ? _buildEmptyState(theme)
              : _buildMeasurementList(context, ref, theme, measurementState),
        ),

        // エクスポートボタン
        if (measurementState.measurements.isNotEmpty)
          _buildExportButtons(context, ref, theme),
      ],
    );
  }

  /// ツールバーを構築
  Widget _buildToolbar(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    MeasurementState state,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _buildToolButton(
            context: context,
            ref: ref,
            theme: theme,
            icon: Icons.straighten,
            label: '距離',
            type: MeasurementType.distance,
            isActive: state.activeMode == MeasurementType.distance,
          ),
          const SizedBox(width: 4),
          _buildToolButton(
            context: context,
            ref: ref,
            theme: theme,
            icon: Icons.square_foot,
            label: '面積',
            type: MeasurementType.area,
            isActive: state.activeMode == MeasurementType.area,
          ),
          const SizedBox(width: 4),
          _buildToolButton(
            context: context,
            ref: ref,
            theme: theme,
            icon: Icons.height,
            label: '高さ',
            type: MeasurementType.height,
            isActive: state.activeMode == MeasurementType.height,
          ),
        ],
      ),
    );
  }

  /// ツールボタンを構築
  Widget _buildToolButton({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required IconData icon,
    required String label,
    required MeasurementType type,
    required bool isActive,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isActive ? theme.colorScheme.primary : theme.colorScheme.surface,
          foregroundColor: isActive
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onPressed: () {
          final notifier = ref.read(measurementProvider.notifier);
          if (isActive) {
            notifier.cancelMeasurement();
          } else {
            notifier.startMeasurement(type);
          }
        },
      ),
    );
  }

  /// アクティブな計測の表示
  Widget _buildActiveMeasurement(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    MeasurementState state,
  ) {
    final activeMode = state.activeMode!;

    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getToolIcon(activeMode),
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${activeMode.displayName}計測中',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(measurementProvider.notifier).cancelMeasurement();
                },
                child: const Text('キャンセル'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getInstructions(activeMode),
            style: theme.textTheme.bodySmall,
          ),
          if (state.tempPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    'ポイント: ${state.tempPoints.length}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    _formatValue(state.currentValue, state.currentUnit),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 編集モードの表示
  Widget _buildEditingIndicator(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    MeasurementState state,
  ) {
    // 編集中の計測を取得
    final measurement = state.measurements.firstWhere(
      (m) => m.id == state.editingMeasurementId,
      orElse: () => state.measurements.first,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(
            Icons.edit_location_alt,
            size: 20,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '「${measurement.name}」を編集中',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
                Text(
                  'ドラッグ:移動 / 右クリック:削除 / Enter:確定',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              ref.read(measurementProvider.notifier).endEditMode();
            },
            child: const Text('完了'),
          ),
        ],
      ),
    );
  }

  /// 空状態の表示
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

  /// 計測リストを構築
  Widget _buildMeasurementList(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    MeasurementState state,
  ) {
    return ListView.builder(
      itemCount: state.measurements.length,
      itemBuilder: (context, index) {
        final measurement = state.measurements[index];
        return _MeasurementTile(
          measurement: measurement,
          onVisibilityToggle: () {
            ref
                .read(measurementProvider.notifier)
                .toggleMeasurementVisibility(measurement.id);
          },
          onDelete: () {
            _showDeleteConfirmDialog(context, ref, measurement);
          },
          onTap: () {
            _showEditDialog(context, ref, measurement);
          },
        );
      },
    );
  }

  /// エクスポートボタンを構築
  Widget _buildExportButtons(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.table_chart, size: 16),
              label: const Text('CSV'),
              onPressed: () => _exportToCsv(context, ref),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.map, size: 16),
              label: const Text('GeoJSON'),
              onPressed: () => _exportToGeoJson(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  /// 削除確認ダイアログを表示
  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    Measurement measurement,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('計測を削除'),
        content: Text('「${measurement.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(measurementProvider.notifier)
                  .deleteMeasurement(measurement.id);
              Navigator.of(context).pop();
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  /// 編集ダイアログを表示
  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Measurement measurement,
  ) {
    showDialog(
      context: context,
      builder: (context) => _MeasurementEditDialog(
        measurement: measurement,
        onSave: (name, color, lineWidth, fillOpacity) {
          final notifier = ref.read(measurementProvider.notifier);
          if (name != measurement.name) {
            notifier.updateMeasurementName(measurement.id, name);
          }
          if (color != measurement.color ||
              lineWidth != measurement.lineWidth) {
            notifier.updateMeasurementStyle(
              measurementId: measurement.id,
              color: color,
              lineWidth: lineWidth,
              fillOpacity: fillOpacity,
            );
          }
        },
        onEditPoints: () {
          Navigator.of(context).pop();
          ref.read(measurementProvider.notifier).startEditMode(measurement.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('ドラッグ:移動 / 右クリック:削除 / Enterで確定'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '終了',
                onPressed: () {
                  ref.read(measurementProvider.notifier).endEditMode();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// CSVエクスポート
  Future<void> _exportToCsv(BuildContext context, WidgetRef ref) async {
    try {
      final csv = await ref.read(measurementProvider.notifier).exportToCsv();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'CSV保存先を選択',
        fileName: 'measurements.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        await File(result).writeAsString(csv);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSVを保存しました')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エクスポートに失敗しました: $e')),
        );
      }
    }
  }

  /// GeoJSONエクスポート
  Future<void> _exportToGeoJson(BuildContext context, WidgetRef ref) async {
    try {
      final geoJson =
          await ref.read(measurementProvider.notifier).exportToGeoJson();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'GeoJSON保存先を選択',
        fileName: 'measurements.geojson',
        type: FileType.custom,
        allowedExtensions: ['geojson', 'json'],
      );

      if (result != null) {
        await File(result).writeAsString(jsonEncode(geoJson));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GeoJSONを保存しました')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エクスポートに失敗しました: $e')),
        );
      }
    }
  }

  /// 計測タイプに対応するアイコンを取得
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

  /// 計測タイプに対応する説明を取得
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

  /// 計測値をフォーマット
  String _formatValue(double value, String unit) {
    if (unit == 'm²' && value >= 10000) {
      return '${(value / 10000).toStringAsFixed(2)} ha';
    } else if (unit == 'm' && value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} km';
    }
    return '${value.toStringAsFixed(2)} $unit';
  }
}

/// 計測結果タイル
class _MeasurementTile extends StatelessWidget {
  final Measurement measurement;
  final VoidCallback onVisibilityToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _MeasurementTile({
    required this.measurement,
    required this.onVisibilityToggle,
    required this.onDelete,
    required this.onTap,
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
            ? Color(int.parse(measurement.color.replaceFirst('#', '0xFF')))
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
              measurement.visible ? Icons.visibility : Icons.visibility_off,
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
      onTap: onTap,
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

/// 計測編集ダイアログ
class _MeasurementEditDialog extends StatefulWidget {
  final Measurement measurement;
  final Function(String name, String color, double lineWidth, double fillOpacity)
      onSave;
  final VoidCallback onEditPoints;

  const _MeasurementEditDialog({
    required this.measurement,
    required this.onSave,
    required this.onEditPoints,
  });

  @override
  State<_MeasurementEditDialog> createState() => _MeasurementEditDialogState();
}

class _MeasurementEditDialogState extends State<_MeasurementEditDialog> {
  late TextEditingController _nameController;
  late String _selectedColor;
  late double _lineWidth;
  late double _fillOpacity;

  // 利用可能な色
  static const List<String> _colorOptions = [
    '#FF0000', // 赤
    '#00FF00', // 緑
    '#0000FF', // 青
    '#FFFF00', // 黄
    '#FF00FF', // マゼンタ
    '#00FFFF', // シアン
    '#FFA500', // オレンジ
    '#800080', // 紫
    '#FFC0CB', // ピンク
    '#FFFFFF', // 白
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.measurement.name);
    _selectedColor = widget.measurement.color;
    _lineWidth = widget.measurement.lineWidth;
    _fillOpacity = 0.3; // デフォルト値
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('計測を編集'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名前
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 色選択
              Text('色', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorOptions.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.grey,
                          width: isSelected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 線の太さ
              Text('線の太さ: ${_lineWidth.toStringAsFixed(1)}',
                  style: theme.textTheme.titleSmall),
              Slider(
                value: _lineWidth,
                min: 1,
                max: 10,
                divisions: 18,
                onChanged: (value) => setState(() => _lineWidth = value),
              ),

              // 塗りの不透明度（面積計測のみ）
              if (widget.measurement.type == MeasurementType.area) ...[
                Text('塗りの不透明度: ${(_fillOpacity * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.titleSmall),
                Slider(
                  value: _fillOpacity,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: (value) => setState(() => _fillOpacity = value),
                ),
              ],
              const SizedBox(height: 8),

              // ポイント編集ボタン
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_location_alt, size: 18),
                  label: const Text('ポイント位置を編集'),
                  onPressed: widget.onEditPoints,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(
              _nameController.text,
              _selectedColor,
              _lineWidth,
              _fillOpacity,
            );
            Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
