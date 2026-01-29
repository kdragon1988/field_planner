/// ドローンインポートダイアログ
/// 
/// JSONファイルからドローンフォーメーションをインポートするダイアログ。
/// ファイル選択、プレビュー表示、インポート設定を提供する。
/// 
/// 主な機能:
/// - JSONファイル選択
/// - プレビュー表示（機数、座標範囲）
/// - フォーメーション名の編集
/// - インポート実行

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/drone_formation.dart';
import '../../providers/asset_provider.dart';

/// ドローンインポートダイアログ
class DroneImportDialog extends ConsumerStatefulWidget {
  const DroneImportDialog({super.key});

  @override
  ConsumerState<DroneImportDialog> createState() => _DroneImportDialogState();
}

class _DroneImportDialogState extends ConsumerState<DroneImportDialog> {
  String? _selectedFilePath;
  String? _fileName;
  DroneFormation? _previewFormation;
  String _formationName = '';
  bool _isLoading = false;
  String? _errorMessage;

  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ドローンフォーメーションをインポート'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ファイル選択
            _buildFileSelector(),
            const SizedBox(height: 16),

            // エラーメッセージ
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // プレビュー
            if (_previewFormation != null) ...[
              _buildPreview(),
              const SizedBox(height: 16),
              _buildNameInput(),
            ],

            // ローディング
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _previewFormation != null && !_isLoading
              ? _onImport
              : null,
          child: const Text('インポート'),
        ),
      ],
    );
  }

  Widget _buildFileSelector() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _selectFile,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      child: Row(
        children: [
          const Icon(Icons.upload_file),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fileName ?? 'JSONファイルを選択...',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_selectedFilePath != null)
            const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final formation = _previewFormation!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flight,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'プレビュー',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('機数', '${formation.droneCount}機'),
          _buildInfoRow(
            'サイズ',
            '${formation.width.toStringAsFixed(1)}m × ${formation.depth.toStringAsFixed(1)}m',
          ),
          _buildInfoRow(
            'X座標範囲',
            '${formation.xRange.min.toStringAsFixed(1)} ~ ${formation.xRange.max.toStringAsFixed(1)}m',
          ),
          _buildInfoRow(
            'Y座標範囲',
            '${formation.yRange.min.toStringAsFixed(1)} ~ ${formation.yRange.max.toStringAsFixed(1)}m',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildNameInput() {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'フォーメーション名',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        setState(() => _formationName = value);
      },
    );
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        setState(() {
          _selectedFilePath = filePath;
          _fileName = fileName;
          _isLoading = true;
          _errorMessage = null;
          _previewFormation = null;
        });

        await _loadPreview(filePath, fileName);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'ファイルの選択に失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPreview(String filePath, String fileName) async {
    try {
      final repository = ref.read(droneFormationRepositoryProvider);
      final formation = await repository.importFromFile(filePath);

      // ファイル名をデフォルト名に設定
      final baseName = fileName.replaceAll('.json', '');

      setState(() {
        _previewFormation = formation;
        _formationName = baseName;
        _nameController.text = baseName;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _previewFormation = null;
      });
    }
  }

  Future<void> _onImport() async {
    if (_selectedFilePath == null || _previewFormation == null) return;

    setState(() => _isLoading = true);

    try {
      final name = _formationName.isNotEmpty
          ? _formationName
          : _previewFormation!.name;

      final formation = await ref.read(assetNotifierProvider.notifier)
          .importDroneFormation(_selectedFilePath!, name: name);

      if (mounted) {
        Navigator.pop(context, formation);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'インポートに失敗しました: $e';
        _isLoading = false;
      });
    }
  }
}

/// ドローン配置設定ダイアログ
/// 
/// ドローンフォーメーションを地図上に配置する際の設定ダイアログ
class DronePlacementSettingsDialog extends ConsumerStatefulWidget {
  final DroneFormation formation;

  const DronePlacementSettingsDialog({
    super.key,
    required this.formation,
  });

  @override
  ConsumerState<DronePlacementSettingsDialog> createState() =>
      _DronePlacementSettingsDialogState();
}

class _DronePlacementSettingsDialogState
    extends ConsumerState<DronePlacementSettingsDialog> {
  double _altitude = 50.0;
  double _scale = 1.0;
  double _pointSize = 10.0;
  bool _useIndividualColors = true;
  Color _customColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.formation.name}を配置'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 高さ設定
            _buildSliderField(
              label: '高度',
              value: _altitude,
              min: 10,
              max: 200,
              suffix: 'm',
              onChanged: (v) => setState(() => _altitude = v),
            ),
            const SizedBox(height: 16),

            // スケール設定
            _buildSliderField(
              label: 'スケール',
              value: _scale,
              min: 0.1,
              max: 5.0,
              suffix: '×',
              onChanged: (v) => setState(() => _scale = v),
            ),
            const SizedBox(height: 16),

            // ポイントサイズ設定
            _buildSliderField(
              label: 'ポイントサイズ',
              value: _pointSize,
              min: 5,
              max: 30,
              suffix: 'px',
              onChanged: (v) => setState(() => _pointSize = v),
            ),
            const SizedBox(height: 16),

            // 色設定
            SwitchListTile(
              title: const Text('個別色を使用'),
              subtitle: const Text('各ドローンのLED色を表示'),
              value: _useIndividualColors,
              onChanged: (v) => setState(() => _useIndividualColors = v),
              contentPadding: EdgeInsets.zero,
            ),

            if (!_useIndividualColors) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('統一色:'),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _selectColor,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _customColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _getSettings()),
          child: const Text('配置開始'),
        ),
      ],
    );
  }

  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label)),
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
          child: Text('${value.toStringAsFixed(1)}$suffix'),
        ),
      ],
    );
  }

  Future<void> _selectColor() async {
    // シンプルな色選択（実際のアプリではカラーピッカーを使用）
    final colors = [
      Colors.white,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.yellow,
      Colors.cyan,
      Colors.purple,
      Colors.orange,
    ];

    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('色を選択'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () => Navigator.pop(context, color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: color == _customColor ? Colors.black : Colors.grey,
                    width: color == _customColor ? 2 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _customColor = selected);
    }
  }

  Map<String, dynamic> _getSettings() {
    return {
      'altitude': _altitude,
      'scale': _scale,
      'pointSize': _pointSize,
      'useIndividualColors': _useIndividualColors,
      'customColor': !_useIndividualColors
          ? '#${_customColor.value.toRadixString(16).substring(2)}'
          : null,
    };
  }
}
