// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Asset _$AssetFromJson(Map<String, dynamic> json) => Asset(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  category: $enumDecode(_$AssetCategoryEnumMap, json['category']),
  modelPath: json['modelPath'] as String,
  thumbnailPath: json['thumbnailPath'] as String?,
  dimensions: AssetDimensions.fromJson(
    json['dimensions'] as Map<String, dynamic>,
  ),
  defaultScale: (json['defaultScale'] as num?)?.toDouble() ?? 1.0,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  isBuiltIn: json['isBuiltIn'] as bool? ?? false,
  isFavorite: json['isFavorite'] as bool? ?? false,
  usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$AssetToJson(Asset instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'category': _$AssetCategoryEnumMap[instance.category]!,
  'modelPath': instance.modelPath,
  'thumbnailPath': instance.thumbnailPath,
  'dimensions': instance.dimensions,
  'defaultScale': instance.defaultScale,
  'tags': instance.tags,
  'isBuiltIn': instance.isBuiltIn,
  'isFavorite': instance.isFavorite,
  'usageCount': instance.usageCount,
};

const _$AssetCategoryEnumMap = {
  AssetCategory.tent: 'tent',
  AssetCategory.stage: 'stage',
  AssetCategory.barrier: 'barrier',
  AssetCategory.table: 'table',
  AssetCategory.chair: 'chair',
  AssetCategory.lighting: 'lighting',
  AssetCategory.signage: 'signage',
  AssetCategory.other: 'other',
};

AssetDimensions _$AssetDimensionsFromJson(Map<String, dynamic> json) =>
    AssetDimensions(
      width: (json['width'] as num).toDouble(),
      depth: (json['depth'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );

Map<String, dynamic> _$AssetDimensionsToJson(AssetDimensions instance) =>
    <String, dynamic>{
      'width': instance.width,
      'depth': instance.depth,
      'height': instance.height,
    };
