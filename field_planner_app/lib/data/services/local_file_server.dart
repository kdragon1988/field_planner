import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

import '../../core/utils/logger.dart';

/// ローカルファイルサーバー
///
/// 3D TilesなどのローカルファイルをHTTP経由で提供するためのサーバー。
/// WebViewからのfile://プロトコルアクセス制限を回避するために使用。
class LocalFileServer with LoggableMixin {
  static LocalFileServer? _instance;
  static LocalFileServer get instance => _instance ??= LocalFileServer._();

  LocalFileServer._();

  HttpServer? _server;

  /// サーバーが起動中かどうか
  bool get isRunning => _server != null;

  /// サーバーのベースURL
  String? get baseUrl => _server != null ? 'http://localhost:${_server!.port}' : null;

  /// サーバーのポート
  int? get port => _server?.port;

  /// 提供中のディレクトリマッピング（マウントパス -> ローカルパス）
  final Map<String, String> _mountedPaths = {};

  /// サーバーを起動
  ///
  /// [port] 使用するポート番号（0の場合は自動選択）
  Future<void> start({int port = 0}) async {
    if (_server != null) {
      logInfo('Server already running on port ${_server!.port}');
      return;
    }

    try {
      // CORSを許可するミドルウェア
      shelf.Middleware corsMiddleware() {
        return (shelf.Handler innerHandler) {
          return (shelf.Request request) async {
            // プリフライトリクエストの処理
            if (request.method == 'OPTIONS') {
              return shelf.Response.ok('', headers: _corsHeaders);
            }

            final response = await innerHandler(request);
            return response.change(headers: _corsHeaders);
          };
        };
      }

      // ルーターを作成
      final handler = const shelf.Pipeline()
          .addMiddleware(corsMiddleware())
          .addMiddleware(shelf.logRequests(logger: (message, isError) {
            if (isError) {
              logError('[LocalFileServer] $message');
            } else {
              logDebug('[LocalFileServer] $message');
            }
          }))
          .addHandler(_handleRequest);

      _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
      logInfo('Local file server started on http://localhost:${_server!.port}');
    } catch (e, stackTrace) {
      logError('Failed to start local file server', e, stackTrace);
      rethrow;
    }
  }

  /// サーバーを停止
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _mountedPaths.clear();
      logInfo('Local file server stopped');
    }
  }

  /// ディレクトリをマウント
  ///
  /// [mountPath] URLのパス（例: '/tileset1'）
  /// [localPath] ローカルディレクトリのパス
  ///
  /// Returns: アクセス用のURL
  String mountDirectory(String mountPath, String localPath) {
    // マウントパスを正規化
    if (!mountPath.startsWith('/')) {
      mountPath = '/$mountPath';
    }

    _mountedPaths[mountPath] = localPath;
    logInfo('Mounted directory: $mountPath -> $localPath');

    return '$baseUrl$mountPath';
  }

  /// ディレクトリをアンマウント
  void unmountDirectory(String mountPath) {
    if (!mountPath.startsWith('/')) {
      mountPath = '/$mountPath';
    }

    _mountedPaths.remove(mountPath);
    logInfo('Unmounted directory: $mountPath');
  }

  /// 特定のtileset.jsonのURLを取得
  ///
  /// [localTilesetPath] tileset.jsonのローカルパス
  ///
  /// Returns: HTTP経由でアクセス可能なURL
  String getTilesetUrl(String localTilesetPath) {
    // tileset.jsonの親ディレクトリをマウント
    final file = File(localTilesetPath);
    final directory = file.parent.path;
    final fileName = file.uri.pathSegments.last;

    // ユニークなマウントパスを生成（ディレクトリ名のハッシュを使用）
    final mountPath = '/tileset_${directory.hashCode.abs()}';

    // まだマウントされていなければマウント
    if (!_mountedPaths.containsKey(mountPath)) {
      mountDirectory(mountPath, directory);
    }

    return '$baseUrl$mountPath/$fileName';
  }

  /// リクエストを処理
  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final path = '/${request.url.path}';

    // マウントされたパスを探す
    for (final entry in _mountedPaths.entries) {
      final mountPath = entry.key;
      final localPath = entry.value;

      if (path.startsWith(mountPath)) {
        // マウントパス以降の部分を取得
        final relativePath = path.substring(mountPath.length);
        final filePath = '$localPath$relativePath';

        logDebug('Serving file: $filePath');

        final file = File(filePath);
        if (await file.exists()) {
          // MIMEタイプを判定
          final mimeType = _getMimeType(filePath);

          // ファイルを読み込んで返す
          final bytes = await file.readAsBytes();
          return shelf.Response.ok(
            bytes,
            headers: {
              'Content-Type': mimeType,
              'Content-Length': bytes.length.toString(),
            },
          );
        } else {
          logWarning('File not found: $filePath');
          return shelf.Response.notFound('File not found: $relativePath');
        }
      }
    }

    return shelf.Response.notFound('Not found: $path');
  }

  /// MIMEタイプを判定
  String _getMimeType(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    switch (ext) {
      case 'json':
        return 'application/json';
      case 'b3dm':
        return 'application/octet-stream';
      case 'pnts':
        return 'application/octet-stream';
      case 'i3dm':
        return 'application/octet-stream';
      case 'cmpt':
        return 'application/octet-stream';
      case 'glb':
        return 'model/gltf-binary';
      case 'gltf':
        return 'model/gltf+json';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'bin':
        return 'application/octet-stream';
      default:
        return 'application/octet-stream';
    }
  }

  /// CORSヘッダー
  Map<String, String> get _corsHeaders => {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': '*',
      };
}
