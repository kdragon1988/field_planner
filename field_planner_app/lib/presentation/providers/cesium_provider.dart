import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/webview/cesium_controller.dart';
import '../../data/models/geo_position.dart';

/// CesiumControllerを保持するStateNotifier
class CesiumControllerNotifier extends StateNotifier<CesiumController?> {
  CesiumControllerNotifier() : super(null);

  /// コントローラを設定
  void setController(CesiumController controller) {
    state = controller;
  }

  /// コントローラをクリア
  void clearController() {
    state = null;
  }
}

/// CesiumControllerのProvider
final cesiumControllerProvider =
    StateNotifierProvider<CesiumControllerNotifier, CesiumController?>((ref) {
  return CesiumControllerNotifier();
});

/// 現在のカメラ位置を保持するStateNotifier
class CameraPositionNotifier extends StateNotifier<CameraPosition?> {
  CameraPositionNotifier() : super(null);

  /// カメラ位置を更新
  void updatePosition(CameraPosition position) {
    state = position;
  }

  /// クリア
  void clear() {
    state = null;
  }
}

/// カメラ位置のProvider
final cameraPositionProvider =
    StateNotifierProvider<CameraPositionNotifier, CameraPosition?>((ref) {
  return CameraPositionNotifier();
});

/// CesiumJSの初期化状態
final cesiumInitializedProvider = StateProvider<bool>((ref) => false);
