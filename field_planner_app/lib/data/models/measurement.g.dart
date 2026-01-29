// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Measurement _$MeasurementFromJson(Map<String, dynamic> json) => Measurement(
  id: json['id'] as String,
  type: $enumDecode(_$MeasurementTypeEnumMap, json['type']),
  name: json['name'] as String,
  points: (json['points'] as List<dynamic>)
      .map((e) => GeoPosition.fromJson(e as Map<String, dynamic>))
      .toList(),
  value: (json['value'] as num?)?.toDouble(),
  unit: json['unit'] as String? ?? 'm',
  color: json['color'] as String? ?? '#FF0000',
  lineWidth: (json['lineWidth'] as num?)?.toDouble() ?? 2.0,
  visible: json['visible'] as bool? ?? true,
  note: json['note'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$MeasurementToJson(Measurement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$MeasurementTypeEnumMap[instance.type]!,
      'name': instance.name,
      'points': instance.points,
      'value': instance.value,
      'unit': instance.unit,
      'color': instance.color,
      'lineWidth': instance.lineWidth,
      'visible': instance.visible,
      'note': instance.note,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$MeasurementTypeEnumMap = {
  MeasurementType.distance: 'distance',
  MeasurementType.area: 'area',
  MeasurementType.height: 'height',
  MeasurementType.angle: 'angle',
};
