import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// 3D Tilesインポートダイアログ
///
/// DJI Terra出力などの3D Tilesフォルダをインポートするためのダイアログ。
/// フォルダ選択、名称設定、表示オプションの設定が可能。
class TilesetImportDialog extends ConsumerStatefulWidget {
  const TilesetImportDialog({super.key});

  @override
  ConsumerState<TilesetImportDialog> createState() => _TilesetImportDialogState();
}

class _TilesetImportDialogState extends ConsumerState<TilesetImportDialog> {
  /// 選択されたフォルダパス
  String? _selectedFolderPath;

  /// tileset.jsonのパス
  String? _tilesetJsonPath;

  /// 検出されたTilesetタイプ
  TilesetType? _detectedType;

  /// 名称
  final _nameController = TextEditingController();

  /// エラーメッセージ
  String? _errorMessage;

  /// 処理中フラグ
  bool _isProcessing = false;

  /// Google 3D Tilesをクリッピングする（メッシュの範囲で非表示）
  bool _clipGoogleTiles = true;

  /// インポート後にカメラを移動
  bool _flyToAfterImport = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.view_in_ar),
          SizedBox(width: 8),
          Text('3Dモデルをインポート'),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 説明テキスト
            Text(
              'DJI Terra出力などの3D Tiles（B3DM）フォルダを選択してください。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // フォルダ選択
            _buildFolderSelector(theme),

            // エラーメッセージ
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 検出されたTilesetタイプ
            if (_detectedType != null) ...[
              const SizedBox(height: 16),
              _buildDetectedTypeInfo(theme),
            ],

            // 名称入力
            if (_tilesetJsonPath != null) ...[
              const SizedBox(height: 16),
              _buildNameInput(theme),
            ],

            // オプション
            if (_tilesetJsonPath != null) ...[
              const SizedBox(height: 16),
              _buildOptions(theme),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isProcessing || _tilesetJsonPath == null
              ? null
              : _importTileset,
          child: _isProcessing
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

  /// フォルダ選択UIを構築
  Widget _buildFolderSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('3D Tilesフォルダ'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _selectedFolderPath ?? 'フォルダを選択してください',
                  overflow: TextOverflow.ellipsis,
                  style: _selectedFolderPath == null
                      ? TextStyle(color: theme.hintColor)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _selectFolder,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('参照...'),
            ),
          ],
        ),
      ],
    );
  }

  /// 検出されたTilesetタイプ情報を構築
  Widget _buildDetectedTypeInfo(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _getTypeIcon(_detectedType!),
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _detectedType!.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    _tilesetJsonPath ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  /// 名称入力UIを構築
  Widget _buildNameInput(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('名称'),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'レイヤー名を入力',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  /// オプションUIを構築
  Widget _buildOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  subtitle: const Text('モデルが埋まらないようにする'),
                  value: _clipGoogleTiles,
                  onChanged: (value) {
                    setState(() => _clipGoogleTiles = value);
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

  /// Tilesetタイプに応じたアイコンを取得
  IconData _getTypeIcon(TilesetType type) {
    switch (type) {
      case TilesetType.mesh:
        return Icons.view_in_ar;
      case TilesetType.pointCloud:
        return Icons.grain;
      case TilesetType.buildings:
        return Icons.location_city;
      case TilesetType.unknown:
        return Icons.layers;
    }
  }

  /// フォルダを選択
  Future<void> _selectFolder() async {
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '3D Tilesフォルダを選択',
      );

      if (result != null) {
        await _analyzeFolder(result);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'フォルダの選択に失敗しました: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// フォルダを解析してtileset.jsonを探す
  Future<void> _analyzeFolder(String folderPath) async {
    setState(() {
      _selectedFolderPath = folderPath;
      _tilesetJsonPath = null;
      _detectedType = null;
      _errorMessage = null;
    });

    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      setState(() {
        _errorMessage = 'フォルダが存在しません';
      });
      return;
    }

    // tileset.jsonを探す
    String? tilesetJsonPath;
    TilesetType? detectedType;

    // まず直下をチェック
    final directTileset = File(p.join(folderPath, 'tileset.json'));
    if (await directTileset.exists()) {
      tilesetJsonPath = directTileset.path;
    }

    // サブフォルダもチェック（DJI Terraの出力構造に対応）
    if (tilesetJsonPath == null) {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && p.basename(entity.path) == 'tileset.json') {
          tilesetJsonPath = entity.path;
          break;
        }
      }
    }

    if (tilesetJsonPath == null) {
      setState(() {
        _errorMessage = 'tileset.jsonが見つかりません。\n'
            '3D Tilesフォルダ（DJI Terra出力など）を選択してください。';
      });
      return;
    }

    // Tilesetタイプを判定（ファイル内容やフォルダ構成から推測）
    detectedType = await _detectTilesetType(tilesetJsonPath);

    // 名称をフォルダ名から自動設定
    final folderName = p.basename(folderPath);
    _nameController.text = folderName;

    setState(() {
      _tilesetJsonPath = tilesetJsonPath;
      _detectedType = detectedType;
    });
  }

  /// Tilesetタイプを検出
  Future<TilesetType> _detectTilesetType(String tilesetJsonPath) async {
    try {
      final file = File(tilesetJsonPath);
      final content = await file.readAsString();

      // B3DMファイルの存在をチェック
      final parentDir = p.dirname(tilesetJsonPath);
      final dir = Directory(parentDir);
      bool hasB3dm = false;
      bool hasPnts = false;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.b3dm') hasB3dm = true;
          if (ext == '.pnts') hasPnts = true;
        }
      }

      if (hasPnts) return TilesetType.pointCloud;
      if (hasB3dm) return TilesetType.mesh;

      // JSONの内容からも判断を試みる
      if (content.contains('"geometricError"')) {
        return TilesetType.mesh;
      }

      return TilesetType.unknown;
    } catch (e) {
      return TilesetType.unknown;
    }
  }

  /// インポートを実行
  void _importTileset() {
    if (_tilesetJsonPath == null) return;

    final name = _nameController.text.isNotEmpty
        ? _nameController.text
        : p.basename(_selectedFolderPath ?? 'Unnamed');

    final result = TilesetImportResult(
      id: const Uuid().v4(),
      name: name,
      tilesetJsonPath: _tilesetJsonPath!,
      folderPath: _selectedFolderPath!,
      type: _detectedType ?? TilesetType.unknown,
      clipGoogleTiles: _clipGoogleTiles,
      flyToAfterImport: _flyToAfterImport,
    );

    Navigator.of(context).pop(result);
  }
}

/// Tilesetタイプ
enum TilesetType {
  mesh('3Dメッシュ'),
  pointCloud('点群'),
  buildings('建物'),
  unknown('不明');

  final String displayName;
  const TilesetType(this.displayName);
}

/// インポート結果
class TilesetImportResult {
  /// ユニークID
  final String id;

  /// 表示名
  final String name;

  /// tileset.jsonのパス
  final String tilesetJsonPath;

  /// フォルダパス
  final String folderPath;

  /// Tilesetタイプ
  final TilesetType type;

  /// Google 3D Tilesをクリッピングするか
  final bool clipGoogleTiles;

  /// インポート後にカメラを移動するか
  final bool flyToAfterImport;

  TilesetImportResult({
    required this.id,
    required this.name,
    required this.tilesetJsonPath,
    required this.folderPath,
    required this.type,
    this.clipGoogleTiles = true,
    this.flyToAfterImport = true,
  });
}
