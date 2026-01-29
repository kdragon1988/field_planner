import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/exceptions/app_exceptions.dart';
import '../../core/utils/logger.dart';
import '../../data/models/geo_position.dart';

/// シーンモード（2D/3D表示切替）
enum SceneMode {
  /// 2D表示
  scene2D,

  /// 3D表示
  scene3D,
}

/// CesiumJSとの通信を管理するコントローラ
///
/// WebView経由でCesiumJSの各種操作を行い、
/// イベントコールバックを受け取る
class CesiumController extends ChangeNotifier with LoggableMixin {
  final WebViewController _webViewController;

  /// CesiumJSの初期化完了フラグ
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 現在のカメラ位置
  CameraPosition? _currentCameraPosition;
  CameraPosition? get currentCameraPosition => _currentCameraPosition;

  /// カメラ位置変更時のコールバック
  Function(CameraPosition)? onCameraChanged;

  /// マップクリック時のコールバック
  Function(GeoPosition)? onMapClicked;

  /// 初期化完了時のコールバック
  Function(bool success)? onInitialized;

  /// エラー発生時のコールバック
  Function(String error)? onError;

  /// 計測モード開始時のコールバック
  Function(String type)? onMeasurementModeStarted;

  /// 計測点追加時のコールバック
  Function(List<GeoPosition> points, double currentValue, String unit)?
      onMeasurementPointAdded;

  /// 計測完了時のコールバック
  Function(String type, List<GeoPosition> points, double value, String unit)?
      onMeasurementCompleted;

  /// 計測キャンセル時のコールバック
  Function()? onMeasurementCancelled;

  /// 計測ポイント移動時のコールバック
  Function(String measurementId, int pointIndex, GeoPosition newPoint)?
      onMeasurementPointMoved;

  /// 計測ポイント削除時のコールバック
  Function(String measurementId, int pointIndex)? onMeasurementPointDeleted;

  /// 計測編集モード開始時のコールバック
  Function(String measurementId)? onMeasurementEditModeStarted;

  /// 計測編集モード終了時のコールバック
  Function(String measurementId)? onMeasurementEditModeEnded;

  // ============================================
  // 配置物コールバック
  // ============================================

  /// 配置確定時のコールバック
  Function(String assetId, GeoPosition position)? onPlacementConfirmed;

  /// 配置キャンセル時のコールバック
  Function()? onPlacementCancelled;

  /// 配置物選択時のコールバック
  Function(String placementId)? onPlacementSelected;

  /// 配置物選択解除時のコールバック
  Function()? onPlacementDeselected;

  /// 配置モード開始時のコールバック
  Function(String assetId)? onPlacementModeStarted;

  /// 配置物追加完了時のコールバック
  Function(String placementId)? onPlacementAdded;

  // ============================================
  // ドローンフォーメーションコールバック
  // ============================================

  /// ドローンフォーメーション追加完了時のコールバック
  Function(String formationId, int droneCount)? onDroneFormationAdded;

  /// ドローンフォーメーション削除時のコールバック
  Function(String formationId)? onDroneFormationRemoved;

  /// 3D Tileset追加完了時のコールバック
  Function(String id, String name, GeoPosition center, double radius)? onTilesetAdded;

  /// 3D Tileset削除時のコールバック
  Function(String id)? onTilesetRemoved;

  /// 3D Tilesetエラー時のコールバック
  Function(String id, String error)? onTilesetError;

  /// Google 3D Tiles表示/非表示変更時のコールバック
  Function(bool visible)? onGoogleTilesetVisibilityChanged;

  /// コンストラクタ（JavaScriptチャネルを自動設定）
  CesiumController(this._webViewController) {
    _setupJavaScriptChannels();
  }

  /// 既存のJavaScriptチャネルを使用するコンストラクタ
  ///
  /// チャネルが既にWebViewControllerに追加されている場合に使用
  CesiumController.withExistingChannel(this._webViewController);

  /// JavaScriptチャネルを設定
  void _setupJavaScriptChannels() {
    _webViewController.addJavaScriptChannel(
      'FlutterChannel',
      onMessageReceived: _handleMessageInternal,
    );
  }

  /// 外部からメッセージを処理するための公開メソッド
  ///
  /// JavaScriptチャネルがWidget側で設定されている場合に使用
  void handleMessage(JavaScriptMessage message) {
    _handleMessageInternal(message);
  }

  /// JavaScriptからのメッセージを処理（内部実装）
  void _handleMessageInternal(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final event = data['event'] as String;
      final payload = data['data'] as Map<String, dynamic>?;

      logDebug('Received event: $event');

      switch (event) {
        case 'initialized':
          _isInitialized = payload?['success'] == true;
          onInitialized?.call(_isInitialized);
          notifyListeners();
          logInfo('CesiumJS initialized: $_isInitialized');
          break;

        case 'initializeError':
          final error = payload?['error'] as String? ?? 'Unknown error';
          _isInitialized = false;
          onError?.call(error);
          logError('CesiumJS initialization error: $error');
          break;

        case 'cameraChanged':
          if (payload != null) {
            _currentCameraPosition = CameraPosition.fromJson(payload);
            onCameraChanged?.call(_currentCameraPosition!);
            // notifyListenersは頻繁に呼ばれるため、カメラ変更時は呼ばない
          }
          break;

        case 'mapClicked':
          if (payload != null) {
            final position = GeoPosition.fromJson(payload);
            onMapClicked?.call(position);
            logDebug('Map clicked: $position');
          }
          break;

        // 計測イベント
        case 'measurementModeStarted':
          if (payload != null) {
            final type = payload['type'] as String;
            onMeasurementModeStarted?.call(type);
            logInfo('Measurement mode started: $type');
          }
          break;

        case 'measurementPointAdded':
          if (payload != null) {
            final pointsJson = payload['points'] as List<dynamic>;
            final points = pointsJson
                .map((p) => GeoPosition.fromJson(p as Map<String, dynamic>))
                .toList();
            final currentValue = (payload['currentValue'] as num).toDouble();
            final unit = payload['unit'] as String;
            onMeasurementPointAdded?.call(points, currentValue, unit);
            logDebug('Measurement point added: ${points.length} points, value: $currentValue $unit');
          }
          break;

        case 'measurementCompleted':
          if (payload != null) {
            final type = payload['type'] as String;
            final pointsJson = payload['points'] as List<dynamic>;
            final points = pointsJson
                .map((p) => GeoPosition.fromJson(p as Map<String, dynamic>))
                .toList();
            final value = (payload['value'] as num).toDouble();
            final unit = payload['unit'] as String;
            onMeasurementCompleted?.call(type, points, value, unit);
            logInfo('Measurement completed: $type, value: $value $unit');
          }
          break;

        case 'measurementCancelled':
          onMeasurementCancelled?.call();
          logInfo('Measurement cancelled');
          break;

        case 'measurementPointMoved':
          if (payload != null) {
            final measurementId = payload['measurementId'] as String;
            final pointIndex = payload['pointIndex'] as int;
            final newPointJson = payload['newPoint'] as Map<String, dynamic>;
            final newPoint = GeoPosition.fromJson(newPointJson);
            onMeasurementPointMoved?.call(measurementId, pointIndex, newPoint);
            logInfo('Measurement point moved: $measurementId, index: $pointIndex');
          }
          break;

        case 'measurementPointDeleted':
          if (payload != null) {
            final measurementId = payload['measurementId'] as String;
            final pointIndex = payload['pointIndex'] as int;
            onMeasurementPointDeleted?.call(measurementId, pointIndex);
            logInfo('Measurement point deleted: $measurementId, index: $pointIndex');
          }
          break;

        case 'measurementEditModeStarted':
          if (payload != null) {
            final measurementId = payload['measurementId'] as String;
            onMeasurementEditModeStarted?.call(measurementId);
            logInfo('Measurement edit mode started: $measurementId');
          }
          break;

        case 'measurementEditModeEnded':
          if (payload != null) {
            final measurementId = payload['measurementId'] as String;
            onMeasurementEditModeEnded?.call(measurementId);
            logInfo('Measurement edit mode ended: $measurementId');
          }
          break;

        // Tilesetイベント
        case 'tilesetAdded':
          if (payload != null) {
            final id = payload['id'] as String;
            final name = payload['name'] as String? ?? id;
            final centerJson = payload['center'] as Map<String, dynamic>?;
            final radius = (payload['radius'] as num?)?.toDouble() ?? 0;
            if (centerJson != null) {
              final center = GeoPosition.fromJson(centerJson);
              onTilesetAdded?.call(id, name, center, radius);
              logInfo('Tileset added: $id at ${center.latitude}, ${center.longitude}');
            }
          }
          break;

        case 'tilesetRemoved':
          if (payload != null) {
            final id = payload['id'] as String;
            onTilesetRemoved?.call(id);
            logInfo('Tileset removed: $id');
          }
          break;

        case 'tilesetError':
          if (payload != null) {
            final id = payload['id'] as String;
            final error = payload['error'] as String? ?? 'Unknown error';
            onTilesetError?.call(id, error);
            logError('Tileset error: $id - $error');
          }
          break;

        case 'googleTilesetVisibilityChanged':
          if (payload != null) {
            final visible = payload['visible'] as bool? ?? true;
            onGoogleTilesetVisibilityChanged?.call(visible);
            logInfo('Google tileset visibility changed: $visible');
          }
          break;

        // 配置物イベント
        case 'placementConfirmed':
          if (payload != null) {
            final assetId = payload['assetId'] as String;
            final positionJson = payload['position'] as Map<String, dynamic>;
            final position = GeoPosition.fromJson(positionJson);
            onPlacementConfirmed?.call(assetId, position);
            logInfo('Placement confirmed: $assetId at ${position.latitude}, ${position.longitude}');
          }
          break;

        case 'placementCancelled':
          onPlacementCancelled?.call();
          logInfo('Placement cancelled');
          break;

        case 'placementSelected':
          if (payload != null) {
            final placementId = payload['id'] as String;
            onPlacementSelected?.call(placementId);
            logInfo('Placement selected: $placementId');
          }
          break;

        case 'placementDeselected':
          onPlacementDeselected?.call();
          logInfo('Placement deselected');
          break;

        case 'placementModeStarted':
          if (payload != null) {
            final assetId = payload['assetId'] as String;
            onPlacementModeStarted?.call(assetId);
            logInfo('Placement mode started: $assetId');
          }
          break;

        case 'placementAdded':
          if (payload != null) {
            final placementId = payload['id'] as String;
            onPlacementAdded?.call(placementId);
            logInfo('Placement added: $placementId');
          }
          break;

        // ドローンフォーメーションイベント
        case 'droneFormationAdded':
          if (payload != null) {
            final formationId = payload['id'] as String;
            final droneCount = payload['droneCount'] as int? ?? 0;
            onDroneFormationAdded?.call(formationId, droneCount);
            logInfo('Drone formation added: $formationId ($droneCount drones)');
          }
          break;

        case 'droneFormationRemoved':
          if (payload != null) {
            final formationId = payload['id'] as String;
            onDroneFormationRemoved?.call(formationId);
            logInfo('Drone formation removed: $formationId');
          }
          break;

        default:
          logWarning('Unknown event: $event');
      }
    } catch (e, stackTrace) {
      logError('Error handling Cesium message', e, stackTrace);
    }
  }

  /// CesiumJSを初期化
  ///
  /// [ionToken] Cesium Ionアクセストークン（オプション）
  /// [googleMapsApiKey] Google Maps APIキー（オプション）
  /// [center] 初期表示位置
  Future<void> initialize({
    String? ionToken,
    String? googleMapsApiKey,
    GeoPosition? center,
  }) async {
    await executeMethod('initialize', {
      'ionToken': ionToken ?? '',
      'googleMapsApiKey': googleMapsApiKey ?? '',
      if (center != null) 'center': center.toJson(),
    });
  }

  /// 指定座標にカメラを移動
  ///
  /// [longitude] 経度
  /// [latitude] 緯度
  /// [height] 高さ（メートル）
  /// [heading] 方位角（度）
  /// [pitch] ピッチ（度）
  /// [duration] アニメーション時間（秒）
  Future<void> flyTo({
    required double longitude,
    required double latitude,
    double height = 1000,
    double heading = 0,
    double pitch = -45,
    double duration = 2,
  }) async {
    await executeMethod('flyTo', {
      'longitude': longitude,
      'latitude': latitude,
      'height': height,
      'heading': heading,
      'pitch': pitch,
      'duration': duration,
    });
  }

  /// GeoPositionを使用してカメラを移動
  Future<void> flyToPosition(GeoPosition position, {double duration = 2}) async {
    await flyTo(
      longitude: position.longitude,
      latitude: position.latitude,
      height: position.height,
      duration: duration,
    );
  }

  /// ベースマップを変更
  ///
  /// [provider] プロバイダ名（'osm', 'esri_world', 'esri_natgeo'等）
  Future<void> setBaseMap(String provider) async {
    await executeMethod('setBaseMap', {
      'provider': provider,
    });
    logInfo('Base map changed to: $provider');
  }

  /// 2D/3D表示モードを切り替え
  Future<void> setSceneMode(SceneMode mode) async {
    await executeMethod('setSceneMode', {
      'mode': mode == SceneMode.scene2D ? '2d' : '3d',
    });
    logInfo('Scene mode changed to: $mode');
  }

  /// JavaScriptメソッドを実行
  ///
  /// [method] メソッド名
  /// [params] パラメータ
  Future<void> executeMethod(
    String method,
    Map<String, dynamic> params,
  ) async {
    final paramsJson = jsonEncode(params);
    final script = '''
      window.CesiumBridge.handleFlutterMessage('$method', $paramsJson);
    ''';

    try {
      await _webViewController.runJavaScript(script);
    } catch (e) {
      logError('Failed to execute CesiumBridge method: $method', e);
      throw CesiumBridgeException(
        'Failed to execute method: $method',
        cause: e,
      );
    }
  }

  /// スクリーンショットを取得（将来実装）
  Future<String?> captureScreenshot() async {
    // TODO: CesiumJS側でCanvas.toDataURL()を実行して取得
    return null;
  }

  // ============================================
  // 計測機能
  // ============================================

  /// 計測モードを開始
  ///
  /// [type] 計測タイプ ('distance', 'area', 'height')
  Future<void> startMeasurementMode(String type) async {
    await executeMethod('startMeasurementMode', {
      'type': type,
    });
    logInfo('Starting measurement mode: $type');
  }

  /// 計測をキャンセル
  Future<void> cancelMeasurement() async {
    await executeMethod('cancelMeasurement', {});
    logInfo('Measurement cancelled');
  }

  /// 計測結果を表示
  ///
  /// [measurement] 計測データ（id, type, name, points, value, unit, color等）
  Future<void> addMeasurementDisplay(Map<String, dynamic> measurement) async {
    await executeMethod('addMeasurementDisplay', measurement);
  }

  /// 計測結果を削除
  ///
  /// [measurementId] 計測ID
  Future<void> removeMeasurementDisplay(String measurementId) async {
    await executeMethod('removeMeasurementDisplay', {
      'measurementId': measurementId,
    });
  }

  /// 計測結果の表示/非表示を切り替え
  ///
  /// [measurementId] 計測ID
  /// [visible] 表示フラグ
  Future<void> setMeasurementVisible(String measurementId, bool visible) async {
    await executeMethod('setMeasurementVisible', {
      'measurementId': measurementId,
      'visible': visible,
    });
  }

  /// すべての計測結果をクリア
  Future<void> clearAllMeasurements() async {
    await executeMethod('clearAllMeasurements', {});
  }

  /// 計測結果のスタイルを更新
  ///
  /// [measurementId] 計測ID
  /// [color] 色（HEX）
  /// [fillOpacity] 塗りの不透明度
  /// [lineWidth] 線の太さ
  Future<void> updateMeasurementStyle({
    required String measurementId,
    required String color,
    required double fillOpacity,
    double? lineWidth,
  }) async {
    await executeMethod('updateMeasurementStyle', {
      'measurementId': measurementId,
      'color': color,
      'fillOpacity': fillOpacity,
      if (lineWidth != null) 'lineWidth': lineWidth,
    });
  }

  /// 計測結果を更新（ポイント変更を含む）
  ///
  /// [measurement] 計測データ
  Future<void> updateMeasurementDisplay(Map<String, dynamic> measurement) async {
    await executeMethod('updateMeasurementDisplay', measurement);
  }

  /// 計測ポイント編集モードを開始
  ///
  /// [measurementId] 計測ID
  Future<void> startMeasurementEditMode(String measurementId) async {
    await executeMethod('startMeasurementEditMode', {
      'measurementId': measurementId,
    });
    logInfo('Starting measurement edit mode: $measurementId');
  }

  /// 計測ポイント編集モードを終了
  Future<void> endMeasurementEditMode() async {
    await executeMethod('endMeasurementEditMode', {});
    logInfo('Ending measurement edit mode');
  }

  // ============================================
  // 3D Tileset機能
  // ============================================

  /// ローカルの3D Tilesを追加
  ///
  /// [id] TilesetのユニークID
  /// [url] tileset.jsonのURL（file://プロトコル対応）
  /// [name] 表示名
  /// [opacity] 不透明度（0.0〜1.0）
  /// [show] 表示フラグ
  Future<void> addLocalTileset({
    required String id,
    required String url,
    String? name,
    double opacity = 1.0,
    bool show = true,
  }) async {
    await executeMethod('addLocalTileset', {
      'id': id,
      'url': url,
      'name': name ?? id,
      'opacity': opacity,
      'show': show,
    });
    logInfo('Adding local tileset: $id from $url');
  }

  /// 3D Tilesetを削除
  ///
  /// [id] TilesetのID
  Future<void> removeTileset(String id) async {
    await executeMethod('removeTileset', {'id': id});
    logInfo('Removing tileset: $id');
  }

  /// 3D Tilesetの表示/非表示を切り替え
  ///
  /// [id] TilesetのID
  /// [visible] 表示フラグ
  Future<void> setTilesetVisible(String id, bool visible) async {
    await executeMethod('setTilesetVisible', {
      'id': id,
      'visible': visible,
    });
  }

  /// 3D Tilesetの不透明度を設定
  ///
  /// [id] TilesetのID
  /// [opacity] 不透明度（0.0〜1.0）
  Future<void> setTilesetOpacity(String id, double opacity) async {
    await executeMethod('setTilesetOpacity', {
      'id': id,
      'opacity': opacity,
    });
  }

  /// Google Photorealistic 3D Tilesの表示/非表示を切り替え
  ///
  /// [visible] 表示フラグ
  Future<void> setGoogleTilesetVisible(bool visible) async {
    await executeMethod('setGoogleTilesetVisible', {'visible': visible});
    logInfo('Setting Google tileset visible: $visible');
  }

  /// 3D Tilesetの位置にカメラを移動
  ///
  /// [id] TilesetのID
  Future<void> flyToTileset(String id) async {
    await executeMethod('flyToTileset', {'id': id});
    logInfo('Flying to tileset: $id');
  }

  /// 地形の表示/非表示を切り替え
  ///
  /// [enabled] 有効フラグ
  Future<void> setTerrainEnabled(bool enabled) async {
    await executeMethod('setTerrainEnabled', {'enabled': enabled});
    logInfo('Setting terrain enabled: $enabled');
  }

  /// Google 3D Tilesにクリッピングを設定
  ///
  /// インポートしたTilesetの範囲でGoogle 3D Tilesをクリップ
  /// [tilesetId] クリップ元のTilesetのID
  Future<void> setGoogleTilesetClipping(String tilesetId) async {
    await executeMethod('setGoogleTilesetClipping', {'tilesetId': tilesetId});
    logInfo('Setting Google tileset clipping for: $tilesetId');
  }

  /// Google 3D Tilesのクリッピングを解除
  Future<void> removeGoogleTilesetClipping() async {
    await executeMethod('removeGoogleTilesetClipping', {});
    logInfo('Removing Google tileset clipping');
  }

  /// Tilesetの位置を調整
  ///
  /// [id] TilesetのID
  /// [heightOffset] 高さオフセット（メートル）
  /// [longitude] 経度オフセット（度）
  /// [latitude] 緯度オフセット（度）
  /// [heading] 方位角（度）
  /// [pitch] ピッチ（度）
  /// [roll] ロール（度）
  Future<void> adjustTilesetPosition({
    required String id,
    double? heightOffset,
    double? longitude,
    double? latitude,
    double? heading,
    double? pitch,
    double? roll,
  }) async {
    await executeMethod('adjustTilesetPosition', {
      'id': id,
      if (heightOffset != null) 'heightOffset': heightOffset,
      if (longitude != null) 'longitude': longitude,
      if (latitude != null) 'latitude': latitude,
      if (heading != null) 'heading': heading,
      if (pitch != null) 'pitch': pitch,
      if (roll != null) 'roll': roll,
    });
  }

  /// Tilesetの画質（LOD）を調整
  ///
  /// [id] TilesetのID
  /// [screenSpaceError] Screen Space Error（1-64、小さいほど高画質）
  Future<void> adjustTilesetQuality({
    required String id,
    required double screenSpaceError,
  }) async {
    await executeMethod('adjustTilesetQuality', {
      'id': id,
      'screenSpaceError': screenSpaceError,
    });
    logInfo('Adjusting tileset quality: $id, SSE: $screenSpaceError');
  }

  // ============================================
  // 配置物機能
  // ============================================

  /// 配置物を追加
  ///
  /// [placement] 配置物データ（JSON形式）
  /// [modelUrl] 3DモデルのURL
  Future<void> addPlacement(Map<String, dynamic> placement, String modelUrl) async {
    await executeMethod('addPlacement', {
      'placement': placement,
      'modelUrl': modelUrl,
    });
    logInfo('Adding placement: ${placement['id']}');
  }

  /// 配置物を削除
  ///
  /// [placementId] 配置物ID
  Future<void> removePlacement(String placementId) async {
    await executeMethod('removePlacement', {'placementId': placementId});
    logInfo('Removing placement: $placementId');
  }

  /// 配置物を更新
  ///
  /// [placement] 配置物データ（JSON形式）
  Future<void> updatePlacement(Map<String, dynamic> placement) async {
    await executeMethod('updatePlacement', {'placement': placement});
    logInfo('Updating placement: ${placement['id']}');
  }

  /// 配置モードを開始
  ///
  /// [assetId] アセットID
  /// [modelUrl] 3DモデルのURL
  Future<void> startPlacementMode(String assetId, String modelUrl) async {
    await executeMethod('startPlacementMode', {
      'assetId': assetId,
      'modelUrl': modelUrl,
    });
    logInfo('Starting placement mode: $assetId');
  }

  /// 配置モードをキャンセル
  Future<void> cancelPlacementMode() async {
    await executeMethod('cancelPlacementMode', {});
    logInfo('Cancelling placement mode');
  }

  /// 配置物を選択
  ///
  /// [placementId] 配置物ID
  Future<void> selectPlacement(String placementId) async {
    await executeMethod('selectPlacement', {'placementId': placementId});
  }

  /// 配置物の選択を解除
  Future<void> deselectPlacement() async {
    await executeMethod('deselectPlacement', {});
  }

  /// 配置物にズーム
  ///
  /// [placementId] 配置物ID
  Future<void> zoomToPlacement(String placementId) async {
    await executeMethod('zoomToPlacement', {'placementId': placementId});
    logInfo('Zooming to placement: $placementId');
  }

  /// スナップ設定を更新
  ///
  /// [gridEnabled] グリッドスナップ有効
  /// [gridSize] グリッドサイズ（メートル）
  /// [groundEnabled] 地面スナップ有効
  /// [angleEnabled] 角度スナップ有効
  /// [angleStep] 角度スナップのステップ（度）
  Future<void> updateSnapSettings({
    bool? gridEnabled,
    double? gridSize,
    bool? groundEnabled,
    bool? angleEnabled,
    double? angleStep,
  }) async {
    await executeMethod('updateSnapSettings', {
      if (gridEnabled != null) 'gridEnabled': gridEnabled,
      if (gridSize != null) 'gridSize': gridSize,
      if (groundEnabled != null) 'groundEnabled': groundEnabled,
      if (angleEnabled != null) 'angleEnabled': angleEnabled,
      if (angleStep != null) 'angleStep': angleStep,
    });
  }

  // ============================================
  // ドローンフォーメーション機能
  // ============================================

  /// ドローンフォーメーションを追加
  ///
  /// [id] フォーメーションID
  /// [name] フォーメーション名
  /// [drones] ドローンデータリスト
  /// [basePosition] 基準位置
  /// [altitude] 高度（メートル）
  /// [heading] 方位角（度）
  /// [scale] スケール
  /// [pointSize] ポイントサイズ（ピクセル）
  /// [customColor] カスタム色（HEX）
  /// [useIndividualColors] 個別色を使用するか
  Future<void> addDroneFormation({
    required String id,
    required String name,
    required List<Map<String, dynamic>> drones,
    required GeoPosition basePosition,
    double altitude = 50.0,
    double heading = 0.0,
    double tilt = 0.0,
    double scale = 1.0,
    double pointSize = 5.0,
    double glowIntensity = 1.0,
    String? customColor,
    bool useIndividualColors = true,
  }) async {
    await executeMethod('addDroneFormation', {
      'id': id,
      'name': name,
      'drones': drones,
      'basePosition': {
        'longitude': basePosition.longitude,
        'latitude': basePosition.latitude,
      },
      'altitude': altitude,
      'heading': heading,
      'tilt': tilt,
      'scale': scale,
      'pointSize': pointSize,
      'glowIntensity': glowIntensity,
      if (customColor != null) 'customColor': customColor,
      'useIndividualColors': useIndividualColors,
    });
    logInfo('Adding drone formation: $id');
  }

  /// ドローンフォーメーションを削除
  ///
  /// [formationId] フォーメーションID
  Future<void> removeDroneFormation(String formationId) async {
    await executeMethod('removeDroneFormation', {'formationId': formationId});
    logInfo('Removing drone formation: $formationId');
  }

  /// ドローンフォーメーションを更新
  ///
  /// 全ての設定を含むconfigオブジェクトを渡す
  Future<void> updateDroneFormation(Map<String, dynamic> config) async {
    await executeMethod('updateDroneFormation', config);
    logInfo('Updating drone formation: ${config['id']}');
  }

  /// ドローンフォーメーションのスタイルを更新
  ///
  /// [formationId] フォーメーションID
  /// [pointSize] ポイントサイズ（ピクセル）
  /// [glowIntensity] 輝度（グロー強度、0.5-3.0）
  /// [customColor] カスタム色（HEX）
  /// [useIndividualColors] 個別色を使用するか
  /// [visible] 表示フラグ
  Future<void> updateDroneFormationStyle({
    required String formationId,
    double? pointSize,
    double? glowIntensity,
    String? customColor,
    bool? useIndividualColors,
    bool? visible,
  }) async {
    await executeMethod('updateDroneFormationStyle', {
      'formationId': formationId,
      'options': {
        if (pointSize != null) 'pointSize': pointSize,
        if (glowIntensity != null) 'glowIntensity': glowIntensity,
        if (customColor != null) 'customColor': customColor,
        if (useIndividualColors != null) 'useIndividualColors': useIndividualColors,
        if (visible != null) 'visible': visible,
      },
    });
  }

  /// ドローンフォーメーションの表示/非表示を切り替え
  ///
  /// [formationId] フォーメーションID
  /// [visible] 表示フラグ
  Future<void> setDroneFormationVisible(String formationId, bool visible) async {
    await executeMethod('setDroneFormationVisible', {
      'formationId': formationId,
      'visible': visible,
    });
  }

  /// ドローンフォーメーションにズーム
  ///
  /// [formationId] フォーメーションID
  Future<void> zoomToDroneFormation(String formationId) async {
    await executeMethod('zoomToDroneFormation', {'formationId': formationId});
    logInfo('Zooming to drone formation: $formationId');
  }
}
