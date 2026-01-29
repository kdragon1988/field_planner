import 'package:logging/logging.dart';

/// アプリケーション全体のログ設定を管理するクラス
///
/// ログレベルの設定、フォーマット、機微情報のマスク処理を行う
class AppLogger {
  AppLogger._();

  static bool _isInitialized = false;

  /// ロギングシステムを初期化
  ///
  /// アプリケーション起動時に一度だけ呼び出す
  static void initialize({Level level = Level.ALL}) {
    if (_isInitialized) return;

    Logger.root.level = level;
    Logger.root.onRecord.listen((record) {
      final message = _sanitizeMessage(record.message);
      final time = record.time.toIso8601String();
      final levelName = record.level.name;
      final loggerName = record.loggerName;

      // ignore: avoid_print
      print('[$levelName] $time [$loggerName] $message');

      if (record.error != null) {
        // ignore: avoid_print
        print('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('StackTrace: ${record.stackTrace}');
      }
    });

    _isInitialized = true;
  }

  /// メッセージから機微情報をマスクする
  ///
  /// ファイルパス、APIキーなどの機密情報を検出してマスク
  static String _sanitizeMessage(String message) {
    String sanitized = message;

    // APIキーパターンをマスク
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'([Aa]pi[Kk]ey|[Tt]oken|[Ss]ecret)[\s:=]+[A-Za-z0-9_-]+'),
      (match) => '${match.group(1)}=***MASKED***',
    );

    // ユーザーディレクトリパスを部分マスク
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'/Users/[^/]+/'),
      (match) => '/Users/***/');

    return sanitized;
  }

  /// 指定した名前でLoggerインスタンスを取得
  static Logger getLogger(String name) {
    return Logger(name);
  }
}

/// ログ出力用のミックスイン
///
/// クラスに組み込むことで簡単にログ機能を利用可能
mixin LoggableMixin {
  /// このクラス用のLogger
  Logger get logger => Logger(runtimeType.toString());

  /// デバッグログを出力
  void logDebug(String message) => logger.fine(message);

  /// 情報ログを出力
  void logInfo(String message) => logger.info(message);

  /// 警告ログを出力
  void logWarning(String message) => logger.warning(message);

  /// エラーログを出力
  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    logger.severe(message, error, stackTrace);
  }
}
