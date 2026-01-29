import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/basemap.dart';
import '../../infrastructure/webview/cesium_controller.dart';
import '../providers/basemap_provider.dart';
import '../providers/cesium_provider.dart';
import '../providers/measurement_provider.dart';
import '../providers/tileset_provider.dart';
import '../widgets/cesium_map_widget.dart';
import '../widgets/dialogs/tileset_import_dialog.dart';
import '../widgets/panels/layer_panel.dart';
import '../widgets/panels/asset_palette.dart';
import '../widgets/panels/measurement_panel.dart';
import '../widgets/panels/placement_inspector.dart';
import '../widgets/panels/tileset_inspector.dart';

/// メイン画面
///
/// 左パネル（レイヤー/アセット/計測）、中央3Dビュー、右パネル（プロパティ）を表示
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with SingleTickerProviderStateMixin {
  // パネル表示状態
  bool _showLeftPanel = true;
  bool _showRightPanel = true;
  bool _presentationMode = false;

  // パネルサイズ
  final double _leftPanelWidth = 280;
  final double _rightPanelWidth = 320;

  // 左パネルのタブコントローラ
  late TabController _leftPanelTabController;

  // 現在のツール
  String _currentTool = 'select';

  // 2D/3Dモード状態
  String _sceneMode = '3d';

  @override
  void initState() {
    super.initState();
    _leftPanelTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _leftPanelTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraPosition = ref.watch(cameraPositionProvider);

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Column(
          children: [
            // ツールバー（プレゼンテーションモードでは非表示）
            if (!_presentationMode) _buildToolbar(),

            // メインコンテンツ
            Expanded(
              child: Row(
                children: [
                  // 左パネル
                  if (_showLeftPanel && !_presentationMode) _buildLeftPanel(),

                  // 3Dビュー（中央）
                  Expanded(
                    child: _build3DView(),
                  ),

                  // 右パネル
                  if (_showRightPanel && !_presentationMode) _buildRightPanel(),
                ],
              ),
            ),

            // ステータスバー（プレゼンテーションモードでは非表示）
            if (!_presentationMode) _buildStatusBar(cameraPosition),
          ],
        ),
      ),
    );
  }

  /// キーボードイベント処理
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Ctrl+N: 新規プロジェクト
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyN) {
      // TODO: 新規プロジェクト
    }
    // Ctrl+O: 開く
    else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyO) {
      // TODO: 開く
    }
    // Ctrl+S: 保存
    else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) {
      // TODO: 保存
    }
    // Escape: 選択解除
    else if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _currentTool = 'select');
    }
    // F11: プレゼンテーションモード
    else if (event.logicalKey == LogicalKeyboardKey.f11) {
      setState(() => _presentationMode = !_presentationMode);
    }
    // D: 距離計測
    else if (event.logicalKey == LogicalKeyboardKey.keyD) {
      _leftPanelTabController.animateTo(2);
    }
    // A: 面積計測
    else if (event.logicalKey == LogicalKeyboardKey.keyA && !isCtrl) {
      _leftPanelTabController.animateTo(2);
    }
  }

  /// ツールバーを構築
  Widget _buildToolbar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          // ホームボタン
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'ホームに戻る',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const VerticalDivider(),

          // ツール選択
          _buildToolButton(
            icon: Icons.near_me,
            label: '選択',
            toolId: 'select',
          ),
          _buildToolButton(
            icon: Icons.pan_tool,
            label: '移動',
            toolId: 'pan',
          ),

          const VerticalDivider(),

          // ベースマップ切り替え
          PopupMenuButton<BaseMapProvider>(
            icon: const Icon(Icons.map),
            tooltip: 'ベースマップ',
            onSelected: (provider) {
              ref.read(baseMapControllerProvider).changeBaseMap(provider);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: BaseMapProvider.googleSatellite,
                child: Row(
                  children: [
                    Icon(Icons.satellite_alt, size: 18),
                    SizedBox(width: 8),
                    Text('Google Maps 衛星'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: BaseMapProvider.googleRoad,
                child: Row(
                  children: [
                    Icon(Icons.map, size: 18),
                    SizedBox(width: 8),
                    Text('Google Maps 地図'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: BaseMapProvider.osm,
                child: Row(
                  children: [
                    Icon(Icons.public, size: 18),
                    SizedBox(width: 8),
                    Text('OpenStreetMap'),
                  ],
                ),
              ),
            ],
          ),

          // 3Dデータインポート
          IconButton(
            icon: const Icon(Icons.add_box),
            tooltip: '3Dモデルをインポート',
            onPressed: _showTilesetImportDialog,
          ),

          const Spacer(),

          // 2D/3D切り替え
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '3d', icon: Icon(Icons.view_in_ar, size: 18)),
              ButtonSegment(value: '2d', icon: Icon(Icons.map, size: 18)),
            ],
            selected: {_sceneMode},
            onSelectionChanged: (value) {
              final mode = value.first;
              setState(() => _sceneMode = mode);
              ref.read(cesiumControllerProvider)?.setSceneMode(
                    mode == '2d' ? SceneMode.scene2D : SceneMode.scene3D,
                  );
            },
          ),

          const VerticalDivider(),

          // パネル表示切り替え
          IconButton(
            icon: Icon(
              _showLeftPanel ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            ),
            tooltip: '左パネル表示/非表示',
            onPressed: () {
              setState(() => _showLeftPanel = !_showLeftPanel);
            },
          ),
          IconButton(
            icon: Icon(
              _showRightPanel
                  ? Icons.view_sidebar
                  : Icons.view_sidebar_outlined,
            ),
            tooltip: '右パネル表示/非表示',
            onPressed: () {
              setState(() => _showRightPanel = !_showRightPanel);
            },
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'プレゼンテーションモード (F11)',
            onPressed: () {
              setState(() => _presentationMode = true);
            },
          ),
        ],
      ),
    );
  }

  /// ツールボタンを構築
  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required String toolId,
  }) {
    final isActive = _currentTool == toolId;

    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: isActive
              ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
              : null,
          foregroundColor:
              isActive ? Theme.of(context).primaryColor : null,
        ),
        onPressed: () {
          setState(() => _currentTool = toolId);
        },
      ),
    );
  }

  /// 左パネルを構築
  Widget _buildLeftPanel() {
    return Container(
      width: _leftPanelWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _leftPanelTabController,
            tabs: const [
              Tab(text: 'レイヤー'),
              Tab(text: 'アセット'),
              Tab(text: '計測'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _leftPanelTabController,
              children: const [
                LayerPanel(),
                AssetPalette(),
                MeasurementPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3Dビューを構築
  Widget _build3DView() {
    return Stack(
      children: [
        // CesiumJS WebView
        CesiumMapWidget(
          ionToken: ApiKeys.cesiumIonToken.isNotEmpty
              ? ApiKeys.cesiumIonToken
              : null,
          googleMapsApiKey: ApiKeys.googleMapsApiKey.isNotEmpty
              ? ApiKeys.googleMapsApiKey
              : null,
          onControllerCreated: (controller) {
            ref.read(cesiumControllerProvider.notifier).setController(controller);
            ref.read(cesiumInitializedProvider.notifier).state = true;

            controller.onCameraChanged = (position) {
              ref.read(cameraPositionProvider.notifier).updatePosition(position);
            };

            // 計測プロバイダーにCesiumControllerを設定
            ref.read(measurementProvider.notifier).updateController(controller);

            // TilesetプロバイダーにCesiumControllerを設定
            ref.read(tilesetProvider.notifier).setController(controller);
          },
        ),

        // プレゼンテーションモード終了ボタン
        if (_presentationMode)
          Positioned(
            top: 16,
            right: 16,
            child: IconButton.filled(
              icon: const Icon(Icons.fullscreen_exit),
              tooltip: 'プレゼンテーションモードを終了',
              onPressed: () {
                setState(() => _presentationMode = false);
              },
            ),
          ),

        // ビューコントロール
        Positioned(
          right: 16,
          bottom: _presentationMode ? 16 : 32,
          child: _buildViewControls(),
        ),

        // 座標表示
        Positioned(
          left: 16,
          bottom: _presentationMode ? 16 : 8,
          child: _buildCoordinateDisplay(),
        ),
      ],
    );
  }

  /// ビューコントロールを構築
  Widget _buildViewControls() {
    return Column(
      children: [
        FloatingActionButton.small(
          heroTag: 'zoom_in',
          onPressed: () {
            // TODO: ズームイン
          },
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'zoom_out',
          onPressed: () {
            // TODO: ズームアウト
          },
          child: const Icon(Icons.remove),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'home_view',
          onPressed: () {
            ref.read(cesiumControllerProvider)?.flyTo(
                  longitude: AppConstants.defaultCenterLongitude,
                  latitude: AppConstants.defaultCenterLatitude,
                  height: AppConstants.defaultCenterHeight,
                );
          },
          tooltip: 'ホームに戻る',
          child: const Icon(Icons.home),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'north_up',
          onPressed: () {
            // TODO: 北を上に
          },
          tooltip: '北を上に',
          child: const Icon(Icons.navigation),
        ),
      ],
    );
  }

  /// 座標表示を構築
  Widget _buildCoordinateDisplay() {
    final cameraPosition = ref.watch(cameraPositionProvider);
    if (cameraPosition == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '緯度: ${cameraPosition.latitude.toStringAsFixed(6)}°  '
        '経度: ${cameraPosition.longitude.toStringAsFixed(6)}°  '
        '高度: ${cameraPosition.height.toStringAsFixed(1)}m',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  /// 右パネルを構築
  Widget _buildRightPanel() {
    final tilesetState = ref.watch(tilesetProvider);
    final hasSelectedTileset = tilesetState.selectedTilesetId != null;

    return Container(
      width: _rightPanelWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              hasSelectedTileset ? '3Dモデル設定' : 'プロパティ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: hasSelectedTileset
                ? const TilesetInspector()
                : const PlacementInspector(),
          ),
        ],
      ),
    );
  }

  /// ステータスバーを構築
  Widget _buildStatusBar(cameraPosition) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // ツール表示
          Text(
            'ツール: ${_currentTool == 'select' ? '選択' : '移動'}',
            style: const TextStyle(fontSize: 11),
          ),
          const VerticalDivider(),
          
          // 座標表示
          if (cameraPosition != null)
            Text(
              '緯度: ${cameraPosition.latitude.toStringAsFixed(6)}° '
              '経度: ${cameraPosition.longitude.toStringAsFixed(6)}° '
              '高度: ${cameraPosition.height.toStringAsFixed(1)}m',
              style: const TextStyle(fontSize: 11),
            ),
          const Spacer(),
          
          // ショートカットヘルプ
          TextButton.icon(
            icon: const Icon(Icons.keyboard, size: 14),
            label: const Text('ショートカット', style: TextStyle(fontSize: 11)),
            onPressed: _showShortcutHelp,
          ),
          const VerticalDivider(),
          
          // バージョン
          Text(
            'v${AppConstants.appVersion}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 3Dモデルインポートダイアログを表示
  Future<void> _showTilesetImportDialog() async {
    final result = await showDialog<TilesetImportResult>(
      context: context,
      builder: (context) => const TilesetImportDialog(),
    );

    if (result != null && mounted) {
      // Tilesetを追加
      await ref.read(tilesetProvider.notifier).addTileset(
            name: result.name,
            tilesetJsonPath: result.tilesetJsonPath,
            folderPath: result.folderPath,
            flyTo: result.flyToAfterImport,
            clipGoogleTiles: result.clipGoogleTiles,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('3Dモデル「${result.name}」をインポートしました')),
        );
      }
    }
  }

  void _showShortcutHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('キーボードショートカット'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShortcutRow('Ctrl+N', '新規プロジェクト'),
              _ShortcutRow('Ctrl+O', 'プロジェクトを開く'),
              _ShortcutRow('Ctrl+S', '保存'),
              Divider(),
              _ShortcutRow('Escape', '選択解除'),
              _ShortcutRow('Delete', '選択オブジェクトを削除'),
              _ShortcutRow('Ctrl+D', '複製'),
              Divider(),
              _ShortcutRow('D', '距離計測'),
              _ShortcutRow('A', '面積計測'),
              _ShortcutRow('H', '高さ計測'),
              Divider(),
              _ShortcutRow('F11', 'プレゼンテーションモード'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String shortcut;
  final String description;

  const _ShortcutRow(this.shortcut, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(description),
        ],
      ),
    );
  }
}
