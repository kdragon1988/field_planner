/// ドローンショーパネル
/// 
/// ドローンフォーメーションのインポート・配置・調整を行うパネル。
/// 
/// 主な機能:
/// - JSONからのインポート
/// - 配置済みフォーメーション一覧
/// - 位置・角度・高さ・ポイントサイズ・輝度の調整
/// - 複数フォーメーションの管理

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/drone_formation.dart';
import '../../../data/models/geo_position.dart';
import '../../providers/asset_provider.dart';
import '../../providers/placement_provider.dart';
import '../dialogs/drone_import_dialog.dart';

/// 選択中のドローンフォーメーションID
final selectedDroneFormationIdProvider = StateProvider<String?>((ref) => null);

/// ドローンショーパネル
class DroneShowPanel extends ConsumerStatefulWidget {
  const DroneShowPanel({super.key});

  @override
  ConsumerState<DroneShowPanel> createState() => _DroneShowPanelState();
}

class _DroneShowPanelState extends ConsumerState<DroneShowPanel> {
  @override
  Widget build(BuildContext context) {
    final formationsAsync = ref.watch(droneFormationsProvider);
    final placedFormationsAsync = ref.watch(placedDroneFormationsProvider);
    final selectedId = ref.watch(selectedDroneFormationIdProvider);

    return Column(
      children: [
        // インポートボタン
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showImportDialog,
              icon: const Icon(Icons.upload_file),
              label: const Text('JSONからインポート'),
            ),
          ),
        ),
        const Divider(height: 1),

        // インポート済みフォーメーション一覧
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.folder, size: 16),
              const SizedBox(width: 4),
              const Text('インポート済み', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              formationsAsync.when(
                data: (formations) => Text('${formations.length}件', style: const TextStyle(fontSize: 12)),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // インポート済みリスト
        Expanded(
          flex: 1,
          child: formationsAsync.when(
            data: (formations) {
              if (formations.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flight, size: 32, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('フォーメーションなし', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: formations.length,
                itemBuilder: (context, index) {
                  final formation = formations[index];
                  return _FormationCard(
                    formation: formation,
                    onPlace: () => _showPlacementDialog(formation),
                    onDelete: () => _deleteFormation(formation),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('エラー: $e')),
          ),
        ),

        const Divider(height: 1),

        // 配置済みフォーメーション一覧
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.place, size: 16),
              const SizedBox(width: 4),
              const Text('配置済み', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              placedFormationsAsync.when(
                data: (placed) => Text('${placed.length}件', style: const TextStyle(fontSize: 12)),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // 配置済みリスト
        Expanded(
          flex: 2,
          child: placedFormationsAsync.when(
            data: (placedFormations) {
              if (placedFormations.isEmpty) {
                return const Center(
                  child: Text('配置済みフォーメーションなし', style: TextStyle(color: Colors.grey, fontSize: 12)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: placedFormations.length,
                itemBuilder: (context, index) {
                  final placed = placedFormations[index];
                  final isSelected = selectedId == placed.id;
                  return _PlacedFormationCard(
                    placedFormation: placed,
                    isSelected: isSelected,
                    onTap: () {
                      ref.read(selectedDroneFormationIdProvider.notifier).state = placed.id;
                    },
                    onZoom: () => _zoomToFormation(placed),
                    onDelete: () => _deletePlacedFormation(placed),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('エラー: $e')),
          ),
        ),
      ],
    );
  }

  void _showImportDialog() async {
    final result = await showDialog<DroneFormation>(
      context: context,
      builder: (context) => const DroneImportDialog(),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${result.name}」をインポートしました（${result.droneCount}機）')),
      );
    }
  }

  void _showPlacementDialog(DroneFormation formation) async {
    final settings = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DronePlacementSettingsDialog(formation: formation),
    );

    if (settings == null || !mounted) return;

    final controller = ref.read(placementControllerProvider);
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('マップが初期化されていません')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('地図上をクリックして「${formation.name}」の配置位置を指定してください'),
        duration: const Duration(seconds: 5),
      ),
    );

    controller.startDronePlacementMode(
      formation: formation,
      altitude: settings['altitude'] as double,
      scale: settings['scale'] as double,
      pointSize: settings['pointSize'] as double,
      useIndividualColors: settings['useIndividualColors'] as bool,
      customColor: settings['customColor'] as String?,
    );
  }

  void _deleteFormation(DroneFormation formation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('フォーメーションを削除'),
        content: Text('「${formation.name}」を削除しますか？\n配置済みのものも削除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(assetNotifierProvider.notifier).deleteDroneFormation(formation.id);
    }
  }

  void _zoomToFormation(PlacedDroneFormation placed) {
    ref.read(placementControllerProvider)?.zoomToDroneFormation(placed.id);
  }

  void _deletePlacedFormation(PlacedDroneFormation placed) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配置を削除'),
        content: Text('「${placed.name}」の配置を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(placementControllerProvider)?.removePlacedDroneFormation(placed.id);
      if (ref.read(selectedDroneFormationIdProvider) == placed.id) {
        ref.read(selectedDroneFormationIdProvider.notifier).state = null;
      }
    }
  }
}

/// インポート済みフォーメーションカード
class _FormationCard extends StatelessWidget {
  final DroneFormation formation;
  final VoidCallback onPlace;
  final VoidCallback onDelete;

  const _FormationCard({
    required this.formation,
    required this.onPlace,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.flight, size: 20),
        title: Text(formation.name, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          '${formation.droneCount}機 · ${formation.width.toStringAsFixed(0)}m×${formation.depth.toStringAsFixed(0)}m',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.place, size: 18),
              tooltip: '配置',
              onPressed: onPlace,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: '削除',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// 配置済みフォーメーションカード
class _PlacedFormationCard extends StatelessWidget {
  final PlacedDroneFormation placedFormation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onZoom;
  final VoidCallback onDelete;

  const _PlacedFormationCard({
    required this.placedFormation,
    required this.isSelected,
    required this.onTap,
    required this.onZoom,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(
          Icons.flight,
          size: 20,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
        title: Text(
          placedFormation.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        ),
        subtitle: Text(
          '高度: ${placedFormation.altitude.toStringAsFixed(0)}m · サイズ: ${placedFormation.pointSize.toStringAsFixed(0)}px',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 18),
              tooltip: 'ズーム',
              onPressed: onZoom,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: '削除',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
