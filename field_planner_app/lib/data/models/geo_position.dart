import 'package:json_annotation/json_annotation.dart';

part 'geo_position.g.dart';

/// 地理座標を表すデータクラス
///
/// 経度、緯度、高さを保持し、CesiumJSとの座標データ交換に使用
@JsonSerializable()
class GeoPosition {
  /// 経度（度）
  final double longitude;

  /// 緯度（度）
  final double latitude;

  /// 高さ（メートル）
  final double height;

  const GeoPosition({
    required this.longitude,
    required this.latitude,
    this.height = 0,
  });

  /// JSONからGeoPositionを生成
  factory GeoPosition.fromJson(Map<String, dynamic> json) =>
      _$GeoPositionFromJson(json);

  /// GeoPositionをJSONに変換
  Map<String, dynamic> toJson() => _$GeoPositionToJson(this);

  /// デフォルト位置（東京）
  static const GeoPosition tokyo = GeoPosition(
    longitude: 139.6917,
    latitude: 35.6895,
    height: 1000,
  );

  /// コピーして新しいインスタンスを作成
  GeoPosition copyWith({
    double? longitude,
    double? latitude,
    double? height,
  }) {
    return GeoPosition(
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      height: height ?? this.height,
    );
  }

  @override
  String toString() =>
      'GeoPosition(longitude: $longitude, latitude: $latitude, height: $height)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeoPosition &&
        other.longitude == longitude &&
        other.latitude == latitude &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(longitude, latitude, height);
}

/// カメラ位置を表すデータクラス
///
/// 位置に加えてカメラの向き（heading, pitch, roll）を保持
@JsonSerializable()
class CameraPosition {
  /// 経度（度）
  final double longitude;

  /// 緯度（度）
  final double latitude;

  /// 高さ（メートル）
  final double height;

  /// 方位角（度、北=0、東=90）
  final double heading;

  /// ピッチ（度、水平=0、下向き=-90）
  final double pitch;

  /// ロール（度）
  final double roll;

  const CameraPosition({
    required this.longitude,
    required this.latitude,
    required this.height,
    this.heading = 0,
    this.pitch = -45,
    this.roll = 0,
  });

  /// JSONからCameraPositionを生成
  factory CameraPosition.fromJson(Map<String, dynamic> json) =>
      _$CameraPositionFromJson(json);

  /// CameraPositionをJSONに変換
  Map<String, dynamic> toJson() => _$CameraPositionToJson(this);

  /// GeoPositionを取得
  GeoPosition get geoPosition => GeoPosition(
        longitude: longitude,
        latitude: latitude,
        height: height,
      );

  /// コピーして新しいインスタンスを作成
  CameraPosition copyWith({
    double? longitude,
    double? latitude,
    double? height,
    double? heading,
    double? pitch,
    double? roll,
  }) {
    return CameraPosition(
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      height: height ?? this.height,
      heading: heading ?? this.heading,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
    );
  }

  @override
  String toString() =>
      'CameraPosition(lng: $longitude, lat: $latitude, h: $height, heading: $heading, pitch: $pitch)';
}
