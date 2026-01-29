/// 配置物プロバイダー
/// 
/// 配置物管理に関する状態とロジックを提供。
/// PlacementRepositoryとCesiumControllerを統合し、
/// UIから配置操作を行うためのインターフェースを提供する。
/// 
/// 主な機能:
/// - 配置物の追加・更新・削除
/// - 配置モードの管理
/// - ドローンフォーメーションの配置
/// - CesiumJSとの同期

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/drone_formation.dart';
import '../../data/models/geo_position.dart';
import '../../data/models/placement.dart';
import '../../data/repositories/drone_formation_repository.dart';
import '../../data/repositories/placement_repository.dart';
import '../../infrastructure/webview/cesium_controller.dart';
import 'asset_provider.dart';
import 'cesium_provider.dart';
import 'project_provider.dart';

/// PlacementRepositoryのプロバイダー
final placementRepositoryProvider = Provider<PlacementRepository>((ref) {
  return PlacementRepository();
});

/// 配置物一覧のプロバイダー
final placementsProvider = FutureProvider<List<Placement>>((ref) async {
  final projectState = ref.watch(projectNotifierProvider);
  final repository = ref.read(placementRepositoryProvider);
  
  if (projectState is! ProjectLoadedState) {
    return [];
  }
  
  return repository.loadPlacements(projectState.projectPath);
});

/// 選択中の配置物IDのプロバイダー
final selectedPlacementIdProvider = StateProvider<String?>((ref) => null);

/// 選択中の配置物のプロバイダー
final selectedPlacementProvider = Provider<Placement?>((ref) {
  final selectedId = ref.watch(selectedPlacementIdProvider);
  final placementsAsync = ref.watch(placementsProvider);
  
  return placementsAsync.whenOrNull(
    data: (placements) {
      if (selectedId == null) return null;
      try {
        return placements.firstWhere((p) => p.id == selectedId);
      } catch (_) {
        return null;
      }
    },
  );
});

/// 配置モード状態
enum PlacementModeState {
  /// アイドル（配置モードなし）
  idle,
  /// 配置モード中
  placing,
  /// 移動モード中
  moving,
}

/// 配置モード状態のプロバイダー
final placementModeStateProvider = StateProvider<PlacementModeState>((ref) {
  return PlacementModeState.idle;
});

/// 配置中のアセットIDのプロバイダー
final placingAssetIdProvider = StateProvider<String?>((ref) => null);

/// 配置物管理コントローラ
class PlacementController extends ChangeNotifier {
  final CesiumController _cesiumController;
  final PlacementRepository _placementRepository;
  final DroneFormationRepository _droneFormationRepository;
  final Ref _ref;

  final List<Placement> _placements = [];
  final List<PlacementGroup> _groups = [];
  String? _selectedPlacementId;
  String? _currentAssetIdForPlacement;

  /// ドローン配置モード用の一時データ
  DroneFormation? _pendingDroneFormation;
  Map<String, dynamic>? _pendingDroneSettings;

  /// ドローン位置変更モード用のデータ
  String? _positionPickTargetId;
  void Function(GeoPosition)? _onPositionPicked;

  /// UUIDジェネレータ
  final Uuid _uuid = const Uuid();

  List<Placement> get placements => List.unmodifiable(_placements);
  List<PlacementGroup> get groups => List.unmodifiable(_groups);
  String? get selectedPlacementId => _selectedPlacementId;
  
  Placement? get selectedPlacement {
    if (_selectedPlacementId == null) return null;
    try {
      return _placements.firstWhere((p) => p.id == _selectedPlacementId);
    } catch (_) {
      return null;
    }
  }

  PlacementController(
    this._cesiumController,
    this._placementRepository,
    this._droneFormationRepository,
    this._ref,
  ) {
    _setupCallbacks();
  }

  /// コールバックを設定
  void _setupCallbacks() {
    _cesiumController.onPlacementConfirmed = _onPlacementConfirmed;
    _cesiumController.onPlacementSelected = _onPlacementSelected;
    _cesiumController.onPlacementDeselected = _onPlacementDeselected;
    _cesiumController.onPlacementCancelled = _onPlacementCancelled;
    _cesiumController.onMapClicked = _onMapClicked;
  }

  /// プロジェクトパスを取得
  String? get _projectPath {
    final projectState = _ref.read(projectNotifierProvider);
    if (projectState is ProjectLoadedState) {
      return projectState.projectPath;
    }
    return null;
  }

  /// 配置物を読み込み
  Future<void> loadPlacements() async {
    final projectPath = _projectPath;
    if (projectPath == null) return;

    _placements.clear();
    _placements.addAll(await _placementRepository.loadPlacements(projectPath));
    _groups.clear();
    _groups.addAll(await _placementRepository.loadGroups(projectPath));

    // CesiumJSに配置物を追加
    for (final placement in _placements) {
      await _addPlacementToCesium(placement);
    }

    notifyListeners();
  }

  /// 配置モードを開始
  Future<void> startPlacementMode(String assetId, String modelUrl) async {
    _currentAssetIdForPlacement = assetId;
    _ref.read(placementModeStateProvider.notifier).state = PlacementModeState.placing;
    _ref.read(placingAssetIdProvider.notifier).state = assetId;

    await _cesiumController.startPlacementMode(assetId, modelUrl);
  }

  /// 配置モードをキャンセル
  Future<void> cancelPlacementMode() async {
    _currentAssetIdForPlacement = null;
    _ref.read(placementModeStateProvider.notifier).state = PlacementModeState.idle;
    _ref.read(placingAssetIdProvider.notifier).state = null;

    await _cesiumController.cancelPlacementMode();
  }

  /// 配置物を選択
  Future<void> selectPlacement(String placementId) async {
    _selectedPlacementId = placementId;
    _ref.read(selectedPlacementIdProvider.notifier).state = placementId;
    await _cesiumController.selectPlacement(placementId);
    notifyListeners();
  }

  /// 選択を解除
  Future<void> deselectPlacement() async {
    _selectedPlacementId = null;
    _ref.read(selectedPlacementIdProvider.notifier).state = null;
    await _cesiumController.deselectPlacement();
    notifyListeners();
  }

  /// 配置物を削除
  Future<void> deletePlacement(String placementId) async {
    final projectPath = _projectPath;
    if (projectPath == null) return;

    await _cesiumController.removePlacement(placementId);
    
    _placements.removeWhere((p) => p.id == placementId);
    await _placementRepository.savePlacements(projectPath, _placements, groups: _groups);

    if (_selectedPlacementId == placementId) {
      _selectedPlacementId = null;
      _ref.read(selectedPlacementIdProvider.notifier).state = null;
    }

    _ref.invalidate(placementsProvider);
    notifyListeners();
  }

  /// 配置物を複製
  Future<void> duplicatePlacement(
    String placementId, {
    double offsetX = 2.0,
    double offsetY = 0.0,
  }) async {
    final projectPath = _projectPath;
    if (projectPath == null) return;

    final original = _placements.firstWhere((p) => p.id == placementId);

    // 経度・緯度のオフセットを計算（メートル→度）
    const metersPerDegreeLon = 111320.0;
    const metersPerDegreeLat = 110540.0;

    final duplicate = Placement(
      id: _uuid.v4(),
      assetId: original.assetId,
      name: '${original.name} (コピー)',
      position: GeoPosition(
        longitude: original.position.longitude + offsetX / metersPerDegreeLon,
        latitude: original.position.latitude + offsetY / metersPerDegreeLat,
        height: original.position.height,
      ),
      rotation: original.rotation,
      scale: original.scale,
      tags: List.from(original.tags),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _placements.add(duplicate);
    await _addPlacementToCesium(duplicate);
    await _placementRepository.savePlacements(projectPath, _placements, groups: _groups);

    _ref.invalidate(placementsProvider);
    notifyListeners();
  }

  /// 配置物を更新
  Future<void> updatePlacement(Placement placement) async {
    final projectPath = _projectPath;
    if (projectPath == null) return;

    final index = _placements.indexWhere((p) => p.id == placement.id);
    if (index == -1) return;

    final updated = placement.copyWith(updatedAt: DateTime.now());
    _placements[index] = updated;

    await _cesiumController.updatePlacement(updated.toJson());
    await _placementRepository.savePlacements(projectPath, _placements, groups: _groups);

    _ref.invalidate(placementsProvider);
    notifyListeners();
  }

  /// 配置物にズーム
  Future<void> zoomToPlacement(String placementId) async {
    await _cesiumController.zoomToPlacement(placementId);
  }

  /// スナップ設定を更新
  Future<void> updateSnapSettings({
    bool? gridEnabled,
    double? gridSize,
    bool? groundEnabled,
    bool? angleEnabled,
    double? angleStep,
  }) async {
    await _cesiumController.updateSnapSettings(
      gridEnabled: gridEnabled,
      gridSize: gridSize,
      groundEnabled: groundEnabled,
      angleEnabled: angleEnabled,
      angleStep: angleStep,
    );
  }

  // ============================================
  // ドローン配置モード
  // ============================================

  /// ドローン配置モードを開始
  /// 
  /// 地図上でクリックされた位置にドローンフォーメーションを配置する
  void startDronePlacementMode({
    required DroneFormation formation,
    required double altitude,
    required double scale,
    required double pointSize,
    required bool useIndividualColors,
    String? customColor,
  }) {
    _pendingDroneFormation = formation;
    _pendingDroneSettings = {
      'altitude': altitude,
      'scale': scale,
      'pointSize': pointSize,
      'useIndividualColors': useIndividualColors,
      'customColor': customColor,
    };
    _ref.read(placementModeStateProvider.notifier).state = PlacementModeState.placing;
    notifyListeners();
  }

  /// ドローン配置モードをキャンセル
  void cancelDronePlacementMode() {
    _pendingDroneFormation = null;
    _pendingDroneSettings = null;
    _ref.read(placementModeStateProvider.notifier).state = PlacementModeState.idle;
    notifyListeners();
  }

  /// ドローン配置モード中かどうか
  bool get isDronePlacementMode => _pendingDroneFormation != null;

  // ============================================
  // ドローンフォーメーション配置
  // ============================================

  /// ドローンフォーメーションを配置
  Future<PlacedDroneFormation> placeDroneFormation({
    required DroneFormation formation,
    required GeoPosition basePosition,
    double altitude = 50.0,
    double heading = 0.0,
    double scale = 1.0,
    double pointSize = 10.0,
    String? customColor,
    bool useIndividualColors = true,
  }) async {
    final projectPath = _projectPath;
    if (projectPath == null) {
      throw StateError('プロジェクトが開かれていません');
    }

    final placedFormation = PlacedDroneFormation(
      id: _uuid.v4(),
      formationId: formation.id,
      name: formation.name,
      baseLongitude: basePosition.longitude,
      baseLatitude: basePosition.latitude,
      altitude: altitude,
      heading: heading,
      scale: scale,
      pointSize: pointSize,
      customColor: customColor,
      useIndividualColors: useIndividualColors,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // CesiumJSに追加
    await _addDroneFormationToCesium(formation, placedFormation);

    // リポジトリに保存
    await _droneFormationRepository.savePlacedFormation(projectPath, placedFormation);
    
    _ref.invalidate(placedDroneFormationsProvider);
    notifyListeners();

    return placedFormation;
  }

  /// 配置済みドローンフォーメーションを更新
  Future<void> updatePlacedDroneFormation(PlacedDroneFormation placedFormation) async {
    final projectPath = _projectPath;
    if (projectPath == null) return;

    final updated = placedFormation.copyWith(updatedAt: DateTime.now());
    
    // CesiumJSを更新
    final formation = await _droneFormationRepository.getFormationById(
      projectPath,
      placedFormation.formationId,
    );
    if (formation != null) {
      await _updateDroneFormationInCesium(formation, updated);
    }

    // リポジトリに保存
    await _droneFormationRepository.updatePlacedFormation(projectPath, updated);
    
    _ref.invalidate(placedDroneFormationsProvider);
    notifyListeners();
  }

  /// 配置済みドローンフォーメーションを更新（チルト付き）- 後方互換性のため残す
  Future<void> updatePlacedDroneFormationWithTilt(
    PlacedDroneFormation placedFormation,
    double tilt,
  ) async {
    await updatePlacedDroneFormation(placedFormation.copyWith(tilt: tilt));
  }

  /// 配置済みドローンフォーメーションを削除
  Future<void> removePlacedDroneFormation(String placedFormationId) async {
    final projectPath = _projectPath;
    if (projectPath == null) return;

    await _cesiumController.removeDroneFormation(placedFormationId);
    await _droneFormationRepository.removePlacedFormation(projectPath, placedFormationId);
    
    _ref.invalidate(placedDroneFormationsProvider);
    notifyListeners();
  }

  /// ドローンフォーメーションにズーム
  Future<void> zoomToDroneFormation(String placedFormationId) async {
    await _cesiumController.zoomToDroneFormation(placedFormationId);
  }

  /// ドローンフォーメーションの表示/非表示を切り替え
  Future<void> setDroneFormationVisible(String formationId, bool visible) async {
    await _cesiumController.setDroneFormationVisible(formationId, visible);
  }

  /// ドローンフォーメーションのスタイルを更新（リアルタイム）
  Future<void> updateDroneFormationStyle({
    required String formationId,
    double? pointSize,
    double? glowIntensity,
    bool? useIndividualColors,
    String? customColor,
  }) async {
    await _cesiumController.updateDroneFormationStyle(
      formationId: formationId,
      pointSize: pointSize,
      glowIntensity: glowIntensity,
      useIndividualColors: useIndividualColors,
      customColor: customColor,
    );
  }

  /// 配置済みドローンフォーメーションを読み込み
  Future<void> loadPlacedDroneFormations() async {
    final projectPath = _projectPath;
    if (projectPath == null) return;

    final placedFormations = await _droneFormationRepository.loadPlacedFormations(projectPath);

    for (final placed in placedFormations) {
      final formation = await _droneFormationRepository.getFormationById(
        projectPath,
        placed.formationId,
      );
      if (formation != null) {
        await _addDroneFormationToCesium(formation, placed);
      }
    }
  }

  // ============================================
  // プライベートメソッド
  // ============================================

  /// 配置物をCesiumJSに追加
  Future<void> _addPlacementToCesium(Placement placement) async {
    // TODO: アセットのモデルURLを取得
    // 現在はプレースホルダー
    final modelUrl = 'assets/models/${placement.assetId}.glb';
    await _cesiumController.addPlacement(placement.toJson(), modelUrl);
  }

  /// ドローンフォーメーションをCesiumJSに追加
  Future<void> _addDroneFormationToCesium(
    DroneFormation formation,
    PlacedDroneFormation placed,
  ) async {
    await _cesiumController.addDroneFormation(
      id: placed.id,
      name: placed.name,
      drones: formation.drones.map((d) => d.toJson()).toList(),
      basePosition: GeoPosition(
        longitude: placed.baseLongitude,
        latitude: placed.baseLatitude,
      ),
      altitude: placed.altitude,
      heading: placed.heading,
      tilt: placed.tilt,
      scale: placed.scale,
      pointSize: placed.pointSize,
      glowIntensity: placed.glowIntensity,
      customColor: placed.customColor,
      useIndividualColors: placed.useIndividualColors,
    );
  }

  /// CesiumJS上のドローンフォーメーションを更新
  Future<void> _updateDroneFormationInCesium(
    DroneFormation formation,
    PlacedDroneFormation placed,
  ) async {
    await _cesiumController.updateDroneFormation({
      'id': placed.id,
      'name': placed.name,
      'drones': formation.drones.map((d) => d.toJson()).toList(),
      'basePosition': {
        'longitude': placed.baseLongitude,
        'latitude': placed.baseLatitude,
      },
      'altitude': placed.altitude,
      'heading': placed.heading,
      'tilt': placed.tilt,
      'scale': placed.scale,
      'pointSize': placed.pointSize,
      'glowIntensity': placed.glowIntensity,
      if (placed.customColor != null) 'customColor': placed.customColor,
      'useIndividualColors': placed.useIndividualColors,
    });
  }

  // ============================================
  // コールバックハンドラ
  // ============================================

  void _onPlacementConfirmed(String assetId, GeoPosition position) async {
    if (_currentAssetIdForPlacement == null) return;

    final projectPath = _projectPath;
    if (projectPath == null) return;

    final placement = Placement(
      id: _uuid.v4(),
      assetId: assetId,
      name: assetId, // TODO: アセット名を取得
      position: position,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _placements.add(placement);
    await _addPlacementToCesium(placement);
    await _placementRepository.savePlacements(projectPath, _placements, groups: _groups);

    // 使用回数をインクリメント
    _ref.read(assetNotifierProvider.notifier).incrementUsage(assetId);

    _ref.invalidate(placementsProvider);
    notifyListeners();
  }

  void _onPlacementSelected(String placementId) {
    _selectedPlacementId = placementId;
    _ref.read(selectedPlacementIdProvider.notifier).state = placementId;
    notifyListeners();
  }

  void _onPlacementDeselected() {
    _selectedPlacementId = null;
    _ref.read(selectedPlacementIdProvider.notifier).state = null;
    notifyListeners();
  }

  void _onPlacementCancelled() {
    _currentAssetIdForPlacement = null;
    _pendingDroneFormation = null;
    _pendingDroneSettings = null;
    _ref.read(placementModeStateProvider.notifier).state = PlacementModeState.idle;
    _ref.read(placingAssetIdProvider.notifier).state = null;
    notifyListeners();
  }

  void _onMapClicked(GeoPosition position) async {
    // 位置ピックモード中の場合
    if (_positionPickTargetId != null && _onPositionPicked != null) {
      _onPositionPicked!(position);
      _positionPickTargetId = null;
      _onPositionPicked = null;
      notifyListeners();
      return;
    }

    // ドローン配置モード中の場合
    if (_pendingDroneFormation != null && _pendingDroneSettings != null) {
      try {
        await placeDroneFormation(
          formation: _pendingDroneFormation!,
          basePosition: position,
          altitude: _pendingDroneSettings!['altitude'] as double,
          scale: _pendingDroneSettings!['scale'] as double,
          pointSize: _pendingDroneSettings!['pointSize'] as double,
          useIndividualColors: _pendingDroneSettings!['useIndividualColors'] as bool,
          customColor: _pendingDroneSettings!['customColor'] as String?,
        );
      } finally {
        // 配置モード終了
        _pendingDroneFormation = null;
        _pendingDroneSettings = null;
        _ref.read(placementModeStateProvider.notifier).state = PlacementModeState.idle;
        notifyListeners();
      }
    }
  }

  /// ドローン位置変更モードを開始
  void startDronePositionPickMode(
    String formationId, {
    required void Function(GeoPosition) onPositionPicked,
  }) {
    _positionPickTargetId = formationId;
    _onPositionPicked = onPositionPicked;
    notifyListeners();
  }
}

/// PlacementControllerのプロバイダー
final placementControllerProvider = ChangeNotifierProvider<PlacementController?>((ref) {
  final cesiumController = ref.watch(cesiumControllerProvider);
  if (cesiumController == null) {
    return null;
  }
  
  final placementRepository = ref.read(placementRepositoryProvider);
  final droneFormationRepository = ref.read(droneFormationRepositoryProvider);
  
  return PlacementController(
    cesiumController,
    placementRepository,
    droneFormationRepository,
    ref,
  );
});
