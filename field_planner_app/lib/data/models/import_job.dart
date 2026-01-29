import 'package:json_annotation/json_annotation.dart';

part 'import_job.g.dart';

/// インポート可能なファイル形式
enum ImportFormat {
  /// LAS形式（点群）
  las('LAS', 'las', ImportCategory.pointCloud),

  /// LAZ形式（圧縮点群）
  laz('LAZ', 'laz', ImportCategory.pointCloud),

  /// PLY形式（点群/メッシュ）
  ply('PLY', 'ply', ImportCategory.pointCloud),

  /// E57形式（点群）
  e57('E57', 'e57', ImportCategory.pointCloud),

  /// OBJ形式（メッシュ）
  obj('OBJ', 'obj', ImportCategory.mesh),

  /// FBX形式（メッシュ）
  fbx('FBX', 'fbx', ImportCategory.mesh),

  /// glTF形式（メッシュ）
  gltf('glTF', 'gltf', ImportCategory.mesh),

  /// GLB形式（バイナリglTF）
  glb('GLB', 'glb', ImportCategory.mesh),

  /// 3D Tiles形式
  tiles3d('3D Tiles', 'json', ImportCategory.tiles);

  final String displayName;
  final String extension;
  final ImportCategory category;

  const ImportFormat(this.displayName, this.extension, this.category);

  /// 拡張子からフォーマットを判定
  static ImportFormat? fromExtension(String ext) {
    final lower = ext.toLowerCase().replaceAll('.', '');
    for (final format in values) {
      if (format.extension == lower) {
        return format;
      }
    }
    return null;
  }
}

/// インポートカテゴリ
enum ImportCategory {
  pointCloud('点群'),
  mesh('メッシュ'),
  tiles('3D Tiles');

  final String displayName;
  const ImportCategory(this.displayName);
}

/// インポートジョブの状態
enum ImportStatus {
  pending('待機中'),
  analyzing('解析中'),
  converting('変換中'),
  copying('コピー中'),
  completed('完了'),
  failed('失敗'),
  cancelled('キャンセル');

  final String displayName;
  const ImportStatus(this.displayName);
}

/// インポートジョブ
@JsonSerializable()
class ImportJob {
  /// ジョブID
  final String id;

  /// ソースファイルパス
  final String sourcePath;

  /// 出力先パス
  final String? outputPath;

  /// フォーマット
  final ImportFormat format;

  /// ステータス
  final ImportStatus status;

  /// 進捗（0.0〜1.0）
  final double progress;

  /// エラーメッセージ
  final String? errorMessage;

  /// 地理参照情報
  final GeoReference? geoReference;

  /// ポイント数（点群の場合）
  final int? pointCount;

  /// 作成日時
  final DateTime createdAt;

  /// 完了日時
  final DateTime? completedAt;

  const ImportJob({
    required this.id,
    required this.sourcePath,
    this.outputPath,
    required this.format,
    this.status = ImportStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.geoReference,
    this.pointCount,
    required this.createdAt,
    this.completedAt,
  });

  factory ImportJob.fromJson(Map<String, dynamic> json) =>
      _$ImportJobFromJson(json);

  Map<String, dynamic> toJson() => _$ImportJobToJson(this);

  /// ファイル名を取得
  String get fileName {
    final parts = sourcePath.split('/');
    return parts.isNotEmpty ? parts.last : sourcePath;
  }

  ImportJob copyWith({
    String? id,
    String? sourcePath,
    String? outputPath,
    ImportFormat? format,
    ImportStatus? status,
    double? progress,
    String? errorMessage,
    GeoReference? geoReference,
    int? pointCount,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return ImportJob(
      id: id ?? this.id,
      sourcePath: sourcePath ?? this.sourcePath,
      outputPath: outputPath ?? this.outputPath,
      format: format ?? this.format,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      geoReference: geoReference ?? this.geoReference,
      pointCount: pointCount ?? this.pointCount,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// 地理参照情報
@JsonSerializable()
class GeoReference {
  /// EPSGコード
  final int? epsg;

  /// 原点X
  final double? originX;

  /// 原点Y
  final double? originY;

  /// 原点Z
  final double? originZ;

  /// バウンディングボックス最小X
  final double? minX;

  /// バウンディングボックス最小Y
  final double? minY;

  /// バウンディングボックス最小Z
  final double? minZ;

  /// バウンディングボックス最大X
  final double? maxX;

  /// バウンディングボックス最大Y
  final double? maxY;

  /// バウンディングボックス最大Z
  final double? maxZ;

  const GeoReference({
    this.epsg,
    this.originX,
    this.originY,
    this.originZ,
    this.minX,
    this.minY,
    this.minZ,
    this.maxX,
    this.maxY,
    this.maxZ,
  });

  factory GeoReference.fromJson(Map<String, dynamic> json) =>
      _$GeoReferenceFromJson(json);

  Map<String, dynamic> toJson() => _$GeoReferenceToJson(this);

  /// 座標系が設定されているか
  bool get hasCoordinateSystem => epsg != null;

  /// バウンディングボックスが設定されているか
  bool get hasBoundingBox =>
      minX != null &&
      minY != null &&
      maxX != null &&
      maxY != null;
}

/// インポートオプション
class ImportOptions {
  /// プロジェクトにファイルをコピー
  final bool copyToProject;

  /// 自動変換を実行
  final bool autoConvert;

  /// EPSGコードを手動指定
  final int? manualEpsg;

  const ImportOptions({
    this.copyToProject = true,
    this.autoConvert = true,
    this.manualEpsg,
  });
}
