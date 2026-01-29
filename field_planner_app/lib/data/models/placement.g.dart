// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'placement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Placement _$PlacementFromJson(Map<String, dynamic> json) => Placement(
  id: json['id'] as String,
  assetId: json['assetId'] as String,
  name: json['name'] as String,
  position: GeoPosition.fromJson(json['position'] as Map<String, dynamic>),
  rotation: json['rotation'] == null
      ? const PlacementRotation()
      : PlacementRotation.fromJson(json['rotation'] as Map<String, dynamic>),
  scale: json['scale'] == null
      ? const PlacementScale()
      : PlacementScale.fromJson(json['scale'] as Map<String, dynamic>),
  visible: json['visible'] as bool? ?? true,
  locked: json['locked'] as bool? ?? false,
  groupId: json['groupId'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  properties: json['properties'] as Map<String, dynamic>?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$PlacementToJson(Placement instance) => <String, dynamic>{
  'id': instance.id,
  'assetId': instance.assetId,
  'name': instance.name,
  'position': instance.position,
  'rotation': instance.rotation,
  'scale': instance.scale,
  'visible': instance.visible,
  'locked': instance.locked,
  'groupId': instance.groupId,
  'tags': instance.tags,
  'properties': instance.properties,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

PlacementRotation _$PlacementRotationFromJson(Map<String, dynamic> json) =>
    PlacementRotation(
      pitch: (json['pitch'] as num?)?.toDouble() ?? 0,
      roll: (json['roll'] as num?)?.toDouble() ?? 0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$PlacementRotationToJson(PlacementRotation instance) =>
    <String, dynamic>{
      'pitch': instance.pitch,
      'roll': instance.roll,
      'heading': instance.heading,
    };

PlacementScale _$PlacementScaleFromJson(Map<String, dynamic> json) =>
    PlacementScale(
      x: (json['x'] as num?)?.toDouble() ?? 1.0,
      y: (json['y'] as num?)?.toDouble() ?? 1.0,
      z: (json['z'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$PlacementScaleToJson(PlacementScale instance) =>
    <String, dynamic>{'x': instance.x, 'y': instance.y, 'z': instance.z};

PlacementGroup _$PlacementGroupFromJson(Map<String, dynamic> json) =>
    PlacementGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String? ?? '#4CAF50',
      visible: json['visible'] as bool? ?? true,
      locked: json['locked'] as bool? ?? false,
    );

Map<String, dynamic> _$PlacementGroupToJson(PlacementGroup instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'color': instance.color,
      'visible': instance.visible,
      'locked': instance.locked,
    };
