// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drone_formation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DroneFormation _$DroneFormationFromJson(Map<String, dynamic> json) =>
    DroneFormation(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      drones: (json['drones'] as List<dynamic>)
          .map((e) => DronePosition.fromJson(e as Map<String, dynamic>))
          .toList(),
      sourceFileName: json['sourceFileName'] as String?,
      importedAt: DateTime.parse(json['importedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DroneFormationToJson(DroneFormation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'drones': instance.drones,
      'sourceFileName': instance.sourceFileName,
      'importedAt': instance.importedAt.toIso8601String(),
      'metadata': instance.metadata,
    };

DronePosition _$DronePositionFromJson(Map<String, dynamic> json) =>
    DronePosition(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      r: (json['r'] as num?)?.toInt() ?? 255,
      g: (json['g'] as num?)?.toInt() ?? 255,
      b: (json['b'] as num?)?.toInt() ?? 255,
      a: (json['a'] as num?)?.toInt() ?? 255,
      detectionSource: json['detectionSource'] as String?,
    );

Map<String, dynamic> _$DronePositionToJson(DronePosition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'x': instance.x,
      'y': instance.y,
      'r': instance.r,
      'g': instance.g,
      'b': instance.b,
      'a': instance.a,
      'detectionSource': instance.detectionSource,
    };

PlacedDroneFormation _$PlacedDroneFormationFromJson(
  Map<String, dynamic> json,
) => PlacedDroneFormation(
  id: json['id'] as String,
  formationId: json['formationId'] as String,
  name: json['name'] as String,
  baseLongitude: (json['baseLongitude'] as num).toDouble(),
  baseLatitude: (json['baseLatitude'] as num).toDouble(),
  altitude: (json['altitude'] as num?)?.toDouble() ?? 50.0,
  heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
  tilt: (json['tilt'] as num?)?.toDouble() ?? 0.0,
  scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
  pointSize: (json['pointSize'] as num?)?.toDouble() ?? 5.0,
  glowIntensity: (json['glowIntensity'] as num?)?.toDouble() ?? 1.0,
  customColor: json['customColor'] as String?,
  useIndividualColors: json['useIndividualColors'] as bool? ?? true,
  visible: json['visible'] as bool? ?? true,
  locked: json['locked'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$PlacedDroneFormationToJson(
  PlacedDroneFormation instance,
) => <String, dynamic>{
  'id': instance.id,
  'formationId': instance.formationId,
  'name': instance.name,
  'baseLongitude': instance.baseLongitude,
  'baseLatitude': instance.baseLatitude,
  'altitude': instance.altitude,
  'heading': instance.heading,
  'tilt': instance.tilt,
  'scale': instance.scale,
  'pointSize': instance.pointSize,
  'glowIntensity': instance.glowIntensity,
  'customColor': instance.customColor,
  'useIndividualColors': instance.useIndividualColors,
  'visible': instance.visible,
  'locked': instance.locked,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
