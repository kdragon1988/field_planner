import 'package:json_annotation/json_annotation.dart';

part 'layer.g.dart';

/// レイヤータイプ
enum LayerType {
  basemap('ベースマップ'),
  pointCloud('点群'),
  mesh('メッシュ'),
  terrain('地形'),
  placements('配置'),
  measurements('計測'),
  annotations('注釈');

  final String displayName;
  const LayerType(this.displayName);
}

/// レイヤーのカラーモード（点群用）
enum ColorMode {
  rgb('RGB'),
  intensity('強度'),
  classification('分類'),
  height('高さ'),
  solid('単色');

  final String displayName;
  const ColorMode(this.displayName);
}

/// レイヤー
@JsonSerializable()
class Layer {
  /// ID
  final String id;

  /// レイヤー名
  final String name;

  /// タイプ
  final LayerType type;

  /// 表示フラグ
  final bool visible;

  /// 不透明度（0.0〜1.0）
  final double opacity;

  /// 表示順序
  final int order;

  /// ロック状態
  final bool locked;

  /// ソースパス（3D Tilesのパス）
  final String? sourcePath;

  /// 元ファイルパス
  final String? originalPath;

  /// スタイル設定
  final LayerStyle? style;

  /// メタデータ
  final Map<String, dynamic>? metadata;

  /// 子レイヤー
  final List<Layer>? children;

  const Layer({
    required this.id,
    required this.name,
    required this.type,
    this.visible = true,
    this.opacity = 1.0,
    this.order = 0,
    this.locked = false,
    this.sourcePath,
    this.originalPath,
    this.style,
    this.metadata,
    this.children,
  });

  factory Layer.fromJson(Map<String, dynamic> json) => _$LayerFromJson(json);

  Map<String, dynamic> toJson() => _$LayerToJson(this);

  Layer copyWith({
    String? id,
    String? name,
    LayerType? type,
    bool? visible,
    double? opacity,
    int? order,
    bool? locked,
    String? sourcePath,
    String? originalPath,
    LayerStyle? style,
    Map<String, dynamic>? metadata,
    List<Layer>? children,
  }) {
    return Layer(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      order: order ?? this.order,
      locked: locked ?? this.locked,
      sourcePath: sourcePath ?? this.sourcePath,
      originalPath: originalPath ?? this.originalPath,
      style: style ?? this.style,
      metadata: metadata ?? this.metadata,
      children: children ?? this.children,
    );
  }
}

/// レイヤースタイル
@JsonSerializable()
class LayerStyle {
  /// 点サイズ（点群用）
  final double pointSize;

  /// カラーモード（点群用）
  final ColorMode colorMode;

  /// 単色（colorMode == solid の場合）
  final String solidColor;

  /// ワイヤーフレーム表示
  final bool wireframe;

  /// 両面レンダリング
  final bool doubleSided;

  const LayerStyle({
    this.pointSize = 2.0,
    this.colorMode = ColorMode.rgb,
    this.solidColor = '#FFFFFF',
    this.wireframe = false,
    this.doubleSided = false,
  });

  factory LayerStyle.fromJson(Map<String, dynamic> json) =>
      _$LayerStyleFromJson(json);

  Map<String, dynamic> toJson() => _$LayerStyleToJson(this);

  LayerStyle copyWith({
    double? pointSize,
    ColorMode? colorMode,
    String? solidColor,
    bool? wireframe,
    bool? doubleSided,
  }) {
    return LayerStyle(
      pointSize: pointSize ?? this.pointSize,
      colorMode: colorMode ?? this.colorMode,
      solidColor: solidColor ?? this.solidColor,
      wireframe: wireframe ?? this.wireframe,
      doubleSided: doubleSided ?? this.doubleSided,
    );
  }
}
