import 'package:path/path.dart' as path;

/// インポートカテゴリ
/// 
/// インポート可能なファイルの種類を分類
enum ImportCategory {
  /// 点群データ
  pointCloud('点群'),
  
  /// メッシュデータ
  mesh('メッシュ'),
  
  /// 3D Tiles（変換済み）
  tiles3d('3D Tiles');

  /// 表示名
  final String displayName;
  
  const ImportCategory(this.displayName);
}

/// インポート対応フォーマット
/// 
/// アプリでインポート可能なファイルフォーマットの定義
enum ImportFormat {
  // 点群フォーマット
  /// ASPRS LAS点群
  las('LAS', '.las', ImportCategory.pointCloud, 'ASPRS LAS点群'),
  
  /// ASPRS LAZ圧縮点群
  laz('LAZ', '.laz', ImportCategory.pointCloud, 'ASPRS LAZ圧縮点群'),
  
  /// PLY点群
  plyPoints('PLY (点群)', '.ply', ImportCategory.pointCloud, 'PLY点群'),
  
  /// E57点群
  e57('E57', '.e57', ImportCategory.pointCloud, 'E57点群'),

  // メッシュフォーマット
  /// Wavefront OBJメッシュ
  obj('OBJ', '.obj', ImportCategory.mesh, 'Wavefront OBJメッシュ'),
  
  /// Autodesk FBXメッシュ
  fbx('FBX', '.fbx', ImportCategory.mesh, 'Autodesk FBXメッシュ'),
  
  /// glTF 2.0
  gltf('glTF', '.gltf', ImportCategory.mesh, 'glTF 2.0'),
  
  /// glTF Binaryメッシュ
  glb('GLB', '.glb', ImportCategory.mesh, 'glTF Binaryメッシュ'),

  // 3D Tiles（変換済み）
  /// Cesium 3D Tiles
  tiles3d('3D Tiles', 'tileset.json', ImportCategory.tiles3d, 'Cesium 3D Tiles');

  /// 表示名
  final String displayName;
  
  /// ファイル拡張子
  final String extension;
  
  /// カテゴリ
  final ImportCategory category;
  
  /// 説明
  final String description;

  const ImportFormat(
    this.displayName,
    this.extension,
    this.category,
    this.description,
  );

  /// 拡張子からフォーマットを判定
  /// 
  /// [ext] ファイル拡張子（ドット付き、例: ".las"）
  /// 該当するフォーマットがない場合はnullを返す
  static ImportFormat? fromExtension(String ext) {
    final lowerExt = ext.toLowerCase();
    for (final format in ImportFormat.values) {
      if (format.extension == lowerExt) {
        return format;
      }
    }
    return null;
  }

  /// ファイルパスからフォーマットを判定
  /// 
  /// [filePath] ファイルパス
  static ImportFormat? fromFilePath(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return fromExtension(ext);
  }

  /// 全ての拡張子リストを取得（ファイルダイアログ用）
  static List<String> get allExtensions =>
      ImportFormat.values.map((f) => f.extension).toList();

  /// 点群フォーマットの拡張子リストを取得
  static List<String> get pointCloudExtensions => ImportFormat.values
      .where((f) => f.category == ImportCategory.pointCloud)
      .map((f) => f.extension)
      .toList();

  /// メッシュフォーマットの拡張子リストを取得
  static List<String> get meshExtensions => ImportFormat.values
      .where((f) => f.category == ImportCategory.mesh)
      .map((f) => f.extension)
      .toList();

  /// ファイルダイアログ用の拡張子リスト（ドットなし）
  static List<String> get allExtensionsWithoutDot =>
      allExtensions.map((e) => e.replaceFirst('.', '')).toList();

  /// 点群ファイルダイアログ用の拡張子リスト（ドットなし）
  static List<String> get pointCloudExtensionsWithoutDot =>
      pointCloudExtensions.map((e) => e.replaceFirst('.', '')).toList();

  /// 指定されたカテゴリのフォーマット一覧を取得
  static List<ImportFormat> getByCategory(ImportCategory category) =>
      ImportFormat.values.where((f) => f.category == category).toList();

  /// このフォーマットが点群かどうか
  bool get isPointCloud => category == ImportCategory.pointCloud;

  /// このフォーマットがメッシュかどうか
  bool get isMesh => category == ImportCategory.mesh;

  /// このフォーマットが3D Tilesかどうか
  bool get isTiles3d => category == ImportCategory.tiles3d;
}

/// 未対応フォーマット例外
class UnsupportedFormatException implements Exception {
  /// 未対応の拡張子
  final String extension;

  UnsupportedFormatException(this.extension);

  @override
  String toString() => '未対応のフォーマットです: $extension';
}
