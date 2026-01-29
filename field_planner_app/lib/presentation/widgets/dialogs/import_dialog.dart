import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../data/models/import_job.dart';

/// インポートダイアログ
///
/// 3Dデータのインポートオプションを設定して実行
class ImportDialog extends ConsumerStatefulWidget {
  final String projectPath;

  const ImportDialog({
    super.key,
    required this.projectPath,
  });

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  String? _selectedFilePath;
  ImportFormat? _detectedFormat;
  bool _copyToProject = true;
  bool _autoConvert = true;
  int? _manualEpsg;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('3Dデータをインポート'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ファイル選択
            _buildFileSelector(theme),
            const SizedBox(height: 16),

            // フォーマット表示
            if (_detectedFormat != null) ...[
              _buildFormatInfo(theme),
              const SizedBox(height: 16),
            ],

            // オプション
            _buildOptions(theme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isImporting || _selectedFilePath == null
              ? null
              : _startImport,
          child: _isImporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('インポート'),
        ),
      ],
    );
  }

  Widget _buildFileSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ファイル'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _selectedFilePath ?? 'ファイルを選択してください',
                  overflow: TextOverflow.ellipsis,
                  style: _selectedFilePath == null
                      ? TextStyle(color: theme.hintColor)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _selectFile,
              child: const Text('参照...'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatInfo(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _getFormatIcon(_detectedFormat!),
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _detectedFormat!.displayName,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  _detectedFormat!.category.displayName,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('オプション'),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('プロジェクトにコピー'),
          subtitle: const Text('インポート元ファイルをプロジェクトフォルダにコピーします'),
          value: _copyToProject,
          onChanged: (value) {
            setState(() => _copyToProject = value ?? true);
          },
        ),
        CheckboxListTile(
          title: const Text('自動変換'),
          subtitle: const Text('3D Tiles形式に自動変換します（推奨）'),
          value: _autoConvert,
          onChanged: (value) {
            setState(() => _autoConvert = value ?? true);
          },
        ),
      ],
    );
  }

  IconData _getFormatIcon(ImportFormat format) {
    switch (format.category) {
      case ImportCategory.pointCloud:
        return Icons.grain;
      case ImportCategory.mesh:
        return Icons.view_in_ar;
      case ImportCategory.tiles:
        return Icons.layers;
    }
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'las', 'laz', 'ply', 'e57',
        'obj', 'fbx', 'gltf', 'glb',
        'json',
      ],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final ext = path.split('.').last;
      final format = ImportFormat.fromExtension(ext);

      setState(() {
        _selectedFilePath = path;
        _detectedFormat = format;
      });
    }
  }

  void _startImport() {
    if (_selectedFilePath == null) return;

    final result = ImportDialogResult(
      filePath: _selectedFilePath!,
      format: _detectedFormat!,
      options: ImportOptions(
        copyToProject: _copyToProject,
        autoConvert: _autoConvert,
        manualEpsg: _manualEpsg,
      ),
    );

    Navigator.of(context).pop(result);
  }
}

/// インポートダイアログの結果
class ImportDialogResult {
  final String filePath;
  final ImportFormat format;
  final ImportOptions options;

  ImportDialogResult({
    required this.filePath,
    required this.format,
    required this.options,
  });
}
