// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImportJob _$ImportJobFromJson(Map<String, dynamic> json) => ImportJob(
  id: json['id'] as String,
  sourcePath: json['sourcePath'] as String,
  outputPath: json['outputPath'] as String?,
  format: $enumDecode(_$ImportFormatEnumMap, json['format']),
  status:
      $enumDecodeNullable(_$ImportStatusEnumMap, json['status']) ??
      ImportStatus.pending,
  progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
  errorMessage: json['errorMessage'] as String?,
  geoReference: json['geoReference'] == null
      ? null
      : GeoReference.fromJson(json['geoReference'] as Map<String, dynamic>),
  pointCount: (json['pointCount'] as num?)?.toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
);

Map<String, dynamic> _$ImportJobToJson(ImportJob instance) => <String, dynamic>{
  'id': instance.id,
  'sourcePath': instance.sourcePath,
  'outputPath': instance.outputPath,
  'format': _$ImportFormatEnumMap[instance.format]!,
  'status': _$ImportStatusEnumMap[instance.status]!,
  'progress': instance.progress,
  'errorMessage': instance.errorMessage,
  'geoReference': instance.geoReference,
  'pointCount': instance.pointCount,
  'createdAt': instance.createdAt.toIso8601String(),
  'completedAt': instance.completedAt?.toIso8601String(),
};

const _$ImportFormatEnumMap = {
  ImportFormat.las: 'las',
  ImportFormat.laz: 'laz',
  ImportFormat.ply: 'ply',
  ImportFormat.e57: 'e57',
  ImportFormat.obj: 'obj',
  ImportFormat.fbx: 'fbx',
  ImportFormat.gltf: 'gltf',
  ImportFormat.glb: 'glb',
  ImportFormat.tiles3d: 'tiles3d',
};

const _$ImportStatusEnumMap = {
  ImportStatus.pending: 'pending',
  ImportStatus.analyzing: 'analyzing',
  ImportStatus.converting: 'converting',
  ImportStatus.copying: 'copying',
  ImportStatus.completed: 'completed',
  ImportStatus.failed: 'failed',
  ImportStatus.cancelled: 'cancelled',
};

GeoReference _$GeoReferenceFromJson(Map<String, dynamic> json) => GeoReference(
  epsg: (json['epsg'] as num?)?.toInt(),
  originX: (json['originX'] as num?)?.toDouble(),
  originY: (json['originY'] as num?)?.toDouble(),
  originZ: (json['originZ'] as num?)?.toDouble(),
  minX: (json['minX'] as num?)?.toDouble(),
  minY: (json['minY'] as num?)?.toDouble(),
  minZ: (json['minZ'] as num?)?.toDouble(),
  maxX: (json['maxX'] as num?)?.toDouble(),
  maxY: (json['maxY'] as num?)?.toDouble(),
  maxZ: (json['maxZ'] as num?)?.toDouble(),
);

Map<String, dynamic> _$GeoReferenceToJson(GeoReference instance) =>
    <String, dynamic>{
      'epsg': instance.epsg,
      'originX': instance.originX,
      'originY': instance.originY,
      'originZ': instance.originZ,
      'minX': instance.minX,
      'minY': instance.minY,
      'minZ': instance.minZ,
      'maxX': instance.maxX,
      'maxY': instance.maxY,
      'maxZ': instance.maxZ,
    };
