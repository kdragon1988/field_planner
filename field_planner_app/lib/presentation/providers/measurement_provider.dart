import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../data/models/measurement.dart';
import '../../data/models/geo_position.dart';
import '../../infrastructure/webview/cesium_controller.dart';
import 'cesium_provider.dart';

/// 計測状態
class MeasurementState {
  /// アクティブな計測モード（null = 計測中ではない）
  final MeasurementType? activeMode;

  /// 一時的な計測ポイント（計測中のみ）
  final List<GeoPosition> tempPoints;

  /// 現在の計測値（計測中のみ）
  final double currentValue;

  /// 現在の単位（計測中のみ）
  final String currentUnit;

  /// 保存済み計測結果一覧
  final List<Measurement> measurements;

  /// 読み込み中フラグ
  final bool isLoading;

  /// 編集中の計測ID（null = 編集中ではない）
  final String? editingMeasurementId;

  const MeasurementState({
    this.activeMode,
    this.tempPoints = const [],
    this.currentValue = 0,
    this.currentUnit = '',
    this.measurements = const [],
    this.isLoading = false,
    this.editingMeasurementId,
  });

  /// 計測中かどうか
  bool get isMeasuring => activeMode != null;

  /// 編集中かどうか
  bool get isEditing => editingMeasurementId != null;

  MeasurementState copyWith({
    MeasurementType? activeMode,
    List<GeoPosition>? tempPoints,
    double? currentValue,
    String? currentUnit,
    List<Measurement>? measurements,
    bool? isLoading,
    String? editingMeasurementId,
    bool clearActiveMode = false,
    bool clearEditingId = false,
  }) {
    return MeasurementState(
      activeMode: clearActiveMode ? null : (activeMode ?? this.activeMode),
      tempPoints: tempPoints ?? this.tempPoints,
      currentValue: currentValue ?? this.currentValue,
      currentUnit: currentUnit ?? this.currentUnit,
      measurements: measurements ?? this.measurements,
      isLoading: isLoading ?? this.isLoading,
      editingMeasurementId: clearEditingId
          ? null
          : (editingMeasurementId ?? this.editingMeasurementId),
    );
  }
}

/// 計測プロバイダー
class MeasurementNotifier extends StateNotifier<MeasurementState> {
  CesiumController? _cesiumController;
  String? _projectPath;

  MeasurementNotifier(this._cesiumController)
      : super(const MeasurementState()) {
    _setupCallbacks();
  }

  /// CesiumControllerを更新してコールバックを設定
  void updateController(CesiumController? controller) {
    _cesiumController = controller;
    _setupCallbacks();
  }

  /// CesiumControllerのコールバックを設定
  void _setupCallbacks() {
    if (_cesiumController == null) return;

    _cesiumController!.onMeasurementModeStarted = _onMeasurementModeStarted;
    _cesiumController!.onMeasurementPointAdded = _onMeasurementPointAdded;
    _cesiumController!.onMeasurementCompleted = _onMeasurementCompleted;
    _cesiumController!.onMeasurementCancelled = _onMeasurementCancelled;
    _cesiumController!.onMeasurementPointMoved = _onMeasurementPointMoved;
    _cesiumController!.onMeasurementPointDeleted = _onMeasurementPointDeleted;
    _cesiumController!.onMeasurementEditModeStarted = _onMeasurementEditModeStarted;
    _cesiumController!.onMeasurementEditModeEnded = _onMeasurementEditModeEnded;
  }

  /// プロジェクトパスを設定
  void setProjectPath(String? projectPath) {
    _projectPath = projectPath;
    if (projectPath != null) {
      loadMeasurements(projectPath);
    }
  }

  // ============================================
  // コールバック
  // ============================================

  void _onMeasurementModeStarted(String type) {
    final measurementType = _typeFromString(type);
    state = state.copyWith(
      activeMode: measurementType,
      tempPoints: [],
      currentValue: 0,
      currentUnit: measurementType?.unit ?? '',
    );
  }

  void _onMeasurementPointAdded(
    List<GeoPosition> points,
    double currentValue,
    String unit,
  ) {
    state = state.copyWith(
      tempPoints: points,
      currentValue: currentValue,
      currentUnit: unit,
    );
  }

  void _onMeasurementCompleted(
    String type,
    List<GeoPosition> points,
    double value,
    String unit,
  ) {
    final measurementType = _typeFromString(type);
    if (measurementType == null) return;

    // 新しい計測を作成
    final measurement = Measurement(
      id: const Uuid().v4(),
      type: measurementType,
      name: '${measurementType.displayName} ${state.measurements.length + 1}',
      points: points,
      value: value,
      unit: unit,
      createdAt: DateTime.now(),
    );

    // 状態を更新
    final newMeasurements = [...state.measurements, measurement];
    state = state.copyWith(
      measurements: newMeasurements,
      clearActiveMode: true,
      tempPoints: [],
      currentValue: 0,
      currentUnit: '',
    );

    // CesiumJSに表示を追加
    _addMeasurementToCesium(measurement);

    // 保存
    if (_projectPath != null) {
      _saveMeasurements();
    }
  }

  void _onMeasurementCancelled() {
    state = state.copyWith(
      clearActiveMode: true,
      tempPoints: [],
      currentValue: 0,
      currentUnit: '',
    );
  }

  void _onMeasurementPointMoved(
    String measurementId,
    int pointIndex,
    GeoPosition newPoint,
  ) {
    final index = state.measurements.indexWhere((m) => m.id == measurementId);
    if (index == -1) return;

    final measurement = state.measurements[index];
    final newPoints = [...measurement.points];
    newPoints[pointIndex] = newPoint;

    // 計測値を再計算
    final newValue = _recalculateMeasurement(measurement.type, newPoints);

    final updatedMeasurement = measurement.copyWith(
      points: newPoints,
      value: newValue,
    );

    final newMeasurements = [...state.measurements];
    newMeasurements[index] = updatedMeasurement;

    state = state.copyWith(measurements: newMeasurements);

    // 表示を更新
    _updateMeasurementInCesium(updatedMeasurement);

    // 保存
    if (_projectPath != null) {
      _saveMeasurements();
    }
  }

  void _onMeasurementPointDeleted(
    String measurementId,
    int pointIndex,
  ) {
    final index = state.measurements.indexWhere((m) => m.id == measurementId);
    if (index == -1) return;

    final measurement = state.measurements[index];
    
    // 最小ポイント数をチェック（距離:2, 面積:3, 高さ:2）
    final minPoints = measurement.type == MeasurementType.area ? 3 : 2;
    if (measurement.points.length <= minPoints) {
      // ポイントが少なすぎる場合は削除しない
      return;
    }

    final newPoints = [...measurement.points];
    newPoints.removeAt(pointIndex);

    // 計測値を再計算
    final newValue = _recalculateMeasurement(measurement.type, newPoints);

    final updatedMeasurement = measurement.copyWith(
      points: newPoints,
      value: newValue,
    );

    final newMeasurements = [...state.measurements];
    newMeasurements[index] = updatedMeasurement;

    state = state.copyWith(measurements: newMeasurements);

    // 表示を更新
    _updateMeasurementInCesium(updatedMeasurement);

    // 編集モードを再開始（ポイントインデックスが変わるため）
    final controller = _cesiumController;
    if (controller != null) {
      controller.endMeasurementEditMode();
      controller.startMeasurementEditMode(measurementId);
    }

    // 保存
    if (_projectPath != null) {
      _saveMeasurements();
    }
  }

  void _onMeasurementEditModeStarted(String measurementId) {
    state = state.copyWith(editingMeasurementId: measurementId);
  }

  void _onMeasurementEditModeEnded(String measurementId) {
    state = state.copyWith(clearEditingId: true);
  }

  // ============================================
  // 公開メソッド
  // ============================================

  /// 計測モードを開始
  Future<void> startMeasurement(MeasurementType type) async {
    final controller = _cesiumController;
    if (controller == null) return;

    // 既存の計測をキャンセル
    if (state.isMeasuring) {
      await cancelMeasurement();
    }

    await controller.startMeasurementMode(type.name);
  }

  /// 計測をキャンセル
  Future<void> cancelMeasurement() async {
    final controller = _cesiumController;
    if (controller == null) return;

    await controller.cancelMeasurement();
    state = state.copyWith(
      clearActiveMode: true,
      tempPoints: [],
      currentValue: 0,
      currentUnit: '',
    );
  }

  /// 計測を削除
  Future<void> deleteMeasurement(String measurementId) async {
    final controller = _cesiumController;
    if (controller == null) return;

    await controller.removeMeasurementDisplay(measurementId);

    final newMeasurements =
        state.measurements.where((m) => m.id != measurementId).toList();
    state = state.copyWith(measurements: newMeasurements);

    if (_projectPath != null) {
      await _saveMeasurements();
    }
  }

  /// 計測名を更新
  Future<void> updateMeasurementName(
    String measurementId,
    String newName,
  ) async {
    final index = state.measurements.indexWhere((m) => m.id == measurementId);
    if (index == -1) return;

    final updatedMeasurement =
        state.measurements[index].copyWith(name: newName);
    final newMeasurements = [...state.measurements];
    newMeasurements[index] = updatedMeasurement;

    state = state.copyWith(measurements: newMeasurements);

    // CesiumJSの表示を更新
    final controller = _cesiumController;
    if (controller != null) {
      await controller.removeMeasurementDisplay(measurementId);
      await _addMeasurementToCesium(updatedMeasurement);
    }

    if (_projectPath != null) {
      await _saveMeasurements();
    }
  }

  /// 計測の表示/非表示を切り替え
  Future<void> toggleMeasurementVisibility(String measurementId) async {
    final index = state.measurements.indexWhere((m) => m.id == measurementId);
    if (index == -1) return;

    final measurement = state.measurements[index];
    final newVisibility = !measurement.visible;

    final controller = _cesiumController;
    if (controller != null) {
      await controller.setMeasurementVisible(measurementId, newVisibility);
    }

    final updatedMeasurement = measurement.copyWith(visible: newVisibility);
    final newMeasurements = [...state.measurements];
    newMeasurements[index] = updatedMeasurement;

    state = state.copyWith(measurements: newMeasurements);

    if (_projectPath != null) {
      await _saveMeasurements();
    }
  }

  /// 計測のスタイルを更新（色、不透明度、線幅）
  Future<void> updateMeasurementStyle({
    required String measurementId,
    String? color,
    double? fillOpacity,
    double? lineWidth,
  }) async {
    final index = state.measurements.indexWhere((m) => m.id == measurementId);
    if (index == -1) return;

    final measurement = state.measurements[index];
    final updatedMeasurement = measurement.copyWith(
      color: color ?? measurement.color,
      lineWidth: lineWidth ?? measurement.lineWidth,
    );

    final newMeasurements = [...state.measurements];
    newMeasurements[index] = updatedMeasurement;

    state = state.copyWith(measurements: newMeasurements);

    // CesiumJSのスタイルを更新
    final controller = _cesiumController;
    if (controller != null) {
      await controller.updateMeasurementStyle(
        measurementId: measurementId,
        color: updatedMeasurement.color,
        fillOpacity: fillOpacity ?? 0.3,
        lineWidth: updatedMeasurement.lineWidth,
      );
    }

    if (_projectPath != null) {
      await _saveMeasurements();
    }
  }

  /// 計測ポイント編集モードを開始
  Future<void> startEditMode(String measurementId) async {
    // 計測中なら終了
    if (state.isMeasuring) {
      await cancelMeasurement();
    }

    final controller = _cesiumController;
    if (controller != null) {
      await controller.startMeasurementEditMode(measurementId);
    }

    state = state.copyWith(editingMeasurementId: measurementId);
  }

  /// 計測ポイント編集モードを終了
  Future<void> endEditMode() async {
    final controller = _cesiumController;
    if (controller != null) {
      await controller.endMeasurementEditMode();
    }

    state = state.copyWith(clearEditingId: true);
  }

  /// 計測ポイントを更新
  Future<void> updateMeasurementPoint({
    required String measurementId,
    required int pointIndex,
    required GeoPosition newPoint,
  }) async {
    final index = state.measurements.indexWhere((m) => m.id == measurementId);
    if (index == -1) return;

    final measurement = state.measurements[index];
    final newPoints = [...measurement.points];
    newPoints[pointIndex] = newPoint;

    // 計測値を再計算
    final newValue = _recalculateMeasurement(measurement.type, newPoints);

    final updatedMeasurement = measurement.copyWith(
      points: newPoints,
      value: newValue,
    );

    final newMeasurements = [...state.measurements];
    newMeasurements[index] = updatedMeasurement;

    state = state.copyWith(measurements: newMeasurements);

    // 表示を更新
    await _updateMeasurementInCesium(updatedMeasurement);

    if (_projectPath != null) {
      await _saveMeasurements();
    }
  }

  /// 計測一覧を読み込み
  Future<void> loadMeasurements(String projectPath) async {
    state = state.copyWith(isLoading: true);

    try {
      final file = File(path.join(projectPath, 'measurements.json'));

      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as List<dynamic>;
        final measurements = json
            .map((e) => Measurement.fromJson(e as Map<String, dynamic>))
            .toList();

        state = state.copyWith(measurements: measurements, isLoading: false);

        // CesiumJSに表示を追加
        for (final measurement in measurements) {
          if (measurement.visible) {
            await _addMeasurementToCesium(measurement);
          }
        }
      } else {
        state = state.copyWith(measurements: [], isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(measurements: [], isLoading: false);
    }
  }

  /// CSVとしてエクスポート
  Future<String> exportToCsv() async {
    final buffer = StringBuffer();

    // ヘッダ
    buffer.writeln('ID,名前,タイプ,値,単位,色,メモ,作成日時,ポイント数');

    // データ
    for (final m in state.measurements) {
      buffer.writeln([
        m.id,
        '"${m.name}"',
        m.type.displayName,
        m.value ?? 0,
        m.unit,
        m.color,
        '"${m.note ?? ''}"',
        m.createdAt.toIso8601String(),
        m.points.length,
      ].join(','));
    }

    return buffer.toString();
  }

  /// GeoJSONとしてエクスポート
  Future<Map<String, dynamic>> exportToGeoJson() async {
    final features = state.measurements.map((m) {
      Map<String, dynamic> geometry;

      if (m.type == MeasurementType.area) {
        // ポリゴン
        geometry = {
          'type': 'Polygon',
          'coordinates': [
            m.points
                .map((p) => [p.longitude, p.latitude, p.height])
                .toList(),
          ],
        };
      } else if (m.points.length > 1) {
        // ライン
        geometry = {
          'type': 'LineString',
          'coordinates':
              m.points.map((p) => [p.longitude, p.latitude, p.height]).toList(),
        };
      } else {
        // ポイント
        geometry = {
          'type': 'Point',
          'coordinates': [
            m.points.first.longitude,
            m.points.first.latitude,
            m.points.first.height,
          ],
        };
      }

      return {
        'type': 'Feature',
        'id': m.id,
        'geometry': geometry,
        'properties': {
          'name': m.name,
          'type': m.type.name,
          'value': m.value,
          'unit': m.unit,
          'color': m.color,
          'note': m.note,
          'createdAt': m.createdAt.toIso8601String(),
        },
      };
    }).toList();

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  // ============================================
  // 内部メソッド
  // ============================================

  MeasurementType? _typeFromString(String type) {
    switch (type) {
      case 'distance':
        return MeasurementType.distance;
      case 'area':
        return MeasurementType.area;
      case 'height':
        return MeasurementType.height;
      case 'angle':
        return MeasurementType.angle;
      default:
        return null;
    }
  }

  /// 計測値を再計算
  double _recalculateMeasurement(MeasurementType type, List<GeoPosition> points) {
    if (points.length < 2) return 0;

    switch (type) {
      case MeasurementType.distance:
        return _calculateDistance(points);
      case MeasurementType.area:
        return _calculateArea(points);
      case MeasurementType.height:
        return _calculateHeight(points);
      case MeasurementType.angle:
        return 0; // 未実装
    }
  }

  /// 距離を計算（メートル）
  double _calculateDistance(List<GeoPosition> points) {
    double totalDistance = 0;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      // Haversine formula
      const earthRadius = 6371000.0; // メートル
      final lat1 = p1.latitude * pi / 180;
      final lat2 = p2.latitude * pi / 180;
      final dLat = (p2.latitude - p1.latitude) * pi / 180;
      final dLon = (p2.longitude - p1.longitude) * pi / 180;

      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      final horizontalDistance = earthRadius * c;

      // 高さの差
      final heightDiff = p2.height - p1.height;

      // 3D距離
      totalDistance +=
          sqrt(horizontalDistance * horizontalDistance + heightDiff * heightDiff);
    }

    return totalDistance;
  }

  /// 面積を計算（平方メートル）
  double _calculateArea(List<GeoPosition> points) {
    if (points.length < 3) return 0;

    double area = 0;
    final n = points.length;

    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;

      // 緯度経度をメートル座標に変換（近似）
      final avgLat = (points[i].latitude + points[j].latitude) / 2 * pi / 180;
      final x1 = points[i].longitude * 111320 * cos(avgLat);
      final y1 = points[i].latitude * 110540;
      final x2 = points[j].longitude * 111320 * cos(avgLat);
      final y2 = points[j].latitude * 110540;

      area += x1 * y2 - x2 * y1;
    }

    return area.abs() / 2;
  }

  /// 高さ/標高差を計算（メートル）
  double _calculateHeight(List<GeoPosition> points) {
    if (points.length < 2) return 0;
    return (points[1].height - points[0].height).abs();
  }

  /// CesiumJSの計測表示を更新
  Future<void> _updateMeasurementInCesium(Measurement measurement) async {
    final controller = _cesiumController;
    if (controller == null) return;

    await controller.updateMeasurementDisplay({
      'id': measurement.id,
      'type': measurement.type.name,
      'name': measurement.name,
      'points': measurement.points.map((p) => p.toJson()).toList(),
      'value': measurement.value,
      'unit': measurement.unit,
      'color': measurement.color,
      'lineWidth': measurement.lineWidth,
      'visible': measurement.visible,
    });
  }

  Future<void> _addMeasurementToCesium(Measurement measurement) async {
    final controller = _cesiumController;
    if (controller == null) return;

    await controller.addMeasurementDisplay({
      'id': measurement.id,
      'type': measurement.type.name,
      'name': measurement.name,
      'points': measurement.points.map((p) => p.toJson()).toList(),
      'value': measurement.value,
      'unit': measurement.unit,
      'color': measurement.color,
      'lineWidth': measurement.lineWidth,
      'visible': measurement.visible,
    });
  }

  Future<void> _saveMeasurements() async {
    if (_projectPath == null) return;

    try {
      final file = File(path.join(_projectPath!, 'measurements.json'));
      final json = state.measurements.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(json), flush: true);
    } catch (e) {
      // エラー処理（ログ出力など）
    }
  }
}

/// 計測プロバイダー
final measurementProvider =
    StateNotifierProvider<MeasurementNotifier, MeasurementState>((ref) {
  final cesiumController = ref.watch(cesiumControllerProvider);
  return MeasurementNotifier(cesiumController);
});
