import 'package:json_annotation/json_annotation.dart';

import 'geo_position.dart';

part 'placement.g.dart';

/// 配置オブジェクト
@JsonSerializable()
class Placement {
  /// ID
  final String id;

  /// アセットID
  final String assetId;

  /// 表示名
  final String name;

  /// 位置
  final GeoPosition position;

  /// 回転（度）
  final PlacementRotation rotation;

  /// スケール
  final PlacementScale scale;

  /// 表示フラグ
  final bool visible;

  /// ロック状態
  final bool locked;

  /// グループID
  final String? groupId;

  /// タグ
  final List<String> tags;

  /// カスタムプロパティ
  final Map<String, dynamic>? properties;

  /// 作成日時
  final DateTime createdAt;

  /// 更新日時
  final DateTime updatedAt;

  const Placement({
    required this.id,
    required this.assetId,
    required this.name,
    required this.position,
    this.rotation = const PlacementRotation(),
    this.scale = const PlacementScale(),
    this.visible = true,
    this.locked = false,
    this.groupId,
    this.tags = const [],
    this.properties,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Placement.fromJson(Map<String, dynamic> json) =>
      _$PlacementFromJson(json);

  Map<String, dynamic> toJson() => _$PlacementToJson(this);

  Placement copyWith({
    String? id,
    String? assetId,
    String? name,
    GeoPosition? position,
    PlacementRotation? rotation,
    PlacementScale? scale,
    bool? visible,
    bool? locked,
    String? groupId,
    List<String>? tags,
    Map<String, dynamic>? properties,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Placement(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      name: name ?? this.name,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      groupId: groupId ?? this.groupId,
      tags: tags ?? this.tags,
      properties: properties ?? this.properties,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 回転（オイラー角、度）
@JsonSerializable()
class PlacementRotation {
  /// ピッチ
  final double pitch;

  /// ロール
  final double roll;

  /// ヘディング（方位角）
  final double heading;

  const PlacementRotation({
    this.pitch = 0,
    this.roll = 0,
    this.heading = 0,
  });

  factory PlacementRotation.fromJson(Map<String, dynamic> json) =>
      _$PlacementRotationFromJson(json);

  Map<String, dynamic> toJson() => _$PlacementRotationToJson(this);

  PlacementRotation copyWith({
    double? pitch,
    double? roll,
    double? heading,
  }) {
    return PlacementRotation(
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
      heading: heading ?? this.heading,
    );
  }
}

/// スケール
@JsonSerializable()
class PlacementScale {
  /// X方向
  final double x;

  /// Y方向
  final double y;

  /// Z方向
  final double z;

  const PlacementScale({
    this.x = 1.0,
    this.y = 1.0,
    this.z = 1.0,
  });

  factory PlacementScale.fromJson(Map<String, dynamic> json) =>
      _$PlacementScaleFromJson(json);

  Map<String, dynamic> toJson() => _$PlacementScaleToJson(this);

  /// 等方スケール
  factory PlacementScale.uniform(double scale) => PlacementScale(
        x: scale,
        y: scale,
        z: scale,
      );

  PlacementScale copyWith({
    double? x,
    double? y,
    double? z,
  }) {
    return PlacementScale(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
    );
  }
}

/// 配置グループ
@JsonSerializable()
class PlacementGroup {
  /// ID
  final String id;

  /// グループ名
  final String name;

  /// 色
  final String color;

  /// 表示フラグ
  final bool visible;

  /// ロック状態
  final bool locked;

  const PlacementGroup({
    required this.id,
    required this.name,
    this.color = '#4CAF50',
    this.visible = true,
    this.locked = false,
  });

  factory PlacementGroup.fromJson(Map<String, dynamic> json) =>
      _$PlacementGroupFromJson(json);

  Map<String, dynamic> toJson() => _$PlacementGroupToJson(this);
}
