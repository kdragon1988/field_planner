import 'package:json_annotation/json_annotation.dart';

import 'geo_position.dart';

part 'measurement.g.dart';

/// 計測タイプ
enum MeasurementType {
  distance('距離', 'm'),
  area('面積', 'm²'),
  height('高さ', 'm'),
  angle('角度', '°');

  final String displayName;
  final String unit;
  const MeasurementType(this.displayName, this.unit);
}

/// 計測データ
@JsonSerializable()
class Measurement {
  /// ID
  final String id;

  /// 計測タイプ
  final MeasurementType type;

  /// 名前
  final String name;

  /// 計測点
  final List<GeoPosition> points;

  /// 計測値
  final double? value;

  /// 単位
  final String unit;

  /// 線の色（HEX）
  final String color;

  /// 線の太さ
  final double lineWidth;

  /// 表示フラグ
  final bool visible;

  /// メモ
  final String? note;

  /// 作成日時
  final DateTime createdAt;

  const Measurement({
    required this.id,
    required this.type,
    required this.name,
    required this.points,
    this.value,
    this.unit = 'm',
    this.color = '#FF0000',
    this.lineWidth = 2.0,
    this.visible = true,
    this.note,
    required this.createdAt,
  });

  factory Measurement.fromJson(Map<String, dynamic> json) =>
      _$MeasurementFromJson(json);

  Map<String, dynamic> toJson() => _$MeasurementToJson(this);

  /// 計測値のフォーマット済み文字列
  String get formattedValue {
    if (value == null) return '-';
    switch (type) {
      case MeasurementType.distance:
        if (value! >= 1000) {
          return '${(value! / 1000).toStringAsFixed(2)} km';
        }
        return '${value!.toStringAsFixed(2)} m';
      case MeasurementType.area:
        if (value! >= 10000) {
          return '${(value! / 10000).toStringAsFixed(2)} ha';
        }
        return '${value!.toStringAsFixed(2)} m²';
      case MeasurementType.height:
        return '${value!.toStringAsFixed(2)} m';
      case MeasurementType.angle:
        return '${value!.toStringAsFixed(1)}°';
    }
  }

  Measurement copyWith({
    String? id,
    MeasurementType? type,
    String? name,
    List<GeoPosition>? points,
    double? value,
    String? unit,
    String? color,
    double? lineWidth,
    bool? visible,
    String? note,
    DateTime? createdAt,
  }) {
    return Measurement(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      points: points ?? this.points,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      visible: visible ?? this.visible,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 計測スタイル
class MeasurementStyle {
  /// 線の色
  final String lineColor;

  /// 線の太さ
  final double lineWidth;

  /// 塗りつぶし透明度
  final double fillOpacity;

  /// ラベルを表示
  final bool showLabel;

  const MeasurementStyle({
    this.lineColor = '#FF0000',
    this.lineWidth = 2.0,
    this.fillOpacity = 0.3,
    this.showLabel = true,
  });
}
