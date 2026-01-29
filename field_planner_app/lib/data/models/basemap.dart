import 'package:json_annotation/json_annotation.dart';

part 'basemap.g.dart';

/// ベースマッププロバイダの種類
enum BaseMapProvider {
  /// Google Maps 衛星画像
  googleSatellite('Google Maps 衛星'),

  /// Google Maps ロードマップ
  googleRoad('Google Maps 地図'),

  /// OpenStreetMap
  osm('OpenStreetMap'),

  /// Cesium Ion（デフォルト）
  cesiumIon('Cesium Ion'),

  /// Bing Maps
  bing('Bing Maps'),

  /// ESRI World Imagery
  esriWorld('ESRI World Imagery'),

  /// ESRI National Geographic
  esriNatGeo('ESRI National Geographic'),

  /// Google Maps（後方互換性）
  google('Google Maps'),

  /// カスタムタイルURL
  custom('カスタム');

  final String displayName;
  const BaseMapProvider(this.displayName);
}

/// ベースマップレイヤー設定
@JsonSerializable()
class BaseMapLayerConfig {
  /// ID
  final String id;

  /// プロバイダ
  final BaseMapProvider provider;

  /// 表示フラグ
  final bool visible;

  /// 不透明度（0.0〜1.0）
  final double opacity;

  /// 表示順序
  final int order;

  /// カスタムタイルURL（providerがcustomの場合に使用）
  final String? customUrl;

  /// APIキー識別子（必要なプロバイダのみ）
  final String? apiKeyId;

  const BaseMapLayerConfig({
    required this.id,
    required this.provider,
    this.visible = true,
    this.opacity = 1.0,
    this.order = 0,
    this.customUrl,
    this.apiKeyId,
  });

  factory BaseMapLayerConfig.fromJson(Map<String, dynamic> json) =>
      _$BaseMapLayerConfigFromJson(json);

  Map<String, dynamic> toJson() => _$BaseMapLayerConfigToJson(this);

  /// プロバイダがAPIキーを必要とするか
  bool get requiresApiKey {
    return provider == BaseMapProvider.bing ||
        provider == BaseMapProvider.google ||
        provider == BaseMapProvider.cesiumIon;
  }

  BaseMapLayerConfig copyWith({
    String? id,
    BaseMapProvider? provider,
    bool? visible,
    double? opacity,
    int? order,
    String? customUrl,
    String? apiKeyId,
  }) {
    return BaseMapLayerConfig(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      order: order ?? this.order,
      customUrl: customUrl ?? this.customUrl,
      apiKeyId: apiKeyId ?? this.apiKeyId,
    );
  }
}

/// 利用可能なベースマップ定義
class AvailableBaseMaps {
  static const osm = BaseMapLayerConfig(
    id: 'osm_standard',
    provider: BaseMapProvider.osm,
  );

  static const esriWorld = BaseMapLayerConfig(
    id: 'esri_world_imagery',
    provider: BaseMapProvider.esriWorld,
  );

  static const esriNatGeo = BaseMapLayerConfig(
    id: 'esri_natgeo',
    provider: BaseMapProvider.esriNatGeo,
  );

  static List<BaseMapLayerConfig> get all => [
        osm,
        esriWorld,
        esriNatGeo,
      ];
}
