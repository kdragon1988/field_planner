import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/utils/logger.dart';
import '../../infrastructure/webview/cesium_controller.dart';
import '../../data/models/geo_position.dart';

/// CesiumJSを表示するWebViewウィジェット
///
/// CesiumJSをWebView内に表示し、Flutterとの双方向通信を提供する
class CesiumMapWidget extends StatefulWidget {
  /// CesiumController生成時のコールバック
  final Function(CesiumController)? onControllerCreated;

  /// 初期表示位置
  final GeoPosition? initialPosition;

  /// Cesium Ionアクセストークン
  final String? ionToken;

  /// Google Maps APIキー
  final String? googleMapsApiKey;

  const CesiumMapWidget({
    super.key,
    this.onControllerCreated,
    this.initialPosition,
    this.ionToken,
    this.googleMapsApiKey,
  });

  @override
  State<CesiumMapWidget> createState() => _CesiumMapWidgetState();
}

class _CesiumMapWidgetState extends State<CesiumMapWidget> with LoggableMixin {
  late WebViewController _webViewController;
  CesiumController? _cesiumController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  /// WebViewを初期化
  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    // macOSではsetBackgroundColorのopaque機能が未実装のため、
    // エラーをキャッチして無視する
    try {
      _webViewController.setBackgroundColor(const Color(0xFF1a1a2e));
    } catch (e) {
      logDebug('setBackgroundColor not supported on this platform: $e');
    }

    // JavaScriptチャネルをページロード前に設定
    // これによりページ読み込み完了時点でFlutterChannelが利用可能になる
    _webViewController.addJavaScriptChannel(
      'FlutterChannel',
      onMessageReceived: _handleJavaScriptMessage,
    );

    _webViewController.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          logDebug('WebView page started: $url');
        },
        onPageFinished: (url) {
          logDebug('WebView page finished: $url');
          _onPageLoaded();
        },
        onWebResourceError: (error) {
          logError('WebView error: ${error.description}');
          setState(() {
            _errorMessage = error.description;
            _isLoading = false;
          });
        },
        onNavigationRequest: (request) {
          // 外部リンクはブロック
          if (!request.url.startsWith('file://') &&
              !request.url.contains('cesium')) {
            logDebug('Blocked navigation to: ${request.url}');
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );

    _webViewController.loadFlutterAsset('assets/cesium/index.html');
  }

  /// JavaScriptからのメッセージを処理
  void _handleJavaScriptMessage(JavaScriptMessage message) {
    // CesiumControllerが作成される前のメッセージもログに出力
    logDebug('Received JS message: ${message.message}');
    _cesiumController?.handleMessage(message);
  }

  /// ページ読み込み完了時の処理
  void _onPageLoaded() {
    // JavaScriptチャネルは既に設定済みなので、コントローラは
    // チャネルを追加せずに作成する
    _cesiumController = CesiumController.withExistingChannel(_webViewController);

    _cesiumController!.onInitialized = (success) {
      if (success) {
        setState(() => _isLoading = false);
        widget.onControllerCreated?.call(_cesiumController!);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'CesiumJSの初期化に失敗しました';
        });
      }
    };

    _cesiumController!.onError = (error) {
      logError('CesiumJS error: $error');
    };

    // 少し遅延を入れてからCesiumJSを初期化
    // JavaScriptの環境が完全に準備されるのを待つ
    Future.delayed(const Duration(milliseconds: 100), () {
      _cesiumController!.initialize(
        ionToken: widget.ionToken,
        googleMapsApiKey: widget.googleMapsApiKey,
        center: widget.initialPosition ?? GeoPosition.tokyo,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // WebView
        WebViewWidget(controller: _webViewController),

        // ローディングインジケーター
        if (_isLoading)
          Container(
            color: const Color(0xFF1a1a2e),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '3Dマップを読み込み中...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

        // エラー表示
        if (_errorMessage != null)
          Container(
            color: const Color(0xFF1a1a2e),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'エラーが発生しました',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 再試行
  void _retry() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _webViewController.reload();
  }

  @override
  void dispose() {
    _cesiumController?.dispose();
    super.dispose();
  }
}
