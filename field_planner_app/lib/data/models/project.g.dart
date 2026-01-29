// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Project _$ProjectFromJson(Map<String, dynamic> json) => Project(
  schemaVersion: json['schemaVersion'] as String? ?? '1.0.0',
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  author: json['author'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  baseMap: json['baseMap'] == null
      ? null
      : BaseMapConfig.fromJson(json['baseMap'] as Map<String, dynamic>),
  scene: json['scene'] == null
      ? null
      : SceneConfig.fromJson(json['scene'] as Map<String, dynamic>),
  dataLayers:
      (json['dataLayers'] as List<dynamic>?)
          ?.map((e) => DataLayer.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  units: json['units'] == null
      ? const UnitsConfig()
      : UnitsConfig.fromJson(json['units'] as Map<String, dynamic>),
  coordinate: json['coordinate'] == null
      ? null
      : CoordinateConfig.fromJson(json['coordinate'] as Map<String, dynamic>),
  settings: json['settings'] == null
      ? const EditorSettings()
      : EditorSettings.fromJson(json['settings'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ProjectToJson(Project instance) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'author': instance.author,
  'tags': instance.tags,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'baseMap': instance.baseMap,
  'scene': instance.scene,
  'dataLayers': instance.dataLayers,
  'units': instance.units,
  'coordinate': instance.coordinate,
  'settings': instance.settings,
};

BaseMapConfig _$BaseMapConfigFromJson(Map<String, dynamic> json) =>
    BaseMapConfig(
      provider: json['provider'] as String? ?? 'osm',
      customUrl: json['customUrl'] as String?,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$BaseMapConfigToJson(BaseMapConfig instance) =>
    <String, dynamic>{
      'provider': instance.provider,
      'customUrl': instance.customUrl,
      'opacity': instance.opacity,
    };

SceneConfig _$SceneConfigFromJson(Map<String, dynamic> json) => SceneConfig(
  center: json['center'] == null
      ? null
      : GeoPosition.fromJson(json['center'] as Map<String, dynamic>),
  camera: json['camera'] == null
      ? null
      : CameraConfig.fromJson(json['camera'] as Map<String, dynamic>),
  terrain: json['terrain'] as String? ?? 'cesium_world',
);

Map<String, dynamic> _$SceneConfigToJson(SceneConfig instance) =>
    <String, dynamic>{
      'center': instance.center,
      'camera': instance.camera,
      'terrain': instance.terrain,
    };

CameraConfig _$CameraConfigFromJson(Map<String, dynamic> json) => CameraConfig(
  heading: (json['heading'] as num?)?.toDouble() ?? 0,
  pitch: (json['pitch'] as num?)?.toDouble() ?? -45,
  roll: (json['roll'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$CameraConfigToJson(CameraConfig instance) =>
    <String, dynamic>{
      'heading': instance.heading,
      'pitch': instance.pitch,
      'roll': instance.roll,
    };

DataLayer _$DataLayerFromJson(Map<String, dynamic> json) => DataLayer(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String,
  path: json['path'] as String,
  visible: json['visible'] as bool? ?? true,
  opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
  order: (json['order'] as num?)?.toInt() ?? 0,
  locked: json['locked'] as bool? ?? false,
  sourcePath: json['sourcePath'] as String?,
  sourceFormat: json['sourceFormat'] as String?,
);

Map<String, dynamic> _$DataLayerToJson(DataLayer instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': instance.type,
  'path': instance.path,
  'visible': instance.visible,
  'opacity': instance.opacity,
  'order': instance.order,
  'locked': instance.locked,
  'sourcePath': instance.sourcePath,
  'sourceFormat': instance.sourceFormat,
};

UnitsConfig _$UnitsConfigFromJson(Map<String, dynamic> json) => UnitsConfig(
  length: json['length'] as String? ?? 'm',
  area: json['area'] as String? ?? 'm2',
);

Map<String, dynamic> _$UnitsConfigToJson(UnitsConfig instance) =>
    <String, dynamic>{'length': instance.length, 'area': instance.area};

CoordinateConfig _$CoordinateConfigFromJson(Map<String, dynamic> json) =>
    CoordinateConfig(
      epsg: (json['epsg'] as num?)?.toInt() ?? 4326,
      localOffset: json['localOffset'] == null
          ? const Offset3D()
          : Offset3D.fromJson(json['localOffset'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CoordinateConfigToJson(CoordinateConfig instance) =>
    <String, dynamic>{
      'epsg': instance.epsg,
      'localOffset': instance.localOffset,
    };

Offset3D _$Offset3DFromJson(Map<String, dynamic> json) => Offset3D(
  x: (json['x'] as num?)?.toDouble() ?? 0,
  y: (json['y'] as num?)?.toDouble() ?? 0,
  z: (json['z'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$Offset3DToJson(Offset3D instance) => <String, dynamic>{
  'x': instance.x,
  'y': instance.y,
  'z': instance.z,
};

EditorSettings _$EditorSettingsFromJson(Map<String, dynamic> json) =>
    EditorSettings(
      gridSize: (json['gridSize'] as num?)?.toDouble() ?? 1.0,
      snapEnabled: json['snapEnabled'] as bool? ?? true,
      snapAngle: (json['snapAngle'] as num?)?.toDouble() ?? 15,
    );

Map<String, dynamic> _$EditorSettingsToJson(EditorSettings instance) =>
    <String, dynamic>{
      'gridSize': instance.gridSize,
      'snapEnabled': instance.snapEnabled,
      'snapAngle': instance.snapAngle,
    };
