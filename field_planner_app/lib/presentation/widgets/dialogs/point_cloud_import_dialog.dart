import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/models/import_format.dart';
import '../../../data/services/file_analyzer_service.dart';
import '../../../data/services/point_cloud_converter.dart';

/// 点群インポート結果
/// 
/// インポートダイアログの結果を返す
class PointCloudImportResult {
  /// 表示名
  final String name;

  /// tileset.jsonのパス
  final String tilesetJsonPath;

  /// 出力フォルダパス
  final String outputPath;

  /// Google 3D Tilesを非表示にするか
  final bool hideGoogleTiles;

  /// インポート後にカメラを移動するか
  final bool flyToAfterImport;

  /// 点群タイプ
  final bool isPointCloud;

  const PointCloudImportResult({
    required this.name,
    required this.tilesetJsonPath,
    required this.outputPath,
    this.hideGoogleTiles = true,
    this.flyToAfterImport = true,
    this.isPointCloud = true,
  });
}

/// 点群インポートダイアログ
/// 
/// LAS/LAZ/PLY/E57ファイルを選択し、3D Tilesに変換してインポートする
class PointCloudImportDialog extends ConsumerStatefulWidget {
  /// プロジェクトパス（変換後のファイル保存先）
  final String? projectPath;

  const PointCloudImportDialog({
    super.key,
    this.projectPath,
  });

  @override
  ConsumerState<PointCloudImportDialog> createState() =>
      _PointCloudImportDialogState();
}

class _PointCloudImportDialogState
    extends ConsumerState<PointCloudImportDialog> {
  /// 選択されたファイルパス
  String? _selectedFilePath;

  /// ファイル情報
  PointCloudFileInfo? _fileInfo;

  /// 解析中フラグ
  bool _isAnalyzing = false;

  /// 変換中フラグ
  bool _isConverting = false;

  /// 変換進捗
  double _conversionProgress = 0.0;

  /// 変換ステータスメッセージ
  String _conversionMessage = '';

  /// エラーメッセージ
  String? _errorMessage;

  /// 名前入力コントローラー
  final _nameController = TextEditingController();

  /// ファイル解析サービス
  final _analyzerService = FileAnalyzerService();

  /// 点群変換サービス
  final _converter = PointCloudConverter();

  /// 変換進捗購読
  StreamSubscription<ConversionProgress>? _progressSubscription;

  // オプション
  /// Google 3D Tilesを非表示にする
  bool _hideGoogleTiles = true;

  /// インポート後にカメラを移動
  bool _flyToAfterImport = true;

  /// ソースCRS（EPSG）
  int? _sourceCrs;

  @override
  void initState() {
    super.initState();
    _progressSubscription = _converter.progressStream.listen((progress) {
      setState(() {
        _conversionProgress = progress.progress;
        _conversionMessage = progress.message;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _progressSubscription?.cancel();
    _converter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('点群をインポート'),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ファイル選択
              _buildFileSelector(theme),
              const SizedBox(height: 16),

              // エラーメッセージ
              if (_errorMessage != null) ...[
                _buildErrorMessage(theme),
                const SizedBox(height: 16),
              ],

              // ファイル情報
              if (_fileInfo != null) ...[
                _buildFileInfo(theme),
                const SizedBox(height: 16),
              ],

              // 変換進捗
              if (_isConverting) ...[
                _buildConversionProgress(theme),
                const SizedBox(height: 16),
              ],

              // オプション
              if (!_isConverting) ...[
                _buildOptions(theme),
              ],
            ],
          ),
        ),
      ),
      actions: _buildActions(theme),
    );
  }

  /// ファイル選択UIを構築
  Widget _buildFileSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('点群ファイル'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _selectedFilePath != null
                      ? p.basename(_selectedFilePath!)
                      : 'ファイルを選択...',
                  overflow: TextOverflow.ellipsis,
                  style: _selectedFilePath == null
                      ? TextStyle(color: theme.hintColor)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('参照'),
              onPressed: _isConverting ? null : _selectFile,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '対応形式: LAS, LAZ, PLY, E57',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// エラーメッセージを構築
  Widget _buildErrorMessage(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// ファイル情報を構築
  Widget _buildFileInfo(ThemeData theme) {
    final info = _fileInfo!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scatter_plot, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ファイル情報',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('フォーマット', info.formatVersion ?? '不明'),
            _buildInfoRow('ファイルサイズ', info.fileSizeDisplay),
            _buildInfoRow('点数', info.pointCountDisplay),
            if (info.geoReference?.boundingBox != null) ...[
              const Divider(),
              _buildInfoRow(
                '範囲 (X)',
                '${info.geoReference!.boundingBox!.width.toStringAsFixed(1)} m',
              ),
              _buildInfoRow(
                '範囲 (Y)',
                '${info.geoReference!.boundingBox!.height.toStringAsFixed(1)} m',
              ),
              _buildInfoRow(
                '範囲 (Z)',
                '${info.geoReference!.boundingBox!.depth.toStringAsFixed(1)} m',
              ),
            ],
            const Divider(),
            Row(
              children: [
                _buildAttributeChip('色', info.hasColor, theme),
                const SizedBox(width: 8),
                _buildAttributeChip('強度', info.hasIntensity, theme),
                const SizedBox(width: 8),
                _buildAttributeChip('分類', info.hasClassification, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeChip(String label, bool hasAttribute, ThemeData theme) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: hasAttribute
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      backgroundColor: hasAttribute
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(
        hasAttribute ? Icons.check : Icons.close,
        size: 14,
        color: hasAttribute
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// 変換進捗を構築
  Widget _buildConversionProgress(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: _conversionProgress > 0 ? _conversionProgress : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '3D Tilesに変換中...',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _conversionProgress),
            const SizedBox(height: 8),
            Text(
              _conversionMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${(_conversionProgress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// オプションを構築
  Widget _buildOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 名前入力
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: '表示名',
            hintText: _selectedFilePath != null
                ? p.basenameWithoutExtension(_selectedFilePath!)
                : '点群データ',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),

        // CRS設定（ジオリファレンス情報がない場合）
        if (_fileInfo != null && _fileInfo!.geoReference?.epsg == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                const Text('座標系（EPSG）: '),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '例: 6677',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _sourceCrs = int.tryParse(v),
                  ),
                ),
              ],
            ),
          ),

        // オプションスイッチ
        const Text('オプション'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SwitchListTile(
                  dense: true,
                  secondary: const Icon(Icons.layers_clear, size: 20),
                  title: const Text('Google 3D Tilesを非表示'),
                  subtitle: const Text('点群が埋まらないようにする'),
                  value: _hideGoogleTiles,
                  onChanged: (value) {
                    setState(() => _hideGoogleTiles = value);
                  },
                ),
                SwitchListTile(
                  dense: true,
                  secondary: const Icon(Icons.center_focus_strong, size: 20),
                  title: const Text('インポート後にカメラを移動'),
                  value: _flyToAfterImport,
                  onChanged: (value) {
                    setState(() => _flyToAfterImport = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// アクションボタンを構築
  List<Widget> _buildActions(ThemeData theme) {
    if (_isConverting) {
      return [
        TextButton(
          onPressed: () {
            _converter.cancel();
            Navigator.of(context).pop();
          },
          child: const Text('キャンセル'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('キャンセル'),
      ),
      ElevatedButton.icon(
        icon: const Icon(Icons.file_download, size: 18),
        label: const Text('インポート'),
        onPressed: _fileInfo != null && !_isAnalyzing ? _startImport : null,
      ),
    ];
  }

  /// ファイルを選択
  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ImportFormat.pointCloudExtensionsWithoutDot,
      dialogTitle: '点群ファイルを選択',
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _fileInfo = null;
        _errorMessage = null;
        _isAnalyzing = true;
      });

      await _analyzeFile();
    }
  }

  /// ファイルを解析
  Future<void> _analyzeFile() async {
    if (_selectedFilePath == null) return;

    try {
      final info =
          await _analyzerService.analyzePointCloudFile(_selectedFilePath!);

      setState(() {
        _fileInfo = info;
        _isAnalyzing = false;
        _nameController.text = p.basenameWithoutExtension(_selectedFilePath!);

        // ジオリファレンス情報からCRSを設定
        if (info?.geoReference?.epsg != null) {
          _sourceCrs = info!.geoReference!.epsg;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'ファイルの解析に失敗しました: $e';
        _isAnalyzing = false;
      });
    }
  }

  /// インポートを開始
  Future<void> _startImport() async {
    if (_selectedFilePath == null || _fileInfo == null) return;

    setState(() {
      _isConverting = true;
      _errorMessage = null;
      _conversionProgress = 0;
      _conversionMessage = '準備中...';
    });

    try {
      // 出力ディレクトリを決定
      final outputDir = widget.projectPath != null
          ? p.join(widget.projectPath!, 'converted')
          : p.join(p.dirname(_selectedFilePath!), 'converted');

      // 変換オプション
      final options = PointCloudConversionOptions(
        sourceCrs: _sourceCrs,
        outputName: _nameController.text.isNotEmpty
            ? _nameController.text
            : p.basenameWithoutExtension(_selectedFilePath!),
      );

      // 変換実行
      final result = await _converter.convert(
        inputPath: _selectedFilePath!,
        outputDir: outputDir,
        options: options,
      );

      if (!mounted) return;

      if (result.success) {
        // 成功
        final importResult = PointCloudImportResult(
          name: _nameController.text.isNotEmpty
              ? _nameController.text
              : p.basenameWithoutExtension(_selectedFilePath!),
          tilesetJsonPath: result.tilesetJsonPath!,
          outputPath: result.outputPath!,
          hideGoogleTiles: _hideGoogleTiles,
          flyToAfterImport: _flyToAfterImport,
          isPointCloud: true,
        );

        Navigator.of(context).pop(importResult);
      } else {
        // 失敗
        setState(() {
          _errorMessage = result.errorMessage;
          _isConverting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '変換中にエラーが発生しました: $e';
        _isConverting = false;
      });
    }
  }
}
