// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'basemap.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaseMapLayerConfig _$BaseMapLayerConfigFromJson(Map<String, dynamic> json) =>
    BaseMapLayerConfig(
      id: json['id'] as String,
      provider: $enumDecode(_$BaseMapProviderEnumMap, json['provider']),
      visible: json['visible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      order: (json['order'] as num?)?.toInt() ?? 0,
      customUrl: json['customUrl'] as String?,
      apiKeyId: json['apiKeyId'] as String?,
    );

Map<String, dynamic> _$BaseMapLayerConfigToJson(BaseMapLayerConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'provider': _$BaseMapProviderEnumMap[instance.provider]!,
      'visible': instance.visible,
      'opacity': instance.opacity,
      'order': instance.order,
      'customUrl': instance.customUrl,
      'apiKeyId': instance.apiKeyId,
    };

const _$BaseMapProviderEnumMap = {
  BaseMapProvider.googleSatellite: 'googleSatellite',
  BaseMapProvider.googleRoad: 'googleRoad',
  BaseMapProvider.osm: 'osm',
  BaseMapProvider.cesiumIon: 'cesiumIon',
  BaseMapProvider.bing: 'bing',
  BaseMapProvider.esriWorld: 'esriWorld',
  BaseMapProvider.esriNatGeo: 'esriNatGeo',
  BaseMapProvider.google: 'google',
  BaseMapProvider.custom: 'custom',
};
