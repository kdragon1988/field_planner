/**
 * CesiumJS - Flutter Bridge
 * 
 * FlutterアプリケーションとCesiumJS間の通信を担当するモジュール。
 * メッセージの送受信、ビューワーの制御、各種イベントの処理を行う。
 */

// グローバル変数
let viewer = null;
let currentCamera = null;

// イメージリーレイヤー管理
const imageryLayers = new Map();

/**
 * Cesium Viewerを初期化
 * @param {Object} config - 初期設定
 */
async function initializeCesium(config) {
  try {
    // Cesium Ion トークンを設定（設定されている場合）
    if (config.ionToken) {
      Cesium.Ion.defaultAccessToken = config.ionToken;
    }

    // CesiumJS 1.107以降の新しいAPI対応
    // terrain オプションを使用（terrainProviderは非推奨）
    viewer = new Cesium.Viewer('cesiumContainer', {
      baseLayerPicker: false,
      geocoder: false,
      homeButton: false,
      sceneModePicker: false,
      navigationHelpButton: false,
      animation: false,
      timeline: false,
      fullscreenButton: false,
      vrButton: false,
      infoBox: true,
      selectionIndicator: true,
    });

    // 地形プロバイダーはデフォルト（楕円体）のまま
    // 3D地形は描画問題を引き起こす可能性があるため、最初は無効
    // 必要に応じてsetTerrainEnabled(true)で有効化可能

    // デフォルトのベースレイヤーを削除して新しいレイヤーを追加
    viewer.imageryLayers.removeAll();

    // Google Maps APIキーを保存（後でベースマップ切り替えに使用）
    window._googleMapsApiKey = config.googleMapsApiKey || '';

    // ベースマップを設定
    try {
      if (config.googleMapsApiKey) {
        // Google Mapsの衛星画像をベースマップとして使用
        const googleSatellite = new Cesium.UrlTemplateImageryProvider({
          url: `https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}`,
          credit: new Cesium.Credit('Google Maps', false)
        });
        viewer.imageryLayers.addImageryProvider(googleSatellite);
        console.log('Google Maps Satellite loaded as base map');
      } else if (config.ionToken) {
        // Cesium Ion Asset ID 2 = Bing Maps Aerial with Labels
        const ionImagery = await Cesium.IonImageryProvider.fromAssetId(2);
        viewer.imageryLayers.addImageryProvider(ionImagery);
        console.log('Bing Maps loaded as base map');
      } else {
        // フォールバック: ArcGIS World Imagery
        const arcGisProvider = await Cesium.ArcGisMapServerImageryProvider.fromUrl(
          'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer'
        );
        viewer.imageryLayers.addImageryProvider(arcGisProvider);
      }
    } catch (imageryError) {
      console.warn('Failed to load imagery provider:', imageryError);
      // フォールバック: TileMapServiceImageryProviderを試す
      try {
        const naturalEarth = await Cesium.TileMapServiceImageryProvider.fromUrl(
          Cesium.buildModuleUrl('Assets/Textures/NaturalEarthII')
        );
        viewer.imageryLayers.addImageryProvider(naturalEarth);
      } catch (fallbackError) {
        console.error('All imagery providers failed:', fallbackError);
      }
    }

    // シーンの設定を最適化
    viewer.scene.globe.depthTestAgainstTerrain = false;
    viewer.scene.logarithmicDepthBuffer = true;

    // Google Photorealistic 3D Tiles を追加
    if (config.ionToken) {
      try {
        // Google Photorealistic 3D Tiles (Asset ID: 2275207)
        const googleTileset = await Cesium.Cesium3DTileset.fromIonAssetId(2275207);
        viewer.scene.primitives.add(googleTileset);
        console.log('Google Photorealistic 3D Tiles loaded successfully');
      } catch (tilesError) {
        console.warn('Failed to load Google 3D Tiles:', tilesError);
        // フォールバック: Cesium OSM Buildings
        try {
          const osmBuildings = await Cesium.Cesium3DTileset.fromIonAssetId(96188);
          viewer.scene.primitives.add(osmBuildings);
          console.log('Fallback to Cesium OSM Buildings');
        } catch (fallbackError) {
          console.warn('Failed to load OSM Buildings:', fallbackError);
        }
      }
    }

    // カメラ変更イベントのリスナー
    viewer.camera.changed.addEventListener(() => {
      const position = viewer.camera.positionCartographic;
      sendToFlutter('cameraChanged', {
        longitude: Cesium.Math.toDegrees(position.longitude),
        latitude: Cesium.Math.toDegrees(position.latitude),
        height: position.height,
        heading: Cesium.Math.toDegrees(viewer.camera.heading),
        pitch: Cesium.Math.toDegrees(viewer.camera.pitch),
        roll: Cesium.Math.toDegrees(viewer.camera.roll)
      });
    });

    // クリックイベントのリスナー
    viewer.screenSpaceEventHandler.setInputAction((click) => {
      const cartesian = viewer.camera.pickEllipsoid(click.position);
      if (cartesian) {
        const cartographic = Cesium.Cartographic.fromCartesian(cartesian);
        sendToFlutter('mapClicked', {
          longitude: Cesium.Math.toDegrees(cartographic.longitude),
          latitude: Cesium.Math.toDegrees(cartographic.latitude),
          height: cartographic.height || 0
        });
      }
    }, Cesium.ScreenSpaceEventType.LEFT_CLICK);

    // 初期位置に移動（設定がある場合）
    if (config.center) {
      viewer.camera.flyTo({
        destination: Cesium.Cartesian3.fromDegrees(
          config.center.longitude,
          config.center.latitude,
          config.center.height || 1000
        ),
        duration: 0
      });
    }

    sendToFlutter('initialized', { success: true });
  } catch (error) {
    sendToFlutter('initializeError', { 
      success: false, 
      error: error.message 
    });
  }
}

/**
 * カメラを指定位置に移動
 * @param {Object} params - 移動先パラメータ
 */
function flyTo(params) {
  if (!viewer) return;

  viewer.camera.flyTo({
    destination: Cesium.Cartesian3.fromDegrees(
      params.longitude,
      params.latitude,
      params.height || 1000
    ),
    orientation: {
      heading: Cesium.Math.toRadians(params.heading || 0),
      pitch: Cesium.Math.toRadians(params.pitch || -45),
      roll: 0
    },
    duration: params.duration || 2
  });
}

/**
 * ベースマップレイヤーを追加
 * @param {Object} config - レイヤー設定
 */
async function addBaseMapLayer(config) {
  if (!viewer) return;

  let imageryProvider;
  // グローバルに保存されたAPIキーを使用
  const googleApiKey = config.apiKey || window._googleMapsApiKey || '';

  switch (config.provider) {
    case 'osm':
      imageryProvider = new Cesium.OpenStreetMapImageryProvider({
        url: 'https://a.tile.openstreetmap.org/'
      });
      break;

    case 'esriWorld':
      try {
        imageryProvider = await Cesium.ArcGisMapServerImageryProvider.fromUrl(
          'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer'
        );
      } catch (e) {
        console.warn('Failed to load ESRI World Imagery:', e);
      }
      break;

    case 'esriNatGeo':
      try {
        imageryProvider = await Cesium.ArcGisMapServerImageryProvider.fromUrl(
          'https://services.arcgisonline.com/ArcGIS/rest/services/NatGeo_World_Map/MapServer'
        );
      } catch (e) {
        console.warn('Failed to load ESRI NatGeo:', e);
      }
      break;

    case 'bing':
      try {
        imageryProvider = await Cesium.IonImageryProvider.fromAssetId(2);
      } catch (e) {
        console.warn('Failed to load Bing Maps:', e);
      }
      break;

    case 'google':
    case 'googleSatellite':
      // Google Maps衛星画像（APIキー不要のパブリックタイル）
      imageryProvider = new Cesium.UrlTemplateImageryProvider({
        url: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
        credit: new Cesium.Credit('Google Maps', false)
      });
      break;

    case 'googleRoad':
      // Google Mapsロードマップ
      imageryProvider = new Cesium.UrlTemplateImageryProvider({
        url: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
        credit: new Cesium.Credit('Google Maps', false)
      });
      break;

    case 'googleHybrid':
      // Google Mapsハイブリッド（衛星+ラベル）
      imageryProvider = new Cesium.UrlTemplateImageryProvider({
        url: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
        credit: new Cesium.Credit('Google Maps', false)
      });
      break;

    case 'custom':
      if (config.customUrl) {
        imageryProvider = new Cesium.UrlTemplateImageryProvider({
          url: config.customUrl
        });
      }
      break;

    default:
      console.warn('Unknown provider:', config.provider);
      return;
  }

  if (imageryProvider) {
    const layer = viewer.imageryLayers.addImageryProvider(imageryProvider);
    layer.alpha = config.opacity !== undefined ? config.opacity : 1.0;
    layer.show = config.visible !== undefined ? config.visible : true;

    imageryLayers.set(config.id, layer);
    sendToFlutter('baseMapAdded', { id: config.id, success: true });
  }
}

/**
 * ベースマップレイヤーを削除
 * @param {string} id - レイヤーID
 */
function removeBaseMapLayer(id) {
  if (!viewer) return;

  const layer = imageryLayers.get(id);
  if (layer) {
    viewer.imageryLayers.remove(layer);
    imageryLayers.delete(id);
    sendToFlutter('baseMapRemoved', { id: id });
  }
}

/**
 * ベースマップの不透明度を設定
 * @param {string} id - レイヤーID
 * @param {number} opacity - 不透明度（0.0〜1.0）
 */
function setBaseMapOpacity(id, opacity) {
  const layer = imageryLayers.get(id);
  if (layer) {
    layer.alpha = opacity;
  }
}

/**
 * ベースマップの表示/非表示を設定
 * @param {string} id - レイヤーID
 * @param {boolean} visible - 表示フラグ
 */
function setBaseMapVisible(id, visible) {
  const layer = imageryLayers.get(id);
  if (layer) {
    layer.show = visible;
  }
}

/**
 * すべてのベースマップをクリア
 */
function clearAllBaseMaps() {
  if (!viewer) return;

  viewer.imageryLayers.removeAll();
  imageryLayers.clear();
}

/**
 * ベースマップを変更（シンプル版 - 互換性のため）
 * @param {string} provider - プロバイダ名
 */
function setBaseMap(provider) {
  if (!viewer) return;

  clearAllBaseMaps();
  addBaseMapLayer({
    id: 'default_basemap',
    provider: provider,
    opacity: 1.0,
    visible: true
  });
}

/**
 * 2D/3D表示モードを切り替え
 * @param {string} mode - '2d' または '3d'
 */
function setSceneMode(mode) {
  if (!viewer) return;

  viewer.scene.mode = mode === '2d'
    ? Cesium.SceneMode.SCENE2D
    : Cesium.SceneMode.SCENE3D;
}

/**
 * 地形の表示/非表示を切り替え
 * @param {boolean} enabled - 有効フラグ
 */
async function setTerrainEnabled(enabled) {
  if (!viewer) return;

  if (enabled) {
    try {
      // CesiumJS 1.107以降の新しいAPI対応
      if (Cesium.Terrain && Cesium.Terrain.fromWorldTerrain) {
        viewer.scene.setTerrain(Cesium.Terrain.fromWorldTerrain());
      } else if (Cesium.createWorldTerrainAsync) {
        viewer.terrainProvider = await Cesium.createWorldTerrainAsync();
      }
    } catch (error) {
      console.warn('Failed to enable world terrain:', error);
    }
  } else {
    viewer.terrainProvider = new Cesium.EllipsoidTerrainProvider();
  }
}

/**
 * Flutterからのメッセージを処理
 * @param {string} method - メソッド名
 * @param {Object} params - パラメータ
 */
function handleFlutterMessage(method, params) {
  switch (method) {
    case 'initialize':
      initializeCesium(params);
      break;
    case 'flyTo':
      flyTo(params);
      break;
    case 'setBaseMap':
      setBaseMap(params.provider);
      break;
    case 'addBaseMapLayer':
      addBaseMapLayer(params);
      break;
    case 'removeBaseMapLayer':
      removeBaseMapLayer(params.id);
      break;
    case 'setBaseMapOpacity':
      setBaseMapOpacity(params.id, params.opacity);
      break;
    case 'setBaseMapVisible':
      setBaseMapVisible(params.id, params.visible);
      break;
    case 'clearAllBaseMaps':
      clearAllBaseMaps();
      break;
    case 'setSceneMode':
      setSceneMode(params.mode);
      break;
    case 'setTerrainEnabled':
      setTerrainEnabled(params.enabled);
      break;
    default:
      console.warn('Unknown method:', method);
  }
}

/**
 * Flutterへメッセージを送信
 * @param {string} event - イベント名
 * @param {Object} data - データ
 */
function sendToFlutter(event, data) {
  if (window.FlutterChannel) {
    window.FlutterChannel.postMessage(JSON.stringify({
      event: event,
      data: data
    }));
  } else {
    console.log('FlutterChannel not available. Event:', event, 'Data:', data);
  }
}

// グローバルに公開
window.CesiumBridge = {
  handleFlutterMessage,
  sendToFlutter
};
