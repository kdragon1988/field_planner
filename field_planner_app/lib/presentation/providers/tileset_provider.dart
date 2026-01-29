import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/logger.dart';
import '../../data/models/geo_position.dart';
import '../../data/models/layer.dart';
import '../../data/services/local_file_server.dart';
import '../../infrastructure/webview/cesium_controller.dart';

/// 3D Tilesレイヤー情報
class TilesetLayer {
  /// ユニークID
  final String id;

  /// 表示名
  final String name;

  /// tileset.jsonのパス
  final String tilesetJsonPath;

  /// フォルダパス
  final String folderPath;

  /// 表示フラグ
  final bool visible;

  /// 不透明度
  final double opacity;

  /// 中心座標
  final GeoPosition? center;

  /// バウンディング半径
  final double? radius;

  /// 高さオフセット（メートル）
  final double heightOffset;

  /// 画質設定（Screen Space Error、1-64、小さいほど高画質）
  final double screenSpaceError;

  /// Google 3D Tilesをクリッピングするか
  final bool clipGoogleTiles;

  /// レイヤーに変換
  Layer toLayer() {
    return Layer(
      id: id,
      name: name,
      type: LayerType.tiles3D,
      visible: visible,
      opacity: opacity,
      sourcePath: tilesetJsonPath,
      originalPath: folderPath,
      metadata: {
        if (center != null) 'center': center!.toJson(),
        if (radius != null) 'radius': radius,
        'heightOffset': heightOffset,
        'screenSpaceError': screenSpaceError,
        'clipGoogleTiles': clipGoogleTiles,
      },
    );
  }

  TilesetLayer({
    required this.id,
    required this.name,
    required this.tilesetJsonPath,
    required this.folderPath,
    this.visible = true,
    this.opacity = 1.0,
    this.center,
    this.radius,
    this.heightOffset = 0.0,
    this.screenSpaceError = 2.0,
    this.clipGoogleTiles = true,
  });

  TilesetLayer copyWith({
    String? id,
    String? name,
    String? tilesetJsonPath,
    String? folderPath,
    bool? visible,
    double? opacity,
    GeoPosition? center,
    double? radius,
    double? heightOffset,
    double? screenSpaceError,
    bool? clipGoogleTiles,
  }) {
    return TilesetLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      tilesetJsonPath: tilesetJsonPath ?? this.tilesetJsonPath,
      folderPath: folderPath ?? this.folderPath,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      center: center ?? this.center,
      radius: radius ?? this.radius,
      heightOffset: heightOffset ?? this.heightOffset,
      screenSpaceError: screenSpaceError ?? this.screenSpaceError,
      clipGoogleTiles: clipGoogleTiles ?? this.clipGoogleTiles,
    );
  }

  /// JSONからTilesetLayerを生成
  factory TilesetLayer.fromJson(Map<String, dynamic> json) {
    return TilesetLayer(
      id: json['id'] as String,
      name: json['name'] as String,
      tilesetJsonPath: json['tilesetJsonPath'] as String,
      folderPath: json['folderPath'] as String,
      visible: json['visible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      center: json['center'] != null
          ? GeoPosition.fromJson(json['center'] as Map<String, dynamic>)
          : null,
      radius: (json['radius'] as num?)?.toDouble(),
      heightOffset: (json['heightOffset'] as num?)?.toDouble() ?? 0.0,
      screenSpaceError: (json['screenSpaceError'] as num?)?.toDouble() ?? 2.0,
      clipGoogleTiles: json['clipGoogleTiles'] as bool? ?? true,
    );
  }

  /// TilesetLayerをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tilesetJsonPath': tilesetJsonPath,
      'folderPath': folderPath,
      'visible': visible,
      'opacity': opacity,
      if (center != null) 'center': center!.toJson(),
      if (radius != null) 'radius': radius,
      'heightOffset': heightOffset,
      'screenSpaceError': screenSpaceError,
      'clipGoogleTiles': clipGoogleTiles,
    };
  }
}

/// Tilesetプロバイダーの状態
class TilesetState {
  /// 3D Tilesレイヤー一覧
  final List<TilesetLayer> layers;

  /// Google 3D Tiles表示フラグ
  final bool showGoogleTileset;

  /// Cesium地形表示フラグ
  final bool showTerrain;

  /// 選択中のTileset ID
  final String? selectedTilesetId;

  const TilesetState({
    this.layers = const [],
    this.showGoogleTileset = true,
    this.showTerrain = false,
    this.selectedTilesetId,
  });

  /// 選択中のTilesetを取得
  TilesetLayer? get selectedTileset {
    if (selectedTilesetId == null) return null;
    try {
      return layers.firstWhere((l) => l.id == selectedTilesetId);
    } catch (_) {
      return null;
    }
  }

  TilesetState copyWith({
    List<TilesetLayer>? layers,
    bool? showGoogleTileset,
    bool? showTerrain,
    String? selectedTilesetId,
    bool clearSelection = false,
  }) {
    return TilesetState(
      layers: layers ?? this.layers,
      showGoogleTileset: showGoogleTileset ?? this.showGoogleTileset,
      showTerrain: showTerrain ?? this.showTerrain,
      selectedTilesetId: clearSelection ? null : (selectedTilesetId ?? this.selectedTilesetId),
    );
  }
}

/// Tilesetプロバイダー
class TilesetNotifier extends StateNotifier<TilesetState> with LoggableMixin {
  CesiumController? _cesiumController;
  String? _projectPath;

  TilesetNotifier() : super(const TilesetState());

  /// プロジェクトパスを設定
  void setProjectPath(String? path) {
    _projectPath = path;
  }

  /// CesiumControllerを設定
  void setController(CesiumController controller) {
    _cesiumController = controller;

    // コールバックを設定
    controller.onTilesetAdded = _onTilesetAdded;
    controller.onTilesetRemoved = _onTilesetRemoved;
    controller.onTilesetError = _onTilesetError;
    controller.onGoogleTilesetVisibilityChanged = _onGoogleTilesetVisibilityChanged;
  }

  /// 3D Tilesを追加
  ///
  /// [name] 表示名
  /// [tilesetJsonPath] tileset.jsonのローカルパス
  /// [folderPath] フォルダパス
  /// [flyTo] インポート後にカメラを移動するか
  /// [clipGoogleTiles] Google 3D Tilesをクリッピングするか
  Future<void> addTileset({
    required String name,
    required String tilesetJsonPath,
    required String folderPath,
    bool flyTo = true,
    bool clipGoogleTiles = true,
  }) async {
    if (_cesiumController == null) {
      logWarning('CesiumController not available');
      return;
    }

    final id = const Uuid().v4();

    // ローカルファイルサーバーを起動（まだ起動していない場合）
    final fileServer = LocalFileServer.instance;
    if (!fileServer.isRunning) {
      await fileServer.start();
    }

    // ローカルファイルサーバー経由でURLを取得
    // file://プロトコルはWebViewのセキュリティ制限で使えないため、
    // HTTP経由でファイルを提供する
    final url = fileServer.getTilesetUrl(tilesetJsonPath);
    logInfo('Tileset URL: $url (from $tilesetJsonPath)');

    // 仮レイヤーを追加
    final layer = TilesetLayer(
      id: id,
      name: name,
      tilesetJsonPath: tilesetJsonPath,
      folderPath: folderPath,
      clipGoogleTiles: clipGoogleTiles,
    );
    state = state.copyWith(
      layers: [...state.layers, layer],
    );

    // flyTo/clippingフラグを保存（onTilesetAddedコールバックで使用）
    _pendingFlyTo[id] = flyTo;
    _pendingClipping[id] = clipGoogleTiles;

    // CesiumJSに追加
    await _cesiumController!.addLocalTileset(
      id: id,
      url: url,
      name: name,
      opacity: 1.0,
      show: true,
    );

    // プロジェクトに保存
    await saveTilesets();

    logInfo('Tileset added: $name ($id)');
  }

  // flyTo待ちのTileset
  final Map<String, bool> _pendingFlyTo = {};
  
  // クリッピング待ちのTileset
  final Map<String, bool> _pendingClipping = {};

  // 高さオフセット待ちのTileset
  final Map<String, double> _pendingHeightOffset = {};

  // 画質設定待ちのTileset
  final Map<String, double> _pendingScreenSpaceError = {};

  /// 3D Tilesを削除
  Future<void> removeTileset(String id) async {
    if (_cesiumController == null) return;

    // レイヤー情報を取得
    final layer = state.layers.firstWhere(
      (l) => l.id == id,
      orElse: () => TilesetLayer(
        id: id,
        name: '',
        tilesetJsonPath: '',
        folderPath: '',
      ),
    );

    await _cesiumController!.removeTileset(id);

    // ファイルサーバーからアンマウント
    // tileset.jsonの親ディレクトリのハッシュを使用（getTilesetUrlと同じ計算）
    if (layer.tilesetJsonPath.isNotEmpty) {
      final fileServer = LocalFileServer.instance;
      final directory = layer.tilesetJsonPath.substring(
        0,
        layer.tilesetJsonPath.lastIndexOf('/'),
      );
      final mountPath = '/tileset_${directory.hashCode.abs()}';
      fileServer.unmountDirectory(mountPath);
    }

    state = state.copyWith(
      layers: state.layers.where((l) => l.id != id).toList(),
    );

    // プロジェクトに保存
    await saveTilesets();

    logInfo('Tileset removed: $id');
  }

  /// 3D Tilesの表示/非表示を切り替え
  Future<void> setTilesetVisible(String id, bool visible) async {
    if (_cesiumController == null) return;

    await _cesiumController!.setTilesetVisible(id, visible);

    state = state.copyWith(
      layers: state.layers.map((l) {
        if (l.id == id) {
          return l.copyWith(visible: visible);
        }
        return l;
      }).toList(),
    );
  }

  /// 3D Tilesの不透明度を変更
  Future<void> setTilesetOpacity(String id, double opacity) async {
    if (_cesiumController == null) return;

    await _cesiumController!.setTilesetOpacity(id, opacity);

    state = state.copyWith(
      layers: state.layers.map((l) {
        if (l.id == id) {
          return l.copyWith(opacity: opacity);
        }
        return l;
      }).toList(),
    );
  }

  /// 3D Tilesの位置にカメラを移動
  Future<void> flyToTileset(String id) async {
    if (_cesiumController == null) return;
    await _cesiumController!.flyToTileset(id);
  }

  /// Google 3D Tilesの表示/非表示を切り替え
  Future<void> setGoogleTilesetVisible(bool visible) async {
    if (_cesiumController == null) return;

    await _cesiumController!.setGoogleTilesetVisible(visible);
    state = state.copyWith(showGoogleTileset: visible);

    logInfo('Google tileset visibility: $visible');
  }

  /// 地形の表示/非表示を切り替え
  Future<void> setTerrainEnabled(bool enabled) async {
    if (_cesiumController == null) return;

    await _cesiumController!.setTerrainEnabled(enabled);
    state = state.copyWith(showTerrain: enabled);

    logInfo('Terrain enabled: $enabled');
  }

  /// Tilesetを選択
  void selectTileset(String? id) {
    state = state.copyWith(
      selectedTilesetId: id,
      clearSelection: id == null,
    );
    logInfo('Tileset selected: $id');
  }

  /// Tilesetの高さオフセットを調整
  Future<void> adjustTilesetHeight(String id, double heightOffset) async {
    if (_cesiumController == null) return;

    await _cesiumController!.adjustTilesetPosition(
      id: id,
      heightOffset: heightOffset,
    );

    state = state.copyWith(
      layers: state.layers.map((l) {
        if (l.id == id) {
          return l.copyWith(heightOffset: heightOffset);
        }
        return l;
      }).toList(),
    );

    // プロジェクトに保存
    await saveTilesets();

    logInfo('Tileset height adjusted: $id, offset: $heightOffset');
  }

  /// Tilesetの画質を調整
  Future<void> adjustTilesetQuality(String id, double screenSpaceError) async {
    if (_cesiumController == null) return;

    await _cesiumController!.adjustTilesetQuality(
      id: id,
      screenSpaceError: screenSpaceError,
    );

    state = state.copyWith(
      layers: state.layers.map((l) {
        if (l.id == id) {
          return l.copyWith(screenSpaceError: screenSpaceError);
        }
        return l;
      }).toList(),
    );

    // プロジェクトに保存
    await saveTilesets();

    logInfo('Tileset quality adjusted: $id, SSE: $screenSpaceError');
  }

  /// Google 3D Tilesのクリッピングを設定
  Future<void> setGoogleTilesetClipping(String tilesetId) async {
    if (_cesiumController == null) return;

    await _cesiumController!.setGoogleTilesetClipping(tilesetId);

    state = state.copyWith(
      layers: state.layers.map((l) {
        if (l.id == tilesetId) {
          return l.copyWith(clipGoogleTiles: true);
        }
        return l;
      }).toList(),
    );

    logInfo('Google tileset clipping set for: $tilesetId');
  }

  /// Google 3D Tilesのクリッピングを解除
  Future<void> removeGoogleTilesetClipping() async {
    if (_cesiumController == null) return;

    await _cesiumController!.removeGoogleTilesetClipping();

    state = state.copyWith(
      layers: state.layers.map((l) {
        return l.copyWith(clipGoogleTiles: false);
      }).toList(),
    );

    logInfo('Google tileset clipping removed');
  }

  // コールバック処理

  void _onTilesetAdded(String id, String name, GeoPosition center, double radius) {
    logInfo('Tileset ready: $id at ${center.latitude}, ${center.longitude}');

    // 状態を更新
    state = state.copyWith(
      layers: state.layers.map((l) {
        if (l.id == id) {
          return l.copyWith(center: center, radius: radius);
        }
        return l;
      }).toList(),
    );

    // 高さオフセットを適用（保存されていた場合）
    final heightOffset = _pendingHeightOffset.remove(id);
    if (heightOffset != null && heightOffset != 0) {
      logInfo('Applying pending height offset: $id, offset: $heightOffset');
      _cesiumController?.adjustTilesetPosition(
        id: id,
        heightOffset: heightOffset,
      );
    }

    // 画質設定を適用（保存されていた場合）
    final screenSpaceError = _pendingScreenSpaceError.remove(id);
    if (screenSpaceError != null && screenSpaceError != 2.0) {
      logInfo('Applying pending screen space error: $id, SSE: $screenSpaceError');
      _cesiumController?.adjustTilesetQuality(
        id: id,
        screenSpaceError: screenSpaceError,
      );
    }

    // Google 3D Tilesをクリッピング（オプションに応じて）
    final shouldClip = _pendingClipping.remove(id) ?? true;
    if (shouldClip) {
      _cesiumController?.setGoogleTilesetClipping(id);
    }

    // カメラを移動（オプションに応じて）
    final shouldFlyTo = _pendingFlyTo.remove(id) ?? true;
    if (shouldFlyTo) {
      _cesiumController?.flyToTileset(id);
    }
  }

  void _onTilesetRemoved(String id) {
    state = state.copyWith(
      layers: state.layers.where((l) => l.id != id).toList(),
    );
  }

  void _onTilesetError(String id, String error) {
    logError('Tileset error: $id - $error');
    // エラーが発生したレイヤーを削除
    state = state.copyWith(
      layers: state.layers.where((l) => l.id != id).toList(),
    );
  }

  void _onGoogleTilesetVisibilityChanged(bool visible) {
    state = state.copyWith(showGoogleTileset: visible);
  }

  // ============================================
  // 永続化
  // ============================================

  /// 3Dタイル設定をプロジェクトに保存
  Future<void> saveTilesets() async {
    logInfo('saveTilesets called, projectPath: $_projectPath');
    if (_projectPath == null) {
      logWarning('Cannot save tilesets: projectPath is null');
      return;
    }

    final file = File('$_projectPath/tilesets.json');
    final data = {
      'tilesets': state.layers.map((l) => l.toJson()).toList(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    logInfo('Tilesets saved: ${state.layers.length} layers to ${file.path}');
  }

  /// 3Dタイル設定をプロジェクトから読み込み、CesiumJSに追加
  Future<void> loadTilesets() async {
    logInfo('loadTilesets called, projectPath: $_projectPath, controller: ${_cesiumController != null}');
    if (_projectPath == null || _cesiumController == null) {
      logWarning('Cannot load tilesets: projectPath=$_projectPath, controller=${_cesiumController != null}');
      return;
    }

    final file = File('$_projectPath/tilesets.json');
    if (!await file.exists()) {
      logInfo('No tilesets.json found at ${file.path}');
      return;
    }

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final tilesetsJson = data['tilesets'] as List<dynamic>? ?? [];

      logInfo('Loading ${tilesetsJson.length} tilesets...');

      for (final json in tilesetsJson) {
        final layer = TilesetLayer.fromJson(json as Map<String, dynamic>);

        // ファイルが存在するか確認
        final tilesetFile = File(layer.tilesetJsonPath);
        if (!await tilesetFile.exists()) {
          logWarning('Tileset file not found: ${layer.tilesetJsonPath}');
          continue;
        }

        // ローカルファイルサーバーを起動
        final fileServer = LocalFileServer.instance;
        if (!fileServer.isRunning) {
          await fileServer.start();
        }

        // URLを取得
        final url = fileServer.getTilesetUrl(layer.tilesetJsonPath);

        // 状態に追加
        state = state.copyWith(
          layers: [...state.layers, layer],
        );

        // flyToはしない、クリッピングは設定を使用
        _pendingFlyTo[layer.id] = false;
        _pendingClipping[layer.id] = layer.clipGoogleTiles;

        // 高さオフセットと画質設定を保留（タイルセットロード完了後に適用）
        if (layer.heightOffset != 0) {
          _pendingHeightOffset[layer.id] = layer.heightOffset;
          logInfo('Pending height offset for ${layer.id}: ${layer.heightOffset}');
        }
        if (layer.screenSpaceError != 2.0) {
          _pendingScreenSpaceError[layer.id] = layer.screenSpaceError;
          logInfo('Pending SSE for ${layer.id}: ${layer.screenSpaceError}');
        }

        // CesiumJSに追加（ロード完了後に_onTilesetAddedが呼ばれ、そこでオフセット等を適用）
        await _cesiumController!.addLocalTileset(
          id: layer.id,
          url: url,
          name: layer.name,
          opacity: layer.opacity,
          show: layer.visible,
        );

        logInfo('Tileset loaded: ${layer.name}');
      }
    } catch (e) {
      logError('Failed to load tilesets: $e');
    }
  }
}

/// Tilesetプロバイダー
final tilesetProvider = StateNotifierProvider<TilesetNotifier, TilesetState>(
  (ref) => TilesetNotifier(),
);
