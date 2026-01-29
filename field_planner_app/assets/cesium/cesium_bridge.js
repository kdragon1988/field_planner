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

// 3D Tileset管理
const tilesets = new Map();
let googleTileset = null;  // Google Photorealistic 3D Tiles参照

// 計測管理
const measurementEntities = new Map();
let measurementMode = null; // 'distance', 'area', 'height'
let measurementPoints = [];
let tempMeasurementEntity = null;
let tempPointEntities = [];

// 配置物管理
const placementEntities = new Map();
let placementMode = null; // 'place', 'move', 'rotate', 'scale'
let previewEntity = null;
let selectedPlacementId = null;
let currentPlacementAssetId = null;

// スナップ設定
const snapSettings = {
  gridEnabled: true,
  gridSize: 1.0, // メートル
  groundEnabled: true,
  angleEnabled: true,
  angleStep: 15, // 度
};

// ドローンフォーメーション管理
const droneFormations = new Map();

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
        googleTileset = await Cesium.Cesium3DTileset.fromIonAssetId(2275207);
        viewer.scene.primitives.add(googleTileset);
        tilesets.set('google_photorealistic', googleTileset);
        console.log('Google Photorealistic 3D Tiles loaded successfully');
      } catch (tilesError) {
        console.warn('Failed to load Google 3D Tiles:', tilesError);
        // フォールバック: Cesium OSM Buildings
        try {
          const osmBuildings = await Cesium.Cesium3DTileset.fromIonAssetId(96188);
          viewer.scene.primitives.add(osmBuildings);
          tilesets.set('cesium_osm_buildings', osmBuildings);
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

// ============================================
// 3D Tileset管理機能
// ============================================

/**
 * ローカルの3D Tilesを追加
 * @param {Object} config - Tileset設定
 * @param {string} config.id - TilesetのユニークID
 * @param {string} config.url - tileset.jsonのURL（file://プロトコル対応）
 * @param {string} config.name - 表示名
 * @param {number} config.opacity - 不透明度（0.0〜1.0）
 * @param {boolean} config.show - 表示フラグ
 */
async function addLocalTileset(config) {
  if (!viewer) {
    console.error('[CesiumBridge] Viewer not initialized');
    return;
  }

  try {
    console.log('[CesiumBridge] Loading local 3D Tileset:', config.url);

    let url = config.url;
    
    // 3D Tilesetを作成（高品質設定）
    // maximumScreenSpaceError: 値が小さいほど高解像度（デフォルト16、1-4で高品質）
    const tileset = await Cesium.Cesium3DTileset.fromUrl(url, {
      maximumScreenSpaceError: config.screenSpaceError || 2,  // 高品質設定
      maximumMemoryUsage: 2048,  // メモリ上限を増加
      skipLevelOfDetail: false,  // LODスキップを無効化（高品質）
      preferLeaves: true,  // 葉ノード（最高詳細）を優先
      dynamicScreenSpaceError: false,  // 動的SSE調整を無効化
      foveatedScreenSpaceError: false,  // フォビエイテッドレンダリングを無効化
      cullWithChildrenBounds: false,  // より正確なカリング
    });

    // スタイル設定
    if (config.opacity !== undefined && config.opacity < 1.0) {
      tileset.style = new Cesium.Cesium3DTileStyle({
        color: `color('white', ${config.opacity})`,
      });
    }

    tileset.show = config.show !== undefined ? config.show : true;

    // シーンに追加
    viewer.scene.primitives.add(tileset);
    tilesets.set(config.id, tileset);

    // Tilesetの準備完了を待つ（CesiumJS 1.104+では readyPromise は非推奨）
    // 代わりに tileset.ready を使用するか、直接バウンディングスフィアを取得
    const checkReady = () => {
      if (tileset.ready) {
        console.log('[CesiumBridge] Tileset ready:', config.id);

        // バウンディングボリュームを取得
        const boundingSphere = tileset.boundingSphere;
        const cartographic = Cesium.Cartographic.fromCartesian(boundingSphere.center);

        sendToFlutter('tilesetAdded', {
          id: config.id,
          name: config.name,
          success: true,
          center: {
            longitude: Cesium.Math.toDegrees(cartographic.longitude),
            latitude: Cesium.Math.toDegrees(cartographic.latitude),
            height: cartographic.height,
          },
          radius: boundingSphere.radius,
        });
      } else {
        // まだ準備中の場合は少し待って再チェック
        setTimeout(checkReady, 100);
      }
    };
    
    // 少し待ってからチェック開始
    setTimeout(checkReady, 500);

    console.log('[CesiumBridge] 3D Tileset added:', config.id);

  } catch (error) {
    console.error('[CesiumBridge] Failed to load 3D Tileset:', error);
    console.error('[CesiumBridge] Error details:', error.stack || error.toString());
    
    // より詳細なエラーメッセージを送信
    let errorMessage = error.message || error.toString() || 'Unknown error';
    if (error.stack) {
      console.error('[CesiumBridge] Stack:', error.stack);
    }
    
    // file://プロトコルの場合の追加メッセージ
    if (config.url && config.url.startsWith('file://')) {
      errorMessage += ' (Note: file:// protocol may have security restrictions in WebView)';
    }
    
    sendToFlutter('tilesetError', {
      id: config.id,
      error: errorMessage,
    });
  }
}

/**
 * 3D Tilesetを削除
 * @param {string} id - TilesetのID
 */
function removeTileset(id) {
  if (!viewer) return;

  const tileset = tilesets.get(id);
  if (tileset) {
    viewer.scene.primitives.remove(tileset);
    tilesets.delete(id);
    
    // クリッピングも削除
    removeGoogleTilesetClipping(id);
    
    console.log('[CesiumBridge] Tileset removed:', id);
    sendToFlutter('tilesetRemoved', { id: id });
  }
}

/**
 * Google 3D Tilesの処理モードを設定
 * NOTE: Google Photorealistic 3D TilesはClipping Planesをサポートしていません
 * 代替として以下のモードを提供:
 * - 'hide': Google 3D Tilesを完全に非表示
 * - 'lower': Google 3D Tilesの描画優先度を下げる（インポートモデルを手前に）
 * 
 * @param {string} tilesetId - 対象のTilesetのID
 * @param {string} mode - 処理モード ('hide' | 'lower')
 */
function setGoogleTilesetClipping(tilesetId, mode = 'hide') {
  if (!viewer || !googleTileset) {
    console.warn('[CesiumBridge] Google tileset not available');
    sendToFlutter('clippingError', { tilesetId: tilesetId, error: 'Google tileset not available' });
    return;
  }

  const tileset = tilesets.get(tilesetId);
  if (!tileset) {
    console.warn('[CesiumBridge] Tileset not found:', tilesetId);
    sendToFlutter('clippingError', { tilesetId: tilesetId, error: 'Tileset not found' });
    return;
  }

  console.log('[CesiumBridge] Google 3D Tiles does not support clipping.');
  console.log('[CesiumBridge] Using alternative mode: hide Google 3D Tiles');

  // Google 3D Tilesを非表示にする（最も確実な方法）
  googleTileset.show = false;

  console.log('[CesiumBridge] Google 3D Tiles hidden');
  sendToFlutter('clippingSet', { 
    tilesetId: tilesetId, 
    success: true,
    note: 'Google 3D Tiles hidden (clipping not supported)'
  });
}

/**
 * Google 3D Tilesを再表示
 * @param {string} tilesetId - 対象のTilesetのID（オプション）
 */
function removeGoogleTilesetClipping(tilesetId) {
  if (!googleTileset) return;

  googleTileset.show = true;
  console.log('[CesiumBridge] Google 3D Tiles shown');
}

/**
 * Tilesetの位置を調整
 * @param {Object} params - 調整パラメータ
 * @param {string} params.id - TilesetのID
 * @param {number} params.heightOffset - 高さオフセット（メートル）
 * @param {number} params.longitude - 経度オフセット（度）
 * @param {number} params.latitude - 緯度オフセット（度）
 * @param {number} params.heading - 方位角（度）
 * @param {number} params.pitch - ピッチ（度）
 * @param {number} params.roll - ロール（度）
 */
function adjustTilesetPosition(params) {
  if (!viewer) return;

  const tileset = tilesets.get(params.id);
  if (!tileset) {
    console.warn('[CesiumBridge] Tileset not found:', params.id);
    return;
  }

  try {
    // 現在のバウンディングスフィアの中心を取得
    const boundingSphere = tileset.boundingSphere;
    const cartographic = Cesium.Cartographic.fromCartesian(boundingSphere.center);

    // オフセットを適用した新しい位置を計算
    const newLongitude = cartographic.longitude + Cesium.Math.toRadians(params.longitude || 0);
    const newLatitude = cartographic.latitude + Cesium.Math.toRadians(params.latitude || 0);
    const newHeight = cartographic.height + (params.heightOffset || 0);

    // 新しい位置への変換行列を作成
    const newPosition = Cesium.Cartesian3.fromRadians(newLongitude, newLatitude, newHeight);

    // 回転を適用
    const heading = Cesium.Math.toRadians(params.heading || 0);
    const pitch = Cesium.Math.toRadians(params.pitch || 0);
    const roll = Cesium.Math.toRadians(params.roll || 0);
    const hpr = new Cesium.HeadingPitchRoll(heading, pitch, roll);

    // 変換行列を計算
    const modelMatrix = Cesium.Transforms.headingPitchRollToFixedFrame(
      newPosition,
      hpr,
      Cesium.Ellipsoid.WGS84,
      Cesium.Transforms.localFrameToFixedFrameGenerator('east', 'north')
    );

    // 元の位置からのオフセット行列を計算
    const originalCenter = boundingSphere.center;
    const offset = Cesium.Cartesian3.subtract(newPosition, originalCenter, new Cesium.Cartesian3());

    // modelMatrixを更新（高さオフセットのみの簡易版）
    if (params.heightOffset !== undefined && params.heightOffset !== 0) {
      const surface = Cesium.Cartesian3.fromRadians(
        cartographic.longitude, 
        cartographic.latitude, 
        0
      );
      const offset = Cesium.Cartesian3.fromRadians(
        cartographic.longitude, 
        cartographic.latitude, 
        params.heightOffset
      );
      
      const translation = Cesium.Cartesian3.subtract(offset, surface, new Cesium.Cartesian3());
      tileset.modelMatrix = Cesium.Matrix4.fromTranslation(translation);
    }

    console.log('[CesiumBridge] Tileset position adjusted:', params.id);
    sendToFlutter('tilesetPositionAdjusted', { 
      id: params.id,
      heightOffset: params.heightOffset,
    });

  } catch (error) {
    console.error('[CesiumBridge] Failed to adjust position:', error);
  }
}

/**
 * Tilesetの画質（LOD）を調整
 * @param {Object} params - 調整パラメータ
 * @param {string} params.id - TilesetのID
 * @param {number} params.screenSpaceError - Screen Space Error（1-64、小さいほど高画質）
 */
function adjustTilesetQuality(params) {
  if (!viewer) return;

  const tileset = tilesets.get(params.id);
  if (!tileset) {
    console.warn('[CesiumBridge] Tileset not found:', params.id);
    return;
  }

  if (params.screenSpaceError !== undefined) {
    tileset.maximumScreenSpaceError = params.screenSpaceError;
    console.log('[CesiumBridge] Tileset quality adjusted:', params.id, 'SSE:', params.screenSpaceError);
  }

  sendToFlutter('tilesetQualityAdjusted', { 
    id: params.id,
    screenSpaceError: params.screenSpaceError,
  });
}

/**
 * 3D Tilesetの表示/非表示を切り替え
 * @param {string} id - TilesetのID
 * @param {boolean} visible - 表示フラグ
 */
function setTilesetVisible(id, visible) {
  const tileset = tilesets.get(id);
  if (tileset) {
    tileset.show = visible;
    console.log('[CesiumBridge] Tileset visibility changed:', id, visible);
  }
}

/**
 * 3D Tilesetの不透明度を設定
 * @param {string} id - TilesetのID
 * @param {number} opacity - 不透明度（0.0〜1.0）
 */
function setTilesetOpacity(id, opacity) {
  const tileset = tilesets.get(id);
  if (tileset) {
    tileset.style = new Cesium.Cesium3DTileStyle({
      color: `color('white', ${opacity})`,
    });
    console.log('[CesiumBridge] Tileset opacity changed:', id, opacity);
  }
}

/**
 * Google Photorealistic 3D Tiles の表示/非表示を切り替え
 * @param {boolean} visible - 表示フラグ
 */
function setGoogleTilesetVisible(visible) {
  if (googleTileset) {
    googleTileset.show = visible;
    console.log('[CesiumBridge] Google 3D Tiles visibility:', visible);
    sendToFlutter('googleTilesetVisibilityChanged', { visible: visible });
  } else {
    // 他の3D Tilesを探す
    const cesiumOsmBuildings = tilesets.get('cesium_osm_buildings');
    if (cesiumOsmBuildings) {
      cesiumOsmBuildings.show = visible;
      console.log('[CesiumBridge] Cesium OSM Buildings visibility:', visible);
    }
  }
}

/**
 * 3D Tilesetの位置にカメラを移動
 * @param {string} id - TilesetのID
 */
function flyToTileset(id) {
  if (!viewer) return;

  const tileset = tilesets.get(id);
  if (tileset) {
    viewer.flyTo(tileset, {
      duration: 2,
      offset: new Cesium.HeadingPitchRange(
        0,
        Cesium.Math.toRadians(-45),
        0
      ),
    });
    console.log('[CesiumBridge] Flying to tileset:', id);
  }
}

/**
 * すべてのカスタム3D Tilesetsを取得
 * @returns {Array} Tileset情報の配列
 */
function getAllCustomTilesets() {
  const result = [];
  tilesets.forEach((tileset, id) => {
    // Google/OSM以外のカスタムTileset
    if (id !== 'google_photorealistic' && id !== 'cesium_osm_buildings') {
      result.push({
        id: id,
        show: tileset.show,
      });
    }
  });
  return result;
}

// ============================================
// 計測機能
// ============================================

/**
 * 計測モードを開始
 * @param {string} type - 計測タイプ ('distance', 'area', 'height')
 */
function startMeasurementMode(type) {
  console.log('[CesiumBridge] startMeasurementMode called with type:', type);
  
  if (!viewer) {
    console.error('[CesiumBridge] Viewer not initialized');
    return;
  }
  
  try {
    // 既存の計測をクリーンアップ
    cleanupTempMeasurement();
    
    measurementMode = type;
    measurementPoints = [];
    
    console.log('[CesiumBridge] Creating temp entity for type:', type);
    
    // 既存の一時エンティティを削除（念のため）
    const existingTemp = viewer.entities.getById('temp_measurement');
    if (existingTemp) {
      viewer.entities.remove(existingTemp);
    }
    
    // 一時エンティティを作成（ライン/ポリゴンプレビュー用）
    if (type === 'area') {
      tempMeasurementEntity = viewer.entities.add({
        id: 'temp_measurement',
        polygon: {
          hierarchy: new Cesium.CallbackProperty(() => {
            if (measurementPoints.length < 3) {
              return new Cesium.PolygonHierarchy([]);
            }
            return new Cesium.PolygonHierarchy(
              measurementPoints.map(p => 
                Cesium.Cartesian3.fromDegrees(p.longitude, p.latitude, p.height || 0)
              )
            );
          }, false),
          material: Cesium.Color.YELLOW.withAlpha(0.3),
          outline: true,
          outlineColor: Cesium.Color.YELLOW,
          outlineWidth: 3,
        },
      });
    } else {
      tempMeasurementEntity = viewer.entities.add({
        id: 'temp_measurement',
        polyline: {
          positions: new Cesium.CallbackProperty(() => {
            return measurementPoints.map(p => 
              Cesium.Cartesian3.fromDegrees(p.longitude, p.latitude, p.height || 0)
            );
          }, false),
          width: 3,
          material: Cesium.Color.YELLOW,
          clampToGround: type !== 'height',
        },
      });
    }
    
    console.log('[CesiumBridge] Setting up click handler for measurement');
    
    // クリックイベント（計測モード用）
    viewer.screenSpaceEventHandler.setInputAction((click) => {
      console.log('[CesiumBridge] Measurement click detected, mode:', measurementMode);
      if (!measurementMode) {
        console.log('[CesiumBridge] No measurement mode active, ignoring');
        return;
      }
      
      const position = getGroundPosition(click.position);
      console.log('[CesiumBridge] Ground position:', position);
      
      if (position) {
        const cartographic = Cesium.Cartographic.fromCartesian(position);
        const point = {
          longitude: Cesium.Math.toDegrees(cartographic.longitude),
          latitude: Cesium.Math.toDegrees(cartographic.latitude),
          height: cartographic.height || 0,
        };
        
        measurementPoints.push(point);
        console.log('[CesiumBridge] Added point, total points:', measurementPoints.length);
        
        // ポイントマーカーを追加
        try {
          const pointEntity = viewer.entities.add({
            position: position,
            point: {
              pixelSize: 10,
              color: Cesium.Color.YELLOW,
              outlineColor: Cesium.Color.BLACK,
              outlineWidth: 2,
            },
          });
          tempPointEntities.push(pointEntity);
        } catch (e) {
          console.warn('[CesiumBridge] Failed to add point marker:', e);
        }
        
        // 高さ計測は2点で自動完了
        if (measurementMode === 'height' && measurementPoints.length === 2) {
          finishMeasurement();
          return;
        }
        
        const currentValue = calculateMeasurement();
        console.log('[CesiumBridge] Current value:', currentValue);
        
        sendToFlutter('measurementPointAdded', {
          points: measurementPoints,
          currentValue: currentValue,
          unit: getMeasurementUnit(),
        });
      }
    }, Cesium.ScreenSpaceEventType.LEFT_CLICK);
    
    // ダブルクリックで確定
    viewer.screenSpaceEventHandler.setInputAction(() => {
      console.log('[CesiumBridge] Double click detected for measurement finish');
      if (!measurementMode) return;
      if (measurementMode === 'distance' && measurementPoints.length >= 2) {
        finishMeasurement();
      } else if (measurementMode === 'area' && measurementPoints.length >= 3) {
        finishMeasurement();
      }
    }, Cesium.ScreenSpaceEventType.LEFT_DOUBLE_CLICK);
    
    // 右クリックでキャンセル
    viewer.screenSpaceEventHandler.setInputAction(() => {
      console.log('[CesiumBridge] Right click - canceling measurement');
      cancelMeasurement();
    }, Cesium.ScreenSpaceEventType.RIGHT_CLICK);
    
    // Enterキーで確定
    setupMeasurementKeyboardHandler();
    
    console.log('[CesiumBridge] Measurement mode started successfully');
    sendToFlutter('measurementModeStarted', { type: type });
    
  } catch (error) {
    console.error('[CesiumBridge] Error starting measurement mode:', error);
    sendToFlutter('measurementError', { error: error.message });
  }
}

/**
 * 地面の位置を取得
 * @param {Cesium.Cartesian2} screenPosition - スクリーン座標
 * @returns {Cesium.Cartesian3|null} 地面の位置
 */
function getGroundPosition(screenPosition) {
  if (!viewer) return null;
  
  try {
    // 地形がある場合は地形との交点を取得
    const ray = viewer.camera.getPickRay(screenPosition);
    if (!ray) {
      console.log('[CesiumBridge] No pick ray available');
      return null;
    }
    
    // まず地形との交点を試す
    const terrainPosition = viewer.scene.globe.pick(ray, viewer.scene);
    if (terrainPosition) {
      console.log('[CesiumBridge] Got terrain position');
      return terrainPosition;
    }
    
    // 地形がない場合は楕円体との交点
    const ellipsoidPosition = viewer.camera.pickEllipsoid(screenPosition);
    console.log('[CesiumBridge] Got ellipsoid position:', ellipsoidPosition ? 'yes' : 'no');
    return ellipsoidPosition;
  } catch (e) {
    console.error('[CesiumBridge] Error in getGroundPosition:', e);
    return null;
  }
}

// 計測用キーボードハンドラ
let measurementKeyboardHandler = null;

/**
 * 計測用キーボードハンドラを設定
 */
function setupMeasurementKeyboardHandler() {
  // 既存のハンドラを削除
  removeMeasurementKeyboardHandler();
  
  measurementKeyboardHandler = (event) => {
    if (event.key === 'Enter' && measurementMode) {
      console.log('[CesiumBridge] Enter pressed - finishing measurement');
      
      // 最小ポイント数をチェック
      if (measurementMode === 'distance' && measurementPoints.length >= 2) {
        finishMeasurement();
      } else if (measurementMode === 'area' && measurementPoints.length >= 3) {
        finishMeasurement();
      } else if (measurementMode === 'height' && measurementPoints.length >= 2) {
        finishMeasurement();
      }
    } else if (event.key === 'Escape' && measurementMode) {
      console.log('[CesiumBridge] Escape pressed - canceling measurement');
      cancelMeasurement();
    }
  };
  
  document.addEventListener('keydown', measurementKeyboardHandler);
}

/**
 * 計測用キーボードハンドラを削除
 */
function removeMeasurementKeyboardHandler() {
  if (measurementKeyboardHandler) {
    document.removeEventListener('keydown', measurementKeyboardHandler);
    measurementKeyboardHandler = null;
  }
}

/**
 * 計測を確定
 */
function finishMeasurement() {
  console.log('[CesiumBridge] finishMeasurement called, mode:', measurementMode);
  
  if (!measurementMode) {
    console.log('[CesiumBridge] No measurement mode, skipping finish');
    return;
  }
  
  try {
    const value = calculateMeasurement();
    const unit = getMeasurementUnit();
    const type = measurementMode;
    const points = [...measurementPoints]; // コピーを作成
    
    console.log('[CesiumBridge] Measurement completed:', { type, value, unit, pointCount: points.length });
    
    sendToFlutter('measurementCompleted', {
      type: type,
      points: points,
      value: value,
      unit: unit,
    });
    
    cleanupTempMeasurement();
    resetMeasurementEventHandlers();
    measurementMode = null;
  } catch (e) {
    console.error('[CesiumBridge] Error in finishMeasurement:', e);
  }
}

/**
 * 計測をキャンセル
 */
function cancelMeasurement() {
  console.log('[CesiumBridge] cancelMeasurement called, mode:', measurementMode);
  
  const wasMode = measurementMode;
  
  try {
    cleanupTempMeasurement();
    resetMeasurementEventHandlers();
    measurementMode = null;
    measurementPoints = [];
    
    if (wasMode) {
      sendToFlutter('measurementCancelled', {});
    }
  } catch (e) {
    console.error('[CesiumBridge] Error in cancelMeasurement:', e);
    measurementMode = null;
    measurementPoints = [];
  }
}

/**
 * 計測用イベントハンドラをリセット
 */
function resetMeasurementEventHandlers() {
  console.log('[CesiumBridge] resetMeasurementEventHandlers called');
  
  // キーボードハンドラを削除
  removeMeasurementKeyboardHandler();
  
  if (!viewer) {
    console.log('[CesiumBridge] No viewer, skipping reset');
    return;
  }
  
  try {
    // クリックイベントを通常のmapClickedに戻す
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
    
    // ダブルクリックと右クリックを削除
    viewer.screenSpaceEventHandler.removeInputAction(Cesium.ScreenSpaceEventType.LEFT_DOUBLE_CLICK);
    viewer.screenSpaceEventHandler.removeInputAction(Cesium.ScreenSpaceEventType.RIGHT_CLICK);
    
    console.log('[CesiumBridge] Event handlers reset to default');
  } catch (e) {
    console.error('[CesiumBridge] Error in resetMeasurementEventHandlers:', e);
  }
}

/**
 * 一時エンティティをクリーンアップ
 */
function cleanupTempMeasurement() {
  console.log('[CesiumBridge] cleanupTempMeasurement called');
  
  if (!viewer) {
    console.log('[CesiumBridge] No viewer, skipping cleanup');
    tempMeasurementEntity = null;
    tempPointEntities = [];
    measurementPoints = [];
    return;
  }
  
  try {
    if (tempMeasurementEntity) {
      viewer.entities.remove(tempMeasurementEntity);
      tempMeasurementEntity = null;
    }
    
    // ポイントマーカーを削除
    tempPointEntities.forEach(entity => {
      try {
        viewer.entities.remove(entity);
      } catch (e) {
        console.warn('[CesiumBridge] Failed to remove point entity:', e);
      }
    });
    tempPointEntities = [];
    measurementPoints = [];
  } catch (e) {
    console.error('[CesiumBridge] Error in cleanupTempMeasurement:', e);
    tempMeasurementEntity = null;
    tempPointEntities = [];
    measurementPoints = [];
  }
}

/**
 * 計測値を計算
 * @returns {number} 計測値
 */
function calculateMeasurement() {
  if (measurementPoints.length < 2) return 0;
  
  switch (measurementMode) {
    case 'distance':
      return calculateDistance();
    case 'area':
      return calculateArea();
    case 'height':
      return calculateHeight();
    default:
      return 0;
  }
}

/**
 * 距離を計算（メートル）
 * @returns {number} 距離（メートル）
 */
function calculateDistance() {
  let totalDistance = 0;
  
  for (let i = 0; i < measurementPoints.length - 1; i++) {
    const p1 = measurementPoints[i];
    const p2 = measurementPoints[i + 1];
    
    const geodesic = new Cesium.EllipsoidGeodesic(
      Cesium.Cartographic.fromDegrees(p1.longitude, p1.latitude),
      Cesium.Cartographic.fromDegrees(p2.longitude, p2.latitude)
    );
    
    // 水平距離
    const horizontalDistance = geodesic.surfaceDistance;
    
    // 高さの差
    const heightDiff = (p2.height || 0) - (p1.height || 0);
    
    // 3D距離
    totalDistance += Math.sqrt(
      horizontalDistance * horizontalDistance + heightDiff * heightDiff
    );
  }
  
  return totalDistance;
}

/**
 * 面積を計算（平方メートル）
 * @returns {number} 面積（平方メートル）
 */
function calculateArea() {
  if (measurementPoints.length < 3) return 0;
  
  const positions = measurementPoints.map(p => 
    Cesium.Cartographic.fromDegrees(p.longitude, p.latitude)
  );
  
  // 球面多角形の面積計算（簡易実装：平面近似）
  let area = 0;
  const n = positions.length;
  
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n;
    
    // 緯度経度をメートル座標に変換（近似）
    const avgLat = (positions[i].latitude + positions[j].latitude) / 2;
    const x1 = positions[i].longitude * 111320 * Math.cos(avgLat);
    const y1 = positions[i].latitude * 110540;
    const x2 = positions[j].longitude * 111320 * Math.cos(avgLat);
    const y2 = positions[j].latitude * 110540;
    
    area += x1 * y2 - x2 * y1;
  }
  
  return Math.abs(area) / 2;
}

/**
 * 高さ/標高差を計算（メートル）
 * @returns {number} 高さ（メートル）
 */
function calculateHeight() {
  if (measurementPoints.length < 2) return 0;
  
  const p1 = measurementPoints[0];
  const p2 = measurementPoints[1];
  
  return Math.abs((p2.height || 0) - (p1.height || 0));
}

/**
 * 計測単位を取得
 * @returns {string} 単位
 */
function getMeasurementUnit() {
  switch (measurementMode) {
    case 'distance':
      return 'm';
    case 'area':
      return 'm²';
    case 'height':
      return 'm';
    default:
      return '';
  }
}

/**
 * 計測結果を表示
 * @param {Object} measurement - 計測データ
 */
function addMeasurementDisplay(measurement) {
  const positions = measurement.points.map(p => 
    Cesium.Cartesian3.fromDegrees(p.longitude, p.latitude, p.height || 0)
  );
  
  const color = Cesium.Color.fromCssColorString(measurement.color || '#FF0000');
  const lineWidth = measurement.lineWidth || 2;
  
  let entity;
  
  if (measurement.type === 'area') {
    // ポリゴン（面積計測）
    entity = viewer.entities.add({
      id: measurement.id,
      name: measurement.name,
      polygon: {
        hierarchy: new Cesium.PolygonHierarchy(positions),
        material: color.withAlpha(0.3),
        outline: true,
        outlineColor: color,
        outlineWidth: lineWidth,
      },
      position: getCentroid(positions),
      label: {
        text: `${measurement.name}\n${formatMeasurementValue(measurement.value, measurement.unit)}`,
        font: '14px sans-serif',
        fillColor: Cesium.Color.WHITE,
        outlineColor: Cesium.Color.BLACK,
        outlineWidth: 2,
        style: Cesium.LabelStyle.FILL_AND_OUTLINE,
        verticalOrigin: Cesium.VerticalOrigin.CENTER,
        horizontalOrigin: Cesium.HorizontalOrigin.CENTER,
        pixelOffset: new Cesium.Cartesian2(0, 0),
        disableDepthTestDistance: Number.POSITIVE_INFINITY,
      },
    });
  } else {
    // ポリライン（距離/高さ計測）
    const midPosition = getMidpoint(positions);
    
    entity = viewer.entities.add({
      id: measurement.id,
      name: measurement.name,
      polyline: {
        positions: positions,
        width: lineWidth,
        material: color,
        clampToGround: measurement.type !== 'height',
      },
      position: midPosition,
      label: {
        text: `${measurement.name}\n${formatMeasurementValue(measurement.value, measurement.unit)}`,
        font: '14px sans-serif',
        fillColor: Cesium.Color.WHITE,
        outlineColor: Cesium.Color.BLACK,
        outlineWidth: 2,
        style: Cesium.LabelStyle.FILL_AND_OUTLINE,
        verticalOrigin: Cesium.VerticalOrigin.BOTTOM,
        pixelOffset: new Cesium.Cartesian2(0, -10),
        disableDepthTestDistance: Number.POSITIVE_INFINITY,
      },
    });
    
    // 端点マーカー
    positions.forEach((pos, i) => {
      viewer.entities.add({
        id: `${measurement.id}_point_${i}`,
        position: pos,
        point: {
          pixelSize: 8,
          color: color,
          outlineColor: Cesium.Color.WHITE,
          outlineWidth: 2,
        },
      });
    });
  }
  
  measurementEntities.set(measurement.id, entity);
}

/**
 * 計測値をフォーマット
 * @param {number} value - 計測値
 * @param {string} unit - 単位
 * @returns {string} フォーマット済み文字列
 */
function formatMeasurementValue(value, unit) {
  if (unit === 'm²' && value >= 10000) {
    return `${(value / 10000).toFixed(2)} ha`;
  } else if (unit === 'm' && value >= 1000) {
    return `${(value / 1000).toFixed(2)} km`;
  }
  return `${value.toFixed(2)} ${unit}`;
}

/**
 * 計測結果を削除
 * @param {string} measurementId - 計測ID
 */
function removeMeasurementDisplay(measurementId) {
  const entity = measurementEntities.get(measurementId);
  if (entity) {
    viewer.entities.remove(entity);
    measurementEntities.delete(measurementId);
    
    // 端点マーカーも削除
    let i = 0;
    while (true) {
      const pointEntity = viewer.entities.getById(`${measurementId}_point_${i}`);
      if (!pointEntity) break;
      viewer.entities.remove(pointEntity);
      i++;
    }
  }
}

/**
 * 計測結果の表示/非表示を切り替え
 * @param {string} measurementId - 計測ID
 * @param {boolean} visible - 表示フラグ
 */
function setMeasurementVisible(measurementId, visible) {
  const entity = measurementEntities.get(measurementId);
  if (entity) {
    entity.show = visible;
    
    // 端点マーカーも更新
    let i = 0;
    while (true) {
      const pointEntity = viewer.entities.getById(`${measurementId}_point_${i}`);
      if (!pointEntity) break;
      pointEntity.show = visible;
      i++;
    }
  }
}

/**
 * すべての計測結果をクリア
 */
function clearAllMeasurements() {
  measurementEntities.forEach((entity, id) => {
    removeMeasurementDisplay(id);
  });
  measurementEntities.clear();
}

// ============================================
// 計測結果の編集機能
// ============================================

// 編集モード管理
let editingMeasurementId = null;
let editingPointIndex = null;
let editDragHandler = null;

/**
 * 計測結果のスタイルを更新
 * @param {Object} params - {measurementId, color, fillOpacity, lineWidth}
 */
function updateMeasurementStyle(params) {
  const { measurementId, color, fillOpacity, lineWidth } = params;
  const entity = measurementEntities.get(measurementId);
  
  if (!entity) {
    console.warn('[CesiumBridge] Measurement not found:', measurementId);
    return;
  }
  
  try {
    const cesiumColor = Cesium.Color.fromCssColorString(color);
    
    if (entity.polygon) {
      // ポリゴン（面積計測）
      entity.polygon.material = cesiumColor.withAlpha(fillOpacity);
      entity.polygon.outlineColor = cesiumColor;
      if (lineWidth !== undefined) {
        entity.polygon.outlineWidth = lineWidth;
      }
    }
    
    if (entity.polyline) {
      // ポリライン（距離/高さ計測）
      entity.polyline.material = cesiumColor;
      if (lineWidth !== undefined) {
        entity.polyline.width = lineWidth;
      }
    }
    
    // 端点マーカーの色も更新
    let i = 0;
    while (true) {
      const pointEntity = viewer.entities.getById(`${measurementId}_point_${i}`);
      if (!pointEntity) break;
      if (pointEntity.point) {
        pointEntity.point.color = cesiumColor;
      }
      i++;
    }
    
    console.log('[CesiumBridge] Style updated for:', measurementId);
    sendToFlutter('measurementStyleUpdated', { measurementId });
  } catch (e) {
    console.error('[CesiumBridge] Error updating style:', e);
  }
}

/**
 * 計測結果を完全に更新（ポイント変更を含む）
 * @param {Object} measurement - 計測データ
 */
function updateMeasurementDisplay(measurement) {
  console.log('[CesiumBridge] Updating measurement display:', measurement.id);
  
  // 既存のエンティティを削除
  removeMeasurementDisplay(measurement.id);
  
  // 新しいエンティティを追加
  addMeasurementDisplay(measurement);
}

/**
 * 計測ポイント編集モードを開始
 * @param {string} measurementId - 計測ID
 */
function startMeasurementEditMode(measurementId) {
  console.log('[CesiumBridge] Starting edit mode for:', measurementId);
  
  // 既存の編集モードを終了
  if (editingMeasurementId) {
    endMeasurementEditMode();
  }
  
  const entity = measurementEntities.get(measurementId);
  if (!entity) {
    console.warn('[CesiumBridge] Measurement not found:', measurementId);
    return;
  }
  
  editingMeasurementId = measurementId;
  
  // 編集用のポイントマーカーをハイライト
  let i = 0;
  while (true) {
    const pointEntity = viewer.entities.getById(`${measurementId}_point_${i}`);
    if (!pointEntity) break;
    if (pointEntity.point) {
      pointEntity.point.pixelSize = 14;
      pointEntity.point.outlineColor = Cesium.Color.CYAN;
      pointEntity.point.outlineWidth = 3;
    }
    i++;
  }
  
  // ドラッグハンドラを設定
  setupPointDragHandler(measurementId);
  
  sendToFlutter('measurementEditModeStarted', { measurementId });
}

/**
 * 計測ポイント編集モードを終了
 */
function endMeasurementEditMode() {
  console.log('[CesiumBridge] Ending edit mode');
  
  if (editingMeasurementId) {
    // ポイントマーカーを通常に戻す
    let i = 0;
    while (true) {
      const pointEntity = viewer.entities.getById(`${editingMeasurementId}_point_${i}`);
      if (!pointEntity) break;
      if (pointEntity.point) {
        pointEntity.point.pixelSize = 8;
        pointEntity.point.outlineColor = Cesium.Color.WHITE;
        pointEntity.point.outlineWidth = 2;
      }
      i++;
    }
  }
  
  // ドラッグハンドラを削除
  if (editDragHandler) {
    editDragHandler.destroy();
    editDragHandler = null;
  }
  
  // キーボードハンドラを削除
  removeEditKeyboardHandler();
  
  // カメラコントロールを確実に有効に戻す
  viewer.scene.screenSpaceCameraController.enableRotate = true;
  viewer.scene.screenSpaceCameraController.enableTranslate = true;
  viewer.scene.screenSpaceCameraController.enableZoom = true;
  viewer.scene.screenSpaceCameraController.enableTilt = true;
  viewer.scene.screenSpaceCameraController.enableLook = true;
  
  const wasEditing = editingMeasurementId;
  editingMeasurementId = null;
  editingPointIndex = null;
  
  if (wasEditing) {
    sendToFlutter('measurementEditModeEnded', { measurementId: wasEditing });
  }
}

/**
 * ポイントドラッグハンドラを設定
 * @param {string} measurementId - 計測ID
 */
function setupPointDragHandler(measurementId) {
  if (editDragHandler) {
    editDragHandler.destroy();
  }
  
  editDragHandler = new Cesium.ScreenSpaceEventHandler(viewer.canvas);
  
  let draggedEntity = null;
  let draggedPointIndex = null;
  
  // マウスダウン - ドラッグ開始
  editDragHandler.setInputAction((click) => {
    const pickedObject = viewer.scene.pick(click.position);
    
    if (Cesium.defined(pickedObject) && pickedObject.id) {
      const entityId = pickedObject.id.id || pickedObject.id;
      
      // 計測ポイントかチェック
      if (typeof entityId === 'string' && entityId.startsWith(measurementId + '_point_')) {
        const pointIndex = parseInt(entityId.split('_point_')[1]);
        draggedEntity = pickedObject.id;
        draggedPointIndex = pointIndex;
        editingPointIndex = pointIndex;
        
        // カメラの操作を無効化
        viewer.scene.screenSpaceCameraController.enableRotate = false;
        viewer.scene.screenSpaceCameraController.enableTranslate = false;
        viewer.scene.screenSpaceCameraController.enableZoom = false;
        
        console.log('[CesiumBridge] Started dragging point:', pointIndex);
      }
    }
  }, Cesium.ScreenSpaceEventType.LEFT_DOWN);
  
  // マウス移動 - ドラッグ中
  editDragHandler.setInputAction((movement) => {
    if (!draggedEntity) return;
    
    const position = getGroundPosition(movement.endPosition);
    if (position) {
      draggedEntity.position = position;
    }
  }, Cesium.ScreenSpaceEventType.MOUSE_MOVE);
  
  // マウスアップ - ドラッグ終了
  editDragHandler.setInputAction((click) => {
    // カメラの操作を常に有効化（ドラッグ中でなくても）
    viewer.scene.screenSpaceCameraController.enableRotate = true;
    viewer.scene.screenSpaceCameraController.enableTranslate = true;
    viewer.scene.screenSpaceCameraController.enableZoom = true;
    
    if (!draggedEntity) return;
    
    // 新しい位置を取得
    const position = draggedEntity.position.getValue(Cesium.JulianDate.now());
    if (position) {
      const cartographic = Cesium.Cartographic.fromCartesian(position);
      const newPoint = {
        longitude: Cesium.Math.toDegrees(cartographic.longitude),
        latitude: Cesium.Math.toDegrees(cartographic.latitude),
        height: cartographic.height || 0,
      };
      
      console.log('[CesiumBridge] Point moved to:', newPoint);
      
      sendToFlutter('measurementPointMoved', {
        measurementId: measurementId,
        pointIndex: draggedPointIndex,
        newPoint: newPoint,
      });
    }
    
    draggedEntity = null;
    draggedPointIndex = null;
  }, Cesium.ScreenSpaceEventType.LEFT_UP);
  
  // 右クリック - ポイント削除
  editDragHandler.setInputAction((click) => {
    const pickedObject = viewer.scene.pick(click.position);
    
    if (Cesium.defined(pickedObject) && pickedObject.id) {
      const entityId = pickedObject.id.id || pickedObject.id;
      
      // 計測ポイントかチェック
      if (typeof entityId === 'string' && entityId.startsWith(measurementId + '_point_')) {
        const pointIndex = parseInt(entityId.split('_point_')[1]);
        
        console.log('[CesiumBridge] Deleting point:', pointIndex);
        
        sendToFlutter('measurementPointDeleted', {
          measurementId: measurementId,
          pointIndex: pointIndex,
        });
      }
    }
  }, Cesium.ScreenSpaceEventType.RIGHT_CLICK);
  
  // キーボードイベント - Enterで編集終了
  setupEditKeyboardHandler();
}

// キーボードハンドラ
let editKeyboardHandler = null;

/**
 * 編集用キーボードハンドラを設定
 */
function setupEditKeyboardHandler() {
  // 既存のハンドラを削除
  if (editKeyboardHandler) {
    document.removeEventListener('keydown', editKeyboardHandler);
  }
  
  editKeyboardHandler = (event) => {
    if (event.key === 'Enter' && editingMeasurementId) {
      console.log('[CesiumBridge] Enter pressed - ending edit mode');
      endMeasurementEditMode();
    }
  };
  
  document.addEventListener('keydown', editKeyboardHandler);
}

/**
 * 編集用キーボードハンドラを削除
 */
function removeEditKeyboardHandler() {
  if (editKeyboardHandler) {
    document.removeEventListener('keydown', editKeyboardHandler);
    editKeyboardHandler = null;
  }
}

/**
 * カメラコントロールをリセット（有効化）
 * マップ操作ができなくなった場合の緊急リセット用
 */
function resetCameraControls() {
  console.log('[CesiumBridge] Resetting camera controls');
  viewer.scene.screenSpaceCameraController.enableRotate = true;
  viewer.scene.screenSpaceCameraController.enableTranslate = true;
  viewer.scene.screenSpaceCameraController.enableZoom = true;
  viewer.scene.screenSpaceCameraController.enableTilt = true;
  viewer.scene.screenSpaceCameraController.enableLook = true;
  
  // 編集モードも終了
  if (editingMeasurementId) {
    endMeasurementEditMode();
  }
  
  sendToFlutter('cameraControlsReset', {});
}

/**
 * 中点を取得
 * @param {Array} positions - 位置配列
 * @returns {Cesium.Cartesian3} 中点
 */
function getMidpoint(positions) {
  if (positions.length === 0) return Cesium.Cartesian3.ZERO;
  if (positions.length === 1) return positions[0];
  
  const midIndex = Math.floor((positions.length - 1) / 2);
  return positions[midIndex];
}

/**
 * 重心を取得
 * @param {Array} positions - 位置配列
 * @returns {Cesium.Cartesian3} 重心
 */
function getCentroid(positions) {
  if (positions.length === 0) return Cesium.Cartesian3.ZERO;
  
  let x = 0, y = 0, z = 0;
  positions.forEach(p => {
    x += p.x;
    y += p.y;
    z += p.z;
  });
  
  return new Cesium.Cartesian3(
    x / positions.length,
    y / positions.length,
    z / positions.length
  );
}

// ============================================
// 配置物管理機能
// ============================================

/**
 * 配置物を追加
 * @param {Object} placement - 配置物データ
 * @param {string} modelUrl - モデルURL
 */
function addPlacement(placement, modelUrl) {
  if (!viewer) return;

  const position = Cesium.Cartesian3.fromDegrees(
    placement.position.longitude,
    placement.position.latitude,
    placement.position.height || 0
  );

  const heading = Cesium.Math.toRadians(placement.rotation?.heading || 0);
  const pitch = Cesium.Math.toRadians(placement.rotation?.pitch || 0);
  const roll = Cesium.Math.toRadians(placement.rotation?.roll || 0);
  const orientation = Cesium.Transforms.headingPitchRollQuaternion(
    position,
    new Cesium.HeadingPitchRoll(heading, pitch, roll)
  );

  const scale = placement.scale?.x || 1.0;

  const entity = viewer.entities.add({
    id: placement.id,
    name: placement.name,
    position: position,
    orientation: orientation,
    model: {
      uri: modelUrl,
      scale: scale,
      minimumPixelSize: 64,
      maximumScale: 20000,
    },
    show: placement.visible !== false,
  });

  placementEntities.set(placement.id, {
    entity: entity,
    placement: placement,
    modelUrl: modelUrl,
  });

  console.log('[CesiumBridge] Placement added:', placement.id);
  sendToFlutter('placementAdded', { id: placement.id });
}

/**
 * 配置物を削除
 * @param {string} placementId - 配置物ID
 */
function removePlacement(placementId) {
  if (!viewer) return;

  const data = placementEntities.get(placementId);
  if (data) {
    viewer.entities.remove(data.entity);
    placementEntities.delete(placementId);
    console.log('[CesiumBridge] Placement removed:', placementId);
  }
}

/**
 * 配置物を更新
 * @param {Object} placement - 配置物データ
 */
function updatePlacement(placement) {
  const data = placementEntities.get(placement.id);
  if (!data) return;

  const position = Cesium.Cartesian3.fromDegrees(
    placement.position.longitude,
    placement.position.latitude,
    placement.position.height || 0
  );

  const heading = Cesium.Math.toRadians(placement.rotation?.heading || 0);
  const pitch = Cesium.Math.toRadians(placement.rotation?.pitch || 0);
  const roll = Cesium.Math.toRadians(placement.rotation?.roll || 0);
  const orientation = Cesium.Transforms.headingPitchRollQuaternion(
    position,
    new Cesium.HeadingPitchRoll(heading, pitch, roll)
  );

  data.entity.position = position;
  data.entity.orientation = orientation;
  data.entity.model.scale = placement.scale?.x || 1.0;
  data.entity.show = placement.visible !== false;
  data.placement = placement;

  console.log('[CesiumBridge] Placement updated:', placement.id);
}

/**
 * 配置モードを開始
 * @param {string} assetId - アセットID
 * @param {string} modelUrl - モデルURL
 */
function startPlacementMode(assetId, modelUrl) {
  if (!viewer) return;

  // 既存のプレビューを削除
  if (previewEntity) {
    viewer.entities.remove(previewEntity);
  }

  placementMode = 'place';
  currentPlacementAssetId = assetId;

  // プレビューエンティティを作成
  previewEntity = viewer.entities.add({
    id: 'preview_' + assetId,
    position: Cesium.Cartesian3.ZERO,
    model: {
      uri: modelUrl,
      scale: 1.0,
      color: Cesium.Color.WHITE.withAlpha(0.7),
      silhouetteColor: Cesium.Color.LIME,
      silhouetteSize: 2,
    },
    show: false,
  });

  // マウス移動イベント
  viewer.screenSpaceEventHandler.setInputAction((movement) => {
    if (placementMode !== 'place') return;

    const position = getGroundPosition(movement.endPosition);
    if (position) {
      const snappedPosition = applyGridSnap(position);
      previewEntity.position = snappedPosition;
      previewEntity.show = true;
    }
  }, Cesium.ScreenSpaceEventType.MOUSE_MOVE);

  // クリックイベントで配置確定
  viewer.screenSpaceEventHandler.setInputAction((click) => {
    if (placementMode !== 'place') return;

    const position = getGroundPosition(click.position);
    if (position) {
      const snappedPosition = applyGridSnap(position);
      const cartographic = Cesium.Cartographic.fromCartesian(snappedPosition);

      sendToFlutter('placementConfirmed', {
        assetId: currentPlacementAssetId,
        position: {
          longitude: Cesium.Math.toDegrees(cartographic.longitude),
          latitude: Cesium.Math.toDegrees(cartographic.latitude),
          height: cartographic.height,
        }
      });
    }
  }, Cesium.ScreenSpaceEventType.LEFT_CLICK);

  // 右クリックでキャンセル
  viewer.screenSpaceEventHandler.setInputAction(() => {
    cancelPlacementMode();
    sendToFlutter('placementCancelled', {});
  }, Cesium.ScreenSpaceEventType.RIGHT_CLICK);

  console.log('[CesiumBridge] Placement mode started:', assetId);
  sendToFlutter('placementModeStarted', { assetId: assetId });
}

/**
 * 配置モードをキャンセル
 */
function cancelPlacementMode() {
  if (previewEntity) {
    viewer.entities.remove(previewEntity);
    previewEntity = null;
  }
  placementMode = null;
  currentPlacementAssetId = null;

  // イベントハンドラを通常に戻す
  resetPlacementEventHandlers();
  console.log('[CesiumBridge] Placement mode cancelled');
}

/**
 * 配置イベントハンドラをリセット
 */
function resetPlacementEventHandlers() {
  if (!viewer) return;

  // クリックイベントを通常のmapClickedに戻す
  viewer.screenSpaceEventHandler.setInputAction((click) => {
    // 配置物のピック
    const pickedObject = viewer.scene.pick(click.position);
    if (Cesium.defined(pickedObject) && pickedObject.id) {
      const entityId = pickedObject.id.id || pickedObject.id;
      if (placementEntities.has(entityId)) {
        selectPlacement(entityId);
        return;
      }
    }

    // 選択解除
    deselectPlacement();

    // 通常のマップクリック
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

  // 移動イベントを削除
  viewer.screenSpaceEventHandler.removeInputAction(Cesium.ScreenSpaceEventType.MOUSE_MOVE);
  viewer.screenSpaceEventHandler.removeInputAction(Cesium.ScreenSpaceEventType.RIGHT_CLICK);
}

/**
 * 配置物を選択
 * @param {string} placementId - 配置物ID
 */
function selectPlacement(placementId) {
  // 既存の選択を解除
  if (selectedPlacementId) {
    const prevData = placementEntities.get(selectedPlacementId);
    if (prevData && prevData.entity.model) {
      prevData.entity.model.silhouetteColor = Cesium.Color.TRANSPARENT;
      prevData.entity.model.silhouetteSize = 0;
    }
  }

  selectedPlacementId = placementId;

  // 新しい選択をハイライト
  const data = placementEntities.get(placementId);
  if (data && data.entity.model) {
    data.entity.model.silhouetteColor = Cesium.Color.YELLOW;
    data.entity.model.silhouetteSize = 3;
  }

  sendToFlutter('placementSelected', { id: placementId });
}

/**
 * 配置物の選択を解除
 */
function deselectPlacement() {
  if (selectedPlacementId) {
    const data = placementEntities.get(selectedPlacementId);
    if (data && data.entity.model) {
      data.entity.model.silhouetteColor = Cesium.Color.TRANSPARENT;
      data.entity.model.silhouetteSize = 0;
    }
    selectedPlacementId = null;
    sendToFlutter('placementDeselected', {});
  }
}

/**
 * 配置物にズーム
 * @param {string} placementId - 配置物ID
 */
function zoomToPlacement(placementId) {
  if (!viewer) return;

  const data = placementEntities.get(placementId);
  if (data) {
    viewer.flyTo(data.entity, {
      duration: 1.5,
      offset: new Cesium.HeadingPitchRange(0, -0.5, 50)
    });
  }
}

/**
 * スナップ設定を更新
 * @param {Object} settings - 設定
 */
function updateSnapSettings(settings) {
  Object.assign(snapSettings, settings);
  console.log('[CesiumBridge] Snap settings updated:', snapSettings);
}

/**
 * グリッドスナップを適用
 * @param {Cesium.Cartesian3} position - 元の位置
 * @returns {Cesium.Cartesian3} スナップ後の位置
 */
function applyGridSnap(position) {
  if (!snapSettings.gridEnabled) return position;

  const cartographic = Cesium.Cartographic.fromCartesian(position);

  // メートル単位でスナップ
  const latRad = cartographic.latitude;
  const metersPerDegreeLon = 111320 * Math.cos(latRad);
  const metersPerDegreeLat = 110540;

  const gridSize = snapSettings.gridSize;
  const lonStep = gridSize / metersPerDegreeLon;
  const latStep = gridSize / metersPerDegreeLat;

  const snappedLon = Math.round(cartographic.longitude / lonStep) * lonStep;
  const snappedLat = Math.round(cartographic.latitude / latStep) * latStep;

  return Cesium.Cartesian3.fromRadians(
    snappedLon,
    snappedLat,
    cartographic.height
  );
}

/**
 * 角度スナップを適用
 * @param {number} angle - 元の角度（度）
 * @returns {number} スナップ後の角度
 */
function applyAngleSnap(angle) {
  if (!snapSettings.angleEnabled) return angle;
  const step = snapSettings.angleStep;
  return Math.round(angle / step) * step;
}

// ============================================
// ドローンフォーメーション管理機能
// ============================================

/**
 * 輝度を適用した色を計算（ソリッドカラー）
 * シンプルな明るさ調整、アルファは常に1.0
 * @param {Cesium.Color} baseColor - 元の色
 * @param {number} intensity - 輝度（0.2-2.0、1.0が基準）
 * @returns {Cesium.Color} 輝度適用後の色
 */
function applyGlowIntensity(baseColor, intensity) {
  let r = baseColor.red;
  let g = baseColor.green;
  let b = baseColor.blue;
  
  if (intensity < 1.0) {
    // 暗くする（RGB全体を乗算）
    r *= intensity;
    g *= intensity;
    b *= intensity;
  } else if (intensity > 1.0) {
    // 明るくする（RGBに加算、元の色の比率を保持）
    const boost = (intensity - 1.0) * 0.5; // 控えめに加算
    r = Math.min(r + boost * (1 - r), 1.0);
    g = Math.min(g + boost * (1 - g), 1.0);
    b = Math.min(b + boost * (1 - b), 1.0);
  }
  
  // アルファは常に1.0（完全不透明）でソリッドに
  return new Cesium.Color(r, g, b, 1.0);
}

/**
 * HSVからCesium.Colorに変換
 * @param {number} h - Hue (0-360)
 * @param {number} s - Saturation (0-1)
 * @param {number} v - Value (0-1)
 * @param {number} a - Alpha (0-1)
 * @returns {Cesium.Color}
 */
function hsvToColor(h, s, v, a) {
  const c = v * s;
  const x = c * (1 - Math.abs((h / 60) % 2 - 1));
  const m = v - c;
  
  let r, g, b;
  if (h < 60) {
    [r, g, b] = [c, x, 0];
  } else if (h < 120) {
    [r, g, b] = [x, c, 0];
  } else if (h < 180) {
    [r, g, b] = [0, c, x];
  } else if (h < 240) {
    [r, g, b] = [0, x, c];
  } else if (h < 300) {
    [r, g, b] = [x, 0, c];
  } else {
    [r, g, b] = [c, 0, x];
  }
  
  return new Cesium.Color(r + m, g + m, b + m, a);
}

/**
 * ドローンフォーメーションを追加（光る球として描画）
 * @param {Object} config - 設定
 * @param {string} config.id - フォーメーションID
 * @param {string} config.name - フォーメーション名
 * @param {Array} config.drones - ドローンデータ配列 [{id, x, y, r, g, b, a}, ...]
 * @param {Object} config.basePosition - 基準位置 {longitude, latitude}
 * @param {number} config.altitude - 高度（メートル）
 * @param {number} config.heading - 方位角（度、水平回転）
 * @param {number} config.tilt - チルト（度、垂直回転、-90〜90）
 * @param {number} config.scale - スケール
 * @param {number} config.pointSize - ポイントサイズ（ピクセル）
 * @param {number} config.glowIntensity - 輝度（発光の濃さ、0.2-2.0）
 * @param {string} config.customColor - カスタム色（HEX、nullの場合は個別色）
 * @param {boolean} config.useIndividualColors - 個別色を使用するか
 */
function addDroneFormation(config) {
  if (!viewer) return;

  console.log('[CesiumBridge] Adding drone formation:', config.id, 'drones:', config.drones.length);

  const basePosition = config.basePosition;
  const altitude = config.altitude || 50;
  const heading = Cesium.Math.toRadians(config.heading || 0);
  const tilt = Cesium.Math.toRadians(config.tilt || 0); // 垂直回転
  const scale = config.scale || 1.0;
  const pointSize = config.pointSize || 5;
  const glowIntensity = config.glowIntensity || 1.0;
  const useIndividualColors = config.useIndividualColors !== false;

  // カスタム色をパース
  let customColor = null;
  if (config.customColor) {
    customColor = Cesium.Color.fromCssColorString(config.customColor);
  }

  // エンティティコレクションを作成
  const entities = [];
  const cosHeading = Math.cos(heading);
  const sinHeading = Math.sin(heading);
  const cosTilt = Math.cos(tilt);
  const sinTilt = Math.sin(tilt);

  // 緯度経度の1メートルあたりの度数を計算
  const baseLatRad = Cesium.Math.toRadians(basePosition.latitude);
  const metersPerDegreeLon = 111320 * Math.cos(baseLatRad);
  const metersPerDegreeLat = 110540;

  for (const drone of config.drones) {
    // 相対座標をスケール適用
    let x = drone.x * scale;
    let y = drone.y * scale;
    let z = 0; // 初期z座標は0

    // チルト（垂直回転）を適用（Y軸周り）
    const tiltedY = y * cosTilt - z * sinTilt;
    const tiltedZ = y * sinTilt + z * cosTilt;
    y = tiltedY;
    z = tiltedZ;

    // 方位角（水平回転）を適用
    const rotatedX = x * cosHeading - y * sinHeading;
    const rotatedY = x * sinHeading + y * cosHeading;

    // 経度・緯度・高度に変換
    const lon = basePosition.longitude + (rotatedX / metersPerDegreeLon);
    const lat = basePosition.latitude + (rotatedY / metersPerDegreeLat);
    const droneAltitude = altitude + z;

    // 色を決定
    let baseColor;
    if (useIndividualColors && !customColor) {
      baseColor = Cesium.Color.fromBytes(drone.r, drone.g, drone.b, drone.a || 255);
    } else if (customColor) {
      baseColor = customColor;
    } else {
      baseColor = Cesium.Color.WHITE;
    }

    // 輝度を適用（HSV色空間でValue調整、彩度も考慮して白飛びを防ぐ）
    const glowColor = applyGlowIntensity(baseColor, glowIntensity);

    const entity = viewer.entities.add({
      id: `${config.id}_drone_${drone.id}`,
      position: Cesium.Cartesian3.fromDegrees(lon, lat, droneAltitude),
      point: {
        pixelSize: pointSize,
        color: glowColor,
        outlineColor: Cesium.Color.TRANSPARENT,
        outlineWidth: 0,
        disableDepthTestDistance: Number.POSITIVE_INFINITY,
        scaleByDistance: new Cesium.NearFarScalar(50, 1.2, 2000, 0.3),
      },
    });

    entities.push({ main: entity, glow: null, droneData: drone, originalPos: { x: drone.x, y: drone.y } });
  }

  // フォーメーション情報を保存
  droneFormations.set(config.id, {
    config: config,
    entities: entities,
    glowIntensity: glowIntensity,
    tilt: config.tilt || 0,
  });

  console.log('[CesiumBridge] Drone formation added:', config.id, 'entities:', entities.length);
  sendToFlutter('droneFormationAdded', { 
    id: config.id, 
    droneCount: entities.length 
  });
}

/**
 * ドローンフォーメーションを削除
 * @param {string} formationId - フォーメーションID
 */
function removeDroneFormation(formationId) {
  if (!viewer) return;

  const data = droneFormations.get(formationId);
  if (data) {
    // 全エンティティを削除
    for (const entityData of data.entities) {
      if (entityData.main) {
        try { viewer.entities.remove(entityData.main); } catch (e) {}
      }
      if (entityData.glow) {
        try { viewer.entities.remove(entityData.glow); } catch (e) {}
      }
    }
    droneFormations.delete(formationId);
    console.log('[CesiumBridge] Drone formation removed:', formationId);
    sendToFlutter('droneFormationRemoved', { id: formationId });
  }
}

/**
 * ドローンフォーメーションを更新
 * @param {Object} config - 設定（addDroneFormationと同じ形式）
 */
function updateDroneFormation(config) {
  // 既存のフォーメーションを削除して再作成
  removeDroneFormation(config.id);
  addDroneFormation(config);
}

/**
 * ドローンフォーメーションのスタイルを更新
 * @param {string} formationId - フォーメーションID
 * @param {Object} options - オプション
 * @param {number} options.pointSize - ポイントサイズ（1-10px）
 * @param {number} options.glowIntensity - 輝度（発光の濃さ、0.2-2.0）
 * @param {string} options.customColor - カスタム色
 * @param {boolean} options.useIndividualColors - 個別色を使用
 * @param {boolean} options.visible - 表示フラグ
 */
function updateDroneFormationStyle(formationId, options) {
  const data = droneFormations.get(formationId);
  if (!data) return;

  let customColor = null;
  if (options.customColor) {
    customColor = Cesium.Color.fromCssColorString(options.customColor);
  }

  const config = data.config;
  const useIndividualColors = options.useIndividualColors !== undefined 
    ? options.useIndividualColors 
    : config.useIndividualColors;
  const glowIntensity = options.glowIntensity !== undefined
    ? options.glowIntensity
    : (data.glowIntensity || 1.0);
  const pointSize = options.pointSize !== undefined
    ? options.pointSize
    : config.pointSize;

  for (let i = 0; i < data.entities.length; i++) {
    const entityData = data.entities[i];
    const drone = entityData.droneData || config.drones[i];

    // 表示/非表示
    if (options.visible !== undefined) {
      if (entityData.main) entityData.main.show = options.visible;
      if (entityData.glow) entityData.glow.show = options.visible;
    }

    // 色を決定
    let baseColor;
    if (customColor) {
      baseColor = customColor;
    } else if (useIndividualColors && drone) {
      baseColor = Cesium.Color.fromBytes(drone.r, drone.g, drone.b, drone.a || 255);
    } else {
      baseColor = Cesium.Color.WHITE;
    }

    // 輝度を適用（HSV色空間でValue調整、彩度も考慮して白飛びを防ぐ）
    const glowColor = applyGlowIntensity(baseColor, glowIntensity);

    // メインポイント更新（サイズは変えない、色のみ調整）
    if (entityData.main && entityData.main.point) {
      entityData.main.point.pixelSize = pointSize;
      entityData.main.point.color = glowColor;
    }
  }

  // 設定を更新
  if (options.pointSize !== undefined) {
    config.pointSize = options.pointSize;
  }
  if (options.glowIntensity !== undefined) {
    data.glowIntensity = options.glowIntensity;
  }
  if (options.customColor !== undefined) {
    config.customColor = options.customColor;
  }
  if (options.useIndividualColors !== undefined) {
    config.useIndividualColors = options.useIndividualColors;
  }

  console.log('[CesiumBridge] Drone formation style updated:', formationId);
}

/**
 * ドローンフォーメーションの表示/非表示を切り替え
 * @param {string} formationId - フォーメーションID
 * @param {boolean} visible - 表示フラグ
 */
function setDroneFormationVisible(formationId, visible) {
  const data = droneFormations.get(formationId);
  if (!data) return;

  for (const entityData of data.entities) {
    if (entityData.main) entityData.main.show = visible;
    if (entityData.glow) entityData.glow.show = visible;
  }

  console.log('[CesiumBridge] Drone formation visibility:', formationId, visible);
}

/**
 * ドローンフォーメーションにズーム
 * @param {string} formationId - フォーメーションID
 */
function zoomToDroneFormation(formationId) {
  if (!viewer) return;

  const data = droneFormations.get(formationId);
  if (!data || data.entities.length === 0) return;

  // 全ドローンを含むバウンディングスフィアを計算
  const positions = data.entities
    .filter(e => e.main)
    .map(e => e.main.position.getValue(Cesium.JulianDate.now()));
  const boundingSphere = Cesium.BoundingSphere.fromPoints(positions);

  viewer.camera.flyToBoundingSphere(boundingSphere, {
    duration: 1.5,
    offset: new Cesium.HeadingPitchRange(0, -0.5, boundingSphere.radius * 2)
  });
}

// ============================================
// 通信処理
// ============================================

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
    
    // 3D Tileset関連
    case 'addLocalTileset':
      addLocalTileset(params);
      break;
    case 'removeTileset':
      removeTileset(params.id);
      break;
    case 'setTilesetVisible':
      setTilesetVisible(params.id, params.visible);
      break;
    case 'setTilesetOpacity':
      setTilesetOpacity(params.id, params.opacity);
      break;
    case 'setGoogleTilesetVisible':
      setGoogleTilesetVisible(params.visible);
      break;
    case 'flyToTileset':
      flyToTileset(params.id);
      break;
    case 'setGoogleTilesetClipping':
      setGoogleTilesetClipping(params.tilesetId);
      break;
    case 'removeGoogleTilesetClipping':
      removeGoogleTilesetClipping(params.tilesetId);
      break;
    case 'adjustTilesetPosition':
      adjustTilesetPosition(params);
      break;
    case 'adjustTilesetQuality':
      adjustTilesetQuality(params);
      break;
    
    // 計測関連
    case 'startMeasurementMode':
      startMeasurementMode(params.type);
      break;
    case 'cancelMeasurement':
      cancelMeasurement();
      break;
    case 'addMeasurementDisplay':
      addMeasurementDisplay(params);
      break;
    case 'removeMeasurementDisplay':
      removeMeasurementDisplay(params.measurementId);
      break;
    case 'setMeasurementVisible':
      setMeasurementVisible(params.measurementId, params.visible);
      break;
    case 'clearAllMeasurements':
      clearAllMeasurements();
      break;
    case 'updateMeasurementStyle':
      updateMeasurementStyle(params);
      break;
    case 'updateMeasurementDisplay':
      updateMeasurementDisplay(params);
      break;
    case 'startMeasurementEditMode':
      startMeasurementEditMode(params.measurementId);
      break;
    case 'endMeasurementEditMode':
      endMeasurementEditMode();
      break;
    case 'resetCameraControls':
      resetCameraControls();
      break;
    
    // 配置物関連
    case 'addPlacement':
      addPlacement(params.placement, params.modelUrl);
      break;
    case 'removePlacement':
      removePlacement(params.placementId);
      break;
    case 'updatePlacement':
      updatePlacement(params.placement);
      break;
    case 'startPlacementMode':
      startPlacementMode(params.assetId, params.modelUrl);
      break;
    case 'cancelPlacementMode':
      cancelPlacementMode();
      break;
    case 'selectPlacement':
      selectPlacement(params.placementId);
      break;
    case 'deselectPlacement':
      deselectPlacement();
      break;
    case 'zoomToPlacement':
      zoomToPlacement(params.placementId);
      break;
    case 'updateSnapSettings':
      updateSnapSettings(params);
      break;
    
    // ドローンフォーメーション関連
    case 'addDroneFormation':
      addDroneFormation(params);
      break;
    case 'removeDroneFormation':
      removeDroneFormation(params.formationId);
      break;
    case 'updateDroneFormation':
      updateDroneFormation(params);
      break;
    case 'updateDroneFormationStyle':
      updateDroneFormationStyle(params.formationId, params.options);
      break;
    case 'setDroneFormationVisible':
      setDroneFormationVisible(params.formationId, params.visible);
      break;
    case 'zoomToDroneFormation':
      zoomToDroneFormation(params.formationId);
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
