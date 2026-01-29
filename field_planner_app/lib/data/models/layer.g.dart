// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'layer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Layer _$LayerFromJson(Map<String, dynamic> json) => Layer(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$LayerTypeEnumMap, json['type']),
  visible: json['visible'] as bool? ?? true,
  opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
  order: (json['order'] as num?)?.toInt() ?? 0,
  locked: json['locked'] as bool? ?? false,
  sourcePath: json['sourcePath'] as String?,
  originalPath: json['originalPath'] as String?,
  style: json['style'] == null
      ? null
      : LayerStyle.fromJson(json['style'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  children: (json['children'] as List<dynamic>?)
      ?.map((e) => Layer.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LayerToJson(Layer instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$LayerTypeEnumMap[instance.type]!,
  'visible': instance.visible,
  'opacity': instance.opacity,
  'order': instance.order,
  'locked': instance.locked,
  'sourcePath': instance.sourcePath,
  'originalPath': instance.originalPath,
  'style': instance.style,
  'metadata': instance.metadata,
  'children': instance.children,
};

const _$LayerTypeEnumMap = {
  LayerType.basemap: 'basemap',
  LayerType.pointCloud: 'pointCloud',
  LayerType.mesh: 'mesh',
  LayerType.terrain: 'terrain',
  LayerType.placements: 'placements',
  LayerType.measurements: 'measurements',
  LayerType.annotations: 'annotations',
};

LayerStyle _$LayerStyleFromJson(Map<String, dynamic> json) => LayerStyle(
  pointSize: (json['pointSize'] as num?)?.toDouble() ?? 2.0,
  colorMode:
      $enumDecodeNullable(_$ColorModeEnumMap, json['colorMode']) ??
      ColorMode.rgb,
  solidColor: json['solidColor'] as String? ?? '#FFFFFF',
  wireframe: json['wireframe'] as bool? ?? false,
  doubleSided: json['doubleSided'] as bool? ?? false,
);

Map<String, dynamic> _$LayerStyleToJson(LayerStyle instance) =>
    <String, dynamic>{
      'pointSize': instance.pointSize,
      'colorMode': _$ColorModeEnumMap[instance.colorMode]!,
      'solidColor': instance.solidColor,
      'wireframe': instance.wireframe,
      'doubleSided': instance.doubleSided,
    };

const _$ColorModeEnumMap = {
  ColorMode.rgb: 'rgb',
  ColorMode.intensity: 'intensity',
  ColorMode.classification: 'classification',
  ColorMode.height: 'height',
  ColorMode.solid: 'solid',
};
