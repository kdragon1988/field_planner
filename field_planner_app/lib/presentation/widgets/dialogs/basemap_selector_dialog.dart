import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/basemap.dart';
import '../../providers/basemap_provider.dart';

/// ベースマップ選択ダイアログ
///
/// 利用可能なベースマップ一覧を表示し、選択・切り替えを行う
class BaseMapSelectorDialog extends ConsumerWidget {
  const BaseMapSelectorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProvider = ref.watch(currentBaseMapProvider);
    final opacity = ref.watch(baseMapOpacityProvider);

    return AlertDialog(
      title: const Text('ベースマップ'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // マップ選択（Google Maps 衛星、Google Maps 地図、OpenStreetMap のみ表示）
            ...[
              BaseMapProvider.googleSatellite,
              BaseMapProvider.googleRoad,
              BaseMapProvider.osm,
            ].map((provider) => _buildMapTile(
                  context,
                  ref,
                  provider,
                  currentProvider == provider,
                )),

            const Divider(height: 24),

            // 不透明度スライダー
            Row(
              children: [
                const Text('不透明度'),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: opacity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(opacity * 100).round()}%',
                    onChanged: (value) {
                      ref.read(baseMapControllerProvider).setOpacity(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text('${(opacity * 100).round()}%'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  Widget _buildMapTile(
    BuildContext context,
    WidgetRef ref,
    BaseMapProvider provider,
    bool isSelected,
  ) {
    IconData icon;
    String subtitle;

    switch (provider) {
      case BaseMapProvider.googleSatellite:
        icon = Icons.satellite_alt;
        subtitle = '高精細な衛星写真';
        break;
      case BaseMapProvider.googleRoad:
        icon = Icons.map;
        subtitle = '道路・建物名を表示';
        break;
      case BaseMapProvider.osm:
        icon = Icons.public;
        subtitle = '無料・オープンソースの地図';
        break;
      case BaseMapProvider.esriWorld:
        icon = Icons.satellite;
        subtitle = '衛星画像';
        break;
      case BaseMapProvider.esriNatGeo:
        icon = Icons.terrain;
        subtitle = 'ナショナルジオグラフィック';
        break;
      case BaseMapProvider.bing:
        icon = Icons.map;
        subtitle = 'Microsoft Bing Maps';
        break;
      case BaseMapProvider.google:
        icon = Icons.map;
        subtitle = 'Google Maps';
        break;
      default:
        icon = Icons.map;
        subtitle = '';
    }

    return RadioListTile<BaseMapProvider>(
      value: provider,
      groupValue: isSelected ? provider : null,
      onChanged: (value) {
        if (value != null) {
          ref.read(baseMapControllerProvider).changeBaseMap(value);
        }
      },
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(provider.displayName),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      selected: isSelected,
    );
  }
}
