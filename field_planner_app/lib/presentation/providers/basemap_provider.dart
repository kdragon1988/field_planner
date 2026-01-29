import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/basemap.dart';
import 'cesium_provider.dart';

/// 現在選択されているベースマップ
final currentBaseMapProvider = StateProvider<BaseMapProvider>((ref) {
  return BaseMapProvider.googleSatellite;
});

/// ベースマップの不透明度
final baseMapOpacityProvider = StateProvider<double>((ref) => 1.0);

/// ベースマップコントローラ
class BaseMapController {
  final Ref _ref;

  BaseMapController(this._ref);

  /// ベースマップを変更
  Future<void> changeBaseMap(BaseMapProvider provider) async {
    final cesiumController = _ref.read(cesiumControllerProvider);
    if (cesiumController == null) return;

    String providerName;
    switch (provider) {
      case BaseMapProvider.googleSatellite:
        providerName = 'googleSatellite';
        break;
      case BaseMapProvider.googleRoad:
        providerName = 'googleRoad';
        break;
      case BaseMapProvider.osm:
        providerName = 'osm';
        break;
      case BaseMapProvider.esriWorld:
        providerName = 'esriWorld';
        break;
      case BaseMapProvider.esriNatGeo:
        providerName = 'esriNatGeo';
        break;
      case BaseMapProvider.bing:
        providerName = 'bing';
        break;
      case BaseMapProvider.google:
        providerName = 'google';
        break;
      case BaseMapProvider.cesiumIon:
        providerName = 'cesiumIon';
        break;
      case BaseMapProvider.custom:
        providerName = 'custom';
        break;
    }

    await cesiumController.setBaseMap(providerName);
    _ref.read(currentBaseMapProvider.notifier).state = provider;
  }

  /// 不透明度を変更
  Future<void> setOpacity(double opacity) async {
    final cesiumController = _ref.read(cesiumControllerProvider);
    if (cesiumController == null) return;

    await cesiumController.executeMethod('setBaseMapOpacity', {
      'id': 'default_basemap',
      'opacity': opacity,
    });
    _ref.read(baseMapOpacityProvider.notifier).state = opacity;
  }
}

/// BaseMapControllerのProvider
final baseMapControllerProvider = Provider<BaseMapController>((ref) {
  return BaseMapController(ref);
});
