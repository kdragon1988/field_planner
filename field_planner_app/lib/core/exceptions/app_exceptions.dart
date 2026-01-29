/// アプリケーション固有の例外の基底クラス
///
/// すべてのカスタム例外はこのクラスを継承する
abstract class AppException implements Exception {
  /// エラーメッセージ
  final String message;

  /// 元の例外（ラップしている場合）
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (Caused by: $cause)' : ''}';
}

/// プロジェクト読み込みに関する例外
///
/// プロジェクトファイルが見つからない、破損している場合などに使用
class ProjectLoadException extends AppException {
  /// プロジェクトのパス
  final String projectPath;

  const ProjectLoadException(
    super.message, {
    required this.projectPath,
    super.cause,
  });

  @override
  String toString() =>
      'ProjectLoadException: $message (path: $projectPath)${cause != null ? ' (Caused by: $cause)' : ''}';
}

/// プロジェクト保存に関する例外
class ProjectSaveException extends AppException {
  /// プロジェクトのパス
  final String projectPath;

  const ProjectSaveException(
    super.message, {
    required this.projectPath,
    super.cause,
  });

  @override
  String toString() =>
      'ProjectSaveException: $message (path: $projectPath)${cause != null ? ' (Caused by: $cause)' : ''}';
}

/// 未対応フォーマットの例外
///
/// インポート時に未対応のファイル形式が指定された場合に使用
class UnsupportedFormatException extends AppException {
  /// ファイル拡張子
  final String extension;

  const UnsupportedFormatException(this.extension)
      : super('未対応のフォーマットです: $extension');

  @override
  String toString() => 'UnsupportedFormatException: 未対応のフォーマットです: $extension';
}

/// データ変換に関する例外
///
/// 点群やメッシュの3D Tiles変換時のエラーに使用
class ConversionException extends AppException {
  const ConversionException(super.message, {super.cause});
}

/// 変換キャンセル例外
class ConversionCancelledException extends AppException {
  const ConversionCancelledException() : super('変換がキャンセルされました');
}

/// ベースマップに関する例外
class BaseMapException extends AppException {
  /// プロバイダ名
  final String? provider;

  const BaseMapException(super.message, {this.provider, super.cause});

  @override
  String toString() =>
      'BaseMapException: $message${provider != null ? ' (provider: $provider)' : ''}';
}

/// エクスポートに関する例外
class ExportException extends AppException {
  const ExportException(super.message, {super.cause});
}

/// インポートに関する例外
class ImportException extends AppException {
  const ImportException(super.message, {super.cause});
}

/// 計測に関する例外
class MeasurementException extends AppException {
  const MeasurementException(super.message, {super.cause});
}

/// 配置に関する例外
class PlacementException extends AppException {
  const PlacementException(super.message, {super.cause});
}

/// WebView/CesiumJS通信に関する例外
class CesiumBridgeException extends AppException {
  const CesiumBridgeException(super.message, {super.cause});
}
