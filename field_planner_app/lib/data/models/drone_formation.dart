/// ドローンフォーメーションデータモデル
/// 
/// ドローンショーのレイアウトデータを表現するモデル。
/// JSONファイルからインポートされた機体位置・色情報を保持し、
/// CesiumJS上でポイント群として表示する。
/// 
/// 主な仕様:
/// - x, y座標は相対座標（メートル単位）
/// - 配置時に基準点（GeoPosition）と高さを指定して絶対座標に変換
/// - r, g, b, aはLEDの色情報（0-255）
/// 
/// 制限事項:
/// - JSONファイルにz座標がない場合は配置時にユーザーが高さを指定
/// - 大量のドローン（数千機）の場合はパフォーマンスに注意

import 'package:json_annotation/json_annotation.dart';

part 'drone_formation.g.dart';

/// ドローンフォーメーション
/// 
/// 複数のドローン位置情報をまとめて管理するコンテナ
@JsonSerializable()
class DroneFormation {
  /// 一意識別子
  final String id;

  /// フォーメーション名
  final String name;

  /// 説明
  final String? description;

  /// ドローン位置リスト
  final List<DronePosition> drones;

  /// インポート元ファイル名
  final String? sourceFileName;

  /// インポート日時
  final DateTime importedAt;

  /// メタデータ（任意の追加情報）
  final Map<String, dynamic>? metadata;

  const DroneFormation({
    required this.id,
    required this.name,
    this.description,
    required this.drones,
    this.sourceFileName,
    required this.importedAt,
    this.metadata,
  });

  /// JSONからDroneFormationを生成
  factory DroneFormation.fromJson(Map<String, dynamic> json) =>
      _$DroneFormationFromJson(json);

  /// DroneFormationをJSONに変換
  Map<String, dynamic> toJson() => _$DroneFormationToJson(this);

  /// ドローン機数を取得
  int get droneCount => drones.length;

  /// X座標の範囲を取得（メートル）
  ({double min, double max}) get xRange {
    if (drones.isEmpty) return (min: 0, max: 0);
    double minX = drones.first.x;
    double maxX = drones.first.x;
    for (final drone in drones) {
      if (drone.x < minX) minX = drone.x;
      if (drone.x > maxX) maxX = drone.x;
    }
    return (min: minX, max: maxX);
  }

  /// Y座標の範囲を取得（メートル）
  ({double min, double max}) get yRange {
    if (drones.isEmpty) return (min: 0, max: 0);
    double minY = drones.first.y;
    double maxY = drones.first.y;
    for (final drone in drones) {
      if (drone.y < minY) minY = drone.y;
      if (drone.y > maxY) maxY = drone.y;
    }
    return (min: minY, max: maxY);
  }

  /// フォーメーションの幅を取得（メートル）
  double get width {
    final range = xRange;
    return range.max - range.min;
  }

  /// フォーメーションの奥行きを取得（メートル）
  double get depth {
    final range = yRange;
    return range.max - range.min;
  }

  /// フォーメーションの中心X座標を取得（メートル）
  double get centerX {
    final range = xRange;
    return (range.min + range.max) / 2;
  }

  /// フォーメーションの中心Y座標を取得（メートル）
  double get centerY {
    final range = yRange;
    return (range.min + range.max) / 2;
  }

  /// コピーして新しいインスタンスを作成
  DroneFormation copyWith({
    String? id,
    String? name,
    String? description,
    List<DronePosition>? drones,
    String? sourceFileName,
    DateTime? importedAt,
    Map<String, dynamic>? metadata,
  }) {
    return DroneFormation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      drones: drones ?? this.drones,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      importedAt: importedAt ?? this.importedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'DroneFormation(id: $id, name: $name, droneCount: $droneCount)';
}

/// 個別ドローンの位置・色情報
/// 
/// JSONからインポートされた単一ドローンのデータを表現
@JsonSerializable()
class DronePosition {
  /// ドローンID（JSON内のid）
  final String id;

  /// 相対X座標（メートル）
  final double x;

  /// 相対Y座標（メートル）
  final double y;

  /// LED赤色成分（0-255）
  final int r;

  /// LED緑色成分（0-255）
  final int g;

  /// LED青色成分（0-255）
  final int b;

  /// LED透明度（0-255）
  final int a;

  /// 検出ソース（オプション）
  final String? detectionSource;

  const DronePosition({
    required this.id,
    required this.x,
    required this.y,
    this.r = 255,
    this.g = 255,
    this.b = 255,
    this.a = 255,
    this.detectionSource,
  });

  /// JSONからDronePositionを生成
  factory DronePosition.fromJson(Map<String, dynamic> json) =>
      _$DronePositionFromJson(json);

  /// DronePositionをJSONに変換
  Map<String, dynamic> toJson() => _$DronePositionToJson(this);

  /// LED色を16進数文字列で取得（例: "#FF0000"）
  String get colorHex {
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  /// LED色をRGBA文字列で取得（例: "rgba(255, 0, 0, 0.5)"）
  String get colorRgba {
    final alpha = a / 255;
    return 'rgba($r, $g, $b, ${alpha.toStringAsFixed(2)})';
  }

  /// コピーして新しいインスタンスを作成
  DronePosition copyWith({
    String? id,
    double? x,
    double? y,
    int? r,
    int? g,
    int? b,
    int? a,
    String? detectionSource,
  }) {
    return DronePosition(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      r: r ?? this.r,
      g: g ?? this.g,
      b: b ?? this.b,
      a: a ?? this.a,
      detectionSource: detectionSource ?? this.detectionSource,
    );
  }

  @override
  String toString() => 'DronePosition(id: $id, x: $x, y: $y, color: $colorHex)';
}

/// 配置済みドローンフォーメーション
/// 
/// DroneFormationを地図上の特定位置に配置したインスタンス
@JsonSerializable()
class PlacedDroneFormation {
  /// 一意識別子
  final String id;

  /// 元のフォーメーションID
  final String formationId;

  /// 表示名
  final String name;

  /// 基準点の経度
  final double baseLongitude;

  /// 基準点の緯度
  final double baseLatitude;

  /// 高度（メートル）
  final double altitude;

  /// 方位角（度、北=0、東=90）
  final double heading;

  /// チルト（度、前後回転、-180〜180）
  final double tilt;

  /// スケール倍率
  final double scale;

  /// ポイントサイズ（ピクセル）
  final double pointSize;

  /// 輝度（発光の濃さ、0.2〜2.0）
  final double glowIntensity;

  /// カスタム色（nullの場合は各ドローンの色を使用）
  final String? customColor;

  /// 個別色を使用するかどうか
  final bool useIndividualColors;

  /// 表示フラグ
  final bool visible;

  /// ロック状態
  final bool locked;

  /// 作成日時
  final DateTime createdAt;

  /// 更新日時
  final DateTime updatedAt;

  const PlacedDroneFormation({
    required this.id,
    required this.formationId,
    required this.name,
    required this.baseLongitude,
    required this.baseLatitude,
    this.altitude = 50.0,
    this.heading = 0.0,
    this.tilt = 0.0,
    this.scale = 1.0,
    this.pointSize = 5.0,
    this.glowIntensity = 1.0,
    this.customColor,
    this.useIndividualColors = true,
    this.visible = true,
    this.locked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// JSONからPlacedDroneFormationを生成
  factory PlacedDroneFormation.fromJson(Map<String, dynamic> json) =>
      _$PlacedDroneFormationFromJson(json);

  /// PlacedDroneFormationをJSONに変換
  Map<String, dynamic> toJson() => _$PlacedDroneFormationToJson(this);

  /// コピーして新しいインスタンスを作成
  PlacedDroneFormation copyWith({
    String? id,
    String? formationId,
    String? name,
    double? baseLongitude,
    double? baseLatitude,
    double? altitude,
    double? heading,
    double? tilt,
    double? scale,
    double? pointSize,
    double? glowIntensity,
    String? customColor,
    bool? useIndividualColors,
    bool? visible,
    bool? locked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlacedDroneFormation(
      id: id ?? this.id,
      formationId: formationId ?? this.formationId,
      name: name ?? this.name,
      baseLongitude: baseLongitude ?? this.baseLongitude,
      baseLatitude: baseLatitude ?? this.baseLatitude,
      altitude: altitude ?? this.altitude,
      heading: heading ?? this.heading,
      tilt: tilt ?? this.tilt,
      scale: scale ?? this.scale,
      pointSize: pointSize ?? this.pointSize,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      customColor: customColor ?? this.customColor,
      useIndividualColors: useIndividualColors ?? this.useIndividualColors,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'PlacedDroneFormation(id: $id, name: $name, altitude: $altitude)';
}
