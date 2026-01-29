import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

import 'geo_position.dart';

part 'project.g.dart';

/// プロジェクトデータモデル
///
/// プロジェクトの全体設定とメタ情報を保持する
@JsonSerializable()
class Project {
  /// スキーマバージョン
  final String schemaVersion;

  /// プロジェクトID（UUID）
  final String id;

  /// プロジェクト名
  final String name;

  /// 説明
  final String? description;

  /// 作成者
  final String? author;

  /// タグ
  final List<String> tags;

  /// 作成日時
  final DateTime createdAt;

  /// 更新日時
  final DateTime updatedAt;

  /// ベースマップ設定
  final BaseMapConfig? baseMap;

  /// シーン設定
  final SceneConfig? scene;

  /// データレイヤー一覧
  final List<DataLayer> dataLayers;

  /// 単位設定
  final UnitsConfig units;

  /// 座標系設定
  final CoordinateConfig? coordinate;

  /// 編集設定
  final EditorSettings settings;

  const Project({
    this.schemaVersion = '1.0.0',
    required this.id,
    required this.name,
    this.description,
    this.author,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.baseMap,
    this.scene,
    this.dataLayers = const [],
    this.units = const UnitsConfig(),
    this.coordinate,
    this.settings = const EditorSettings(),
  });

  /// JSONからProjectを生成
  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

  /// ProjectをJSONに変換
  Map<String, dynamic> toJson() => _$ProjectToJson(this);

  /// 新規プロジェクトを作成
  factory Project.create({
    required String name,
    String? description,
    String? author,
    GeoPosition? center,
  }) {
    final now = DateTime.now();
    return Project(
      id: const Uuid().v4(),
      name: name,
      description: description,
      author: author,
      createdAt: now,
      updatedAt: now,
      scene: SceneConfig(
        center: center ?? GeoPosition.tokyo,
      ),
      baseMap: const BaseMapConfig(provider: 'osm'),
    );
  }

  /// コピーして新しいインスタンスを作成
  Project copyWith({
    String? schemaVersion,
    String? id,
    String? name,
    String? description,
    String? author,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    BaseMapConfig? baseMap,
    SceneConfig? scene,
    List<DataLayer>? dataLayers,
    UnitsConfig? units,
    CoordinateConfig? coordinate,
    EditorSettings? settings,
  }) {
    return Project(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      author: author ?? this.author,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      baseMap: baseMap ?? this.baseMap,
      scene: scene ?? this.scene,
      dataLayers: dataLayers ?? this.dataLayers,
      units: units ?? this.units,
      coordinate: coordinate ?? this.coordinate,
      settings: settings ?? this.settings,
    );
  }
}

/// ベースマップ設定
@JsonSerializable()
class BaseMapConfig {
  /// プロバイダ名
  final String provider;

  /// カスタムタイルURL
  final String? customUrl;

  /// 不透明度
  final double opacity;

  const BaseMapConfig({
    this.provider = 'osm',
    this.customUrl,
    this.opacity = 1.0,
  });

  factory BaseMapConfig.fromJson(Map<String, dynamic> json) =>
      _$BaseMapConfigFromJson(json);

  Map<String, dynamic> toJson() => _$BaseMapConfigToJson(this);

  BaseMapConfig copyWith({
    String? provider,
    String? customUrl,
    double? opacity,
  }) {
    return BaseMapConfig(
      provider: provider ?? this.provider,
      customUrl: customUrl ?? this.customUrl,
      opacity: opacity ?? this.opacity,
    );
  }
}

/// シーン設定
@JsonSerializable()
class SceneConfig {
  /// 中心位置
  final GeoPosition? center;

  /// カメラ設定
  final CameraConfig? camera;

  /// 地形プロバイダ
  final String terrain;

  const SceneConfig({
    this.center,
    this.camera,
    this.terrain = 'cesium_world',
  });

  factory SceneConfig.fromJson(Map<String, dynamic> json) =>
      _$SceneConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SceneConfigToJson(this);

  SceneConfig copyWith({
    GeoPosition? center,
    CameraConfig? camera,
    String? terrain,
  }) {
    return SceneConfig(
      center: center ?? this.center,
      camera: camera ?? this.camera,
      terrain: terrain ?? this.terrain,
    );
  }
}

/// カメラ設定
@JsonSerializable()
class CameraConfig {
  /// 方位角
  final double heading;

  /// ピッチ
  final double pitch;

  /// ロール
  final double roll;

  const CameraConfig({
    this.heading = 0,
    this.pitch = -45,
    this.roll = 0,
  });

  factory CameraConfig.fromJson(Map<String, dynamic> json) =>
      _$CameraConfigFromJson(json);

  Map<String, dynamic> toJson() => _$CameraConfigToJson(this);
}

/// データレイヤー
@JsonSerializable()
class DataLayer {
  /// ID
  final String id;

  /// レイヤー名
  final String name;

  /// タイプ
  final String type;

  /// パス
  final String path;

  /// 表示フラグ
  final bool visible;

  /// 不透明度
  final double opacity;

  /// 順序
  final int order;

  /// ロック
  final bool locked;

  /// 元ファイルパス
  final String? sourcePath;

  /// 元ファイル形式
  final String? sourceFormat;

  const DataLayer({
    required this.id,
    required this.name,
    required this.type,
    required this.path,
    this.visible = true,
    this.opacity = 1.0,
    this.order = 0,
    this.locked = false,
    this.sourcePath,
    this.sourceFormat,
  });

  factory DataLayer.fromJson(Map<String, dynamic> json) =>
      _$DataLayerFromJson(json);

  Map<String, dynamic> toJson() => _$DataLayerToJson(this);

  DataLayer copyWith({
    String? id,
    String? name,
    String? type,
    String? path,
    bool? visible,
    double? opacity,
    int? order,
    bool? locked,
    String? sourcePath,
    String? sourceFormat,
  }) {
    return DataLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      path: path ?? this.path,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      order: order ?? this.order,
      locked: locked ?? this.locked,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceFormat: sourceFormat ?? this.sourceFormat,
    );
  }
}

/// 単位設定
@JsonSerializable()
class UnitsConfig {
  /// 長さの単位
  final String length;

  /// 面積の単位
  final String area;

  const UnitsConfig({
    this.length = 'm',
    this.area = 'm2',
  });

  factory UnitsConfig.fromJson(Map<String, dynamic> json) =>
      _$UnitsConfigFromJson(json);

  Map<String, dynamic> toJson() => _$UnitsConfigToJson(this);
}

/// 座標系設定
@JsonSerializable()
class CoordinateConfig {
  /// EPSG
  final int epsg;

  /// ローカルオフセット
  final Offset3D localOffset;

  const CoordinateConfig({
    this.epsg = 4326,
    this.localOffset = const Offset3D(),
  });

  factory CoordinateConfig.fromJson(Map<String, dynamic> json) =>
      _$CoordinateConfigFromJson(json);

  Map<String, dynamic> toJson() => _$CoordinateConfigToJson(this);
}

/// 3Dオフセット
@JsonSerializable()
class Offset3D {
  final double x;
  final double y;
  final double z;

  const Offset3D({
    this.x = 0,
    this.y = 0,
    this.z = 0,
  });

  factory Offset3D.fromJson(Map<String, dynamic> json) =>
      _$Offset3DFromJson(json);

  Map<String, dynamic> toJson() => _$Offset3DToJson(this);
}

/// 編集設定
@JsonSerializable()
class EditorSettings {
  /// グリッドサイズ
  final double gridSize;

  /// スナップ有効
  final bool snapEnabled;

  /// スナップ角度
  final double snapAngle;

  const EditorSettings({
    this.gridSize = 1.0,
    this.snapEnabled = true,
    this.snapAngle = 15,
  });

  factory EditorSettings.fromJson(Map<String, dynamic> json) =>
      _$EditorSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$EditorSettingsToJson(this);
}
