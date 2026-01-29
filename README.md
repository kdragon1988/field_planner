# Field Planner

Flutter Desktop + CesiumJS による3Dイベント会場設計アプリケーション

## 概要

DJI Terra等から出力した3Dデータ（メッシュ）および点群を取り込み、Cesium 3D Map / Google Maps 等の地図レイヤー上で表示し、イベント会場（テント・ステージ等）を **Minecraftのように** 直感的に配置して、計測・保存・共有を行うデスクトップアプリです。

## 主な機能

### 3Dデータ・点群の取り込み
- 対応フォーマット: LAS/LAZ, PLY, E57, OBJ, FBX, glTF/GLB
- ローカル3D Tiles変換によるストリーミング表示
- ジオリファレンス情報の自動読み取り

### ベースマップ
- Cesium Ion World Imagery
- Bing Maps (Aerial / Roads)
- Google Maps / Satellite / Hybrid
- OpenStreetMap
- ESRI World Imagery
- カスタムタイルURL

### アセット配置（Minecraft風）
- 内蔵アセット: テント、ステージ、バリケード、テーブル、椅子など
- クリック配置、ドラッグ移動
- 回転・スケール・高さ調整
- グリッドスナップ、地面スナップ、角度スナップ
- 複製、整列、グループ化

### 計測機能
- 距離計測（2点/ポリライン）
- 面積計測（ポリゴン）
- 高さ/標高差計測
- CSV/JSON/GeoJSONエクスポート

### プロジェクト管理
- ローカル保存（クラウド不要）
- 自動保存（2分毎、世代管理）
- ZIP形式でのプロジェクト共有
- クラッシュ時リカバリ

## 対応プラットフォーム

- Windows 10/11 (x64)
- macOS 12+ (Apple Silicon / Intel)

## 技術スタック

| レイヤー | 技術 |
|---------|------|
| UI | Flutter Desktop |
| 3D地図・表示 | CesiumJS (WebView埋め込み) |
| ネイティブ連携 | Flutter ↔ JS Bridge |
| 点群変換 | PDAL / Entwine |
| メッシュ変換 | obj2gltf / gltf-pipeline |

## プロジェクト構造

```
field_planner/
├── lib/
│   ├── core/           # コア機能（定数、例外、ユーティリティ）
│   ├── data/           # データ層（モデル、リポジトリ、サービス）
│   ├── domain/         # ドメイン層（エンティティ、ユースケース）
│   ├── presentation/   # プレゼンテーション層（画面、ウィジェット）
│   └── infrastructure/ # インフラ層（WebView、変換処理）
├── assets/
│   ├── models/         # 内蔵3Dアセット
│   ├── cesium/         # CesiumJS関連ファイル
│   └── icons/          # アイコン
├── windows/            # Windows固有設定
├── macos/              # macOS固有設定
└── plans/              # 開発計画書
```

## 開発計画

12工程に分割した詳細な開発計画書は `plans/` フォルダを参照してください。

| 工程 | 内容 |
|------|------|
| 01 | 環境構築・プロジェクト初期化 |
| 02 | CesiumJS統合・JS Bridge実装 |
| 03 | プロジェクト管理機能 |
| 04 | ベースマップ統合 |
| 05 | 3Dデータ・点群インポート |
| 06 | データ変換パイプライン |
| 07 | レイヤー管理機能 |
| 08 | アセット管理・パレット |
| 09 | アセット配置機能 |
| 10 | 計測機能 |
| 11 | UI/UX・画面レイアウト |
| 12 | 自動保存・共有・最終調整 |

## データ形式

### プロジェクト構造
```
MyProject.agproj/
├── project.json        # プロジェクト設定
├── placements.json     # 配置物データ
├── measurements.json   # 計測データ
├── layers/             # 変換済み3D Tiles
├── imports/            # インポート元データ
├── thumbnails/         # サムネイル
└── backups/            # 自動バックアップ
```

## ライセンス・注意事項

- **Google Maps**: APIキーと利用規約の遵守が必要
- **Cesium**: 利用形態により条件が異なる
- **変換ツール**: PDAL/Entwine等のOSSライセンスを確認

## 開発環境セットアップ

```bash
# Flutter SDKのインストール確認
flutter --version

# Desktopサポートの有効化
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop

# 依存パッケージのインストール
flutter pub get

# 実行
flutter run -d windows  # または macos
```

## キーボードショートカット

| ショートカット | 機能 |
|---------------|------|
| Ctrl+N | 新規プロジェクト |
| Ctrl+O | 開く |
| Ctrl+S | 保存 |
| Ctrl+D | 複製 |
| D | 距離計測 |
| A | 面積計測 |
| H | 高さ計測 |
| F11 | プレゼンテーションモード |
| Escape | キャンセル |

## 貢献

Issue や Pull Request を歓迎します。

## 作者

kdragon1988
