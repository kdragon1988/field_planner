import 'package:json_annotation/json_annotation.dart';

part 'asset.g.dart';

/// アセットカテゴリ
enum AssetCategory {
  tent('テント', 'tent'),
  stage('ステージ', 'stage'),
  barrier('バリケード', 'barrier'),
  table('テーブル', 'table'),
  chair('椅子', 'chair'),
  lighting('照明', 'lighting'),
  signage('看板', 'signage'),
  droneShow('ドローンショー', 'drone_show'),
  other('その他', 'other');

  final String displayName;
  final String id;
  const AssetCategory(this.displayName, this.id);
}

/// アセットタイプ
/// 
/// 標準アセット（3Dモデル）とドローンフォーメーション（ポイント群）を区別
enum AssetType {
  /// 標準的な3Dモデルアセット
  standard('標準', 'standard'),
  
  /// ドローンフォーメーション（複数ポイント）
  droneFormation('ドローンフォーメーション', 'drone_formation');

  final String displayName;
  final String id;
  const AssetType(this.displayName, this.id);
}

/// アセットモデル
@JsonSerializable()
class Asset {
  /// ID
  final String id;

  /// アセット名
  final String name;

  /// 説明
  final String? description;

  /// カテゴリ
  final AssetCategory category;

  /// モデルファイルパス（GLB形式）
  final String modelPath;

  /// サムネイル画像パス
  final String? thumbnailPath;

  /// 寸法（メートル）
  final AssetDimensions dimensions;

  /// デフォルトスケール
  final double defaultScale;

  /// タグ
  final List<String> tags;

  /// ビルトインアセットかどうか
  final bool isBuiltIn;

  /// お気に入りフラグ
  final bool isFavorite;

  /// 使用回数
  final int usageCount;

  const Asset({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.modelPath,
    this.thumbnailPath,
    required this.dimensions,
    this.defaultScale = 1.0,
    this.tags = const [],
    this.isBuiltIn = false,
    this.isFavorite = false,
    this.usageCount = 0,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => _$AssetFromJson(json);

  Map<String, dynamic> toJson() => _$AssetToJson(this);

  Asset copyWith({
    String? id,
    String? name,
    String? description,
    AssetCategory? category,
    String? modelPath,
    String? thumbnailPath,
    AssetDimensions? dimensions,
    double? defaultScale,
    List<String>? tags,
    bool? isBuiltIn,
    bool? isFavorite,
    int? usageCount,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      modelPath: modelPath ?? this.modelPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      dimensions: dimensions ?? this.dimensions,
      defaultScale: defaultScale ?? this.defaultScale,
      tags: tags ?? this.tags,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isFavorite: isFavorite ?? this.isFavorite,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}

/// アセットの寸法
@JsonSerializable()
class AssetDimensions {
  /// 幅（X方向、メートル）
  final double width;

  /// 奥行き（Y方向、メートル）
  final double depth;

  /// 高さ（Z方向、メートル）
  final double height;

  const AssetDimensions({
    required this.width,
    required this.depth,
    required this.height,
  });

  factory AssetDimensions.fromJson(Map<String, dynamic> json) =>
      _$AssetDimensionsFromJson(json);

  Map<String, dynamic> toJson() => _$AssetDimensionsToJson(this);

  @override
  String toString() => '${width}m × ${depth}m × ${height}m';
}

/// サンプルアセット（デモ用）
class SampleAssets {
  static const List<Asset> all = [
    Asset(
      id: 'tent_small',
      name: '小型テント',
      category: AssetCategory.tent,
      modelPath: 'assets/models/tent_small.glb',
      dimensions: AssetDimensions(width: 3, depth: 3, height: 2.5),
      isBuiltIn: true,
      tags: ['テント', '小型', '屋外'],
    ),
    Asset(
      id: 'tent_large',
      name: '大型テント',
      category: AssetCategory.tent,
      modelPath: 'assets/models/tent_large.glb',
      dimensions: AssetDimensions(width: 6, depth: 6, height: 3.5),
      isBuiltIn: true,
      tags: ['テント', '大型', '屋外'],
    ),
    Asset(
      id: 'stage_basic',
      name: '基本ステージ',
      category: AssetCategory.stage,
      modelPath: 'assets/models/stage_basic.glb',
      dimensions: AssetDimensions(width: 8, depth: 6, height: 1.2),
      isBuiltIn: true,
      tags: ['ステージ', '音響', 'イベント'],
    ),
    Asset(
      id: 'barrier_fence',
      name: 'フェンスバリケード',
      category: AssetCategory.barrier,
      modelPath: 'assets/models/barrier_fence.glb',
      dimensions: AssetDimensions(width: 2, depth: 0.5, height: 1.1),
      isBuiltIn: true,
      tags: ['バリケード', '安全', '仕切り'],
    ),
    Asset(
      id: 'table_folding',
      name: '折りたたみテーブル',
      category: AssetCategory.table,
      modelPath: 'assets/models/table_folding.glb',
      dimensions: AssetDimensions(width: 1.8, depth: 0.6, height: 0.72),
      isBuiltIn: true,
      tags: ['テーブル', '折りたたみ'],
    ),
    Asset(
      id: 'chair_folding',
      name: '折りたたみ椅子',
      category: AssetCategory.chair,
      modelPath: 'assets/models/chair_folding.glb',
      dimensions: AssetDimensions(width: 0.45, depth: 0.45, height: 0.8),
      isBuiltIn: true,
      tags: ['椅子', '折りたたみ'],
    ),
  ];
}
