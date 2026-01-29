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

  @override
  void dispose() {
    super.dispose();
  }
}
