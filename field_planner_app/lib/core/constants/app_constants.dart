/// アプリケーション全体で使用する定数を定義するクラス
///
/// アプリ名、バージョン、プロジェクト拡張子、自動保存間隔などの
/// 基本的な設定値を一元管理する
class AppConstants {
  AppConstants._();

  /// アプリケーション名
  static const String appName = 'Field Planner';

  /// アプリケーションバージョン
  static const String appVersion = '1.0.0';

  /// プロジェクトファイルの拡張子
  static const String projectExtension = '.agproj';

  /// 自動保存の間隔（秒）
  static const int autoSaveIntervalSeconds = 120;

  /// 最近使ったプロジェクトの最大保持数
  static const int maxRecentProjects = 10;

  /// バックアップの最大世代数
  static const int maxBackupGenerations = 5;

  /// デフォルトのグリッドサイズ（メートル）
  static const double defaultGridSize = 1.0;

  /// デフォルトのスナップ角度（度）
  static const double defaultSnapAngle = 15.0;

  /// デフォルトの中心座標（東京）
  static const double defaultCenterLatitude = 35.6895;
  static const double defaultCenterLongitude = 139.6917;
  static const double defaultCenterHeight = 1000.0;
}

/// APIキー関連の定数
///
/// 注意: 本番環境では環境変数や安全な方法でキーを管理してください
class ApiKeys {
  ApiKeys._();

  /// Cesium Ionアクセストークン
  /// 取得方法: https://ion.cesium.com/ でアカウント作成後、
  /// Access Tokens ページでトークンを生成
  static const String cesiumIonToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiJiMGMwMTQ3YS05YzczLTQ4NjYtODFjYS01MmIxNzUwNWVjOWUiLCJpZCI6Mzg0Njg1LCJpYXQiOjE3Njk2NjY3Mjl9.G7L65c7Cxh0oC0c4mUQs1zKf79jL1SOz9fkNhP_A19s';

  /// Google Maps APIキー
  /// 取得方法: https://console.cloud.google.com/ でMap Tiles APIを有効化
  static const String googleMapsApiKey = 'AIzaSyBm5JoyXcKZXduNfq0HCNmbYNHfYANzTpc';
}

/// レイヤー関連の定数
class LayerConstants {
  LayerConstants._();

  /// デフォルトの不透明度
  static const double defaultOpacity = 1.0;

  /// 点群のデフォルト点サイズ
  static const double defaultPointSize = 2.0;

  /// 3D Tilesの最大スクリーンスペースエラー
  static const double maxScreenSpaceError = 16.0;
}

/// 計測関連の定数
class MeasurementConstants {
  MeasurementConstants._();

  /// デフォルトの線の太さ
  static const double defaultLineWidth = 2.0;

  /// デフォルトの色（赤）
  static const String defaultColor = '#FF0000';

  /// 面積計測のデフォルト塗りつぶし透明度
  static const double defaultFillOpacity = 0.3;
}
