// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geo_position.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeoPosition _$GeoPositionFromJson(Map<String, dynamic> json) => GeoPosition(
  longitude: (json['longitude'] as num).toDouble(),
  latitude: (json['latitude'] as num).toDouble(),
  height: (json['height'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$GeoPositionToJson(GeoPosition instance) =>
    <String, dynamic>{
      'longitude': instance.longitude,
      'latitude': instance.latitude,
      'height': instance.height,
    };

CameraPosition _$CameraPositionFromJson(Map<String, dynamic> json) =>
    CameraPosition(
      longitude: (json['longitude'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble() ?? 0,
      pitch: (json['pitch'] as num?)?.toDouble() ?? -45,
      roll: (json['roll'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$CameraPositionToJson(CameraPosition instance) =>
    <String, dynamic>{
      'longitude': instance.longitude,
      'latitude': instance.latitude,
      'height': instance.height,
      'heading': instance.heading,
      'pitch': instance.pitch,
      'roll': instance.roll,
    };
