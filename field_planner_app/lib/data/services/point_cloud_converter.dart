import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../core/utils/logger.dart';

/// 点群変換オプション
/// 
/// 3D Tiles変換時のオプション設定
class PointCloudConversionOptions {
  /// ダウンサンプリング率（0.0-1.0、1.0で全点を使用）
  final double downsampleRatio;

  /// ソースCRS（EPSGコード）
  final int? sourceCrs;

  /// 並列処理数
  final int jobs;

  /// 出力ディレクトリ名（nullの場合は自動生成）
  final String? outputName;

  const PointCloudConversionOptions({
    this.downsampleRatio = 1.0,
    this.sourceCrs,
    this.jobs = 1, // PyInstallerビルドではmultiprocessingが動作しないため1を使用
    this.outputName,
  });
}

/// 変換結果
/// 
/// 3D Tiles変換の結果情報
class ConversionResult {
  /// 成功フラグ
  final bool success;

  /// 出力ディレクトリパス
  final String? outputPath;

  /// tileset.jsonのパス
  final String? tilesetJsonPath;

  /// エラーメッセージ
  final String? errorMessage;

  /// 処理時間（ミリ秒）
  final int? durationMs;

  const ConversionResult({
    required this.success,
    this.outputPath,
    this.tilesetJsonPath,
    this.errorMessage,
    this.durationMs,
  });

  factory ConversionResult.success({
    required String outputPath,
    required String tilesetJsonPath,
    int? durationMs,
  }) =>
      ConversionResult(
        success: true,
        outputPath: outputPath,
        tilesetJsonPath: tilesetJsonPath,
        durationMs: durationMs,
      );

  factory ConversionResult.failure(String errorMessage) => ConversionResult(
        success: false,
        errorMessage: errorMessage,
      );
}

/// 変換進捗イベント
/// 
/// 変換処理の進捗情報
class ConversionProgress {
  /// 進捗率（0.0-1.0）
  final double progress;

  /// 現在のステータスメッセージ
  final String message;

  /// 処理中のファイル名
  final String? currentFile;

  const ConversionProgress({
    required this.progress,
    required this.message,
    this.currentFile,
  });
}

/// 点群変換サービス
/// 
/// LAS/LAZ/PLY/E57ファイルを3D Tiles形式に変換する
/// py3dtiles_converterバイナリを使用
class PointCloudConverter with LoggableMixin {
  /// 変換進捗ストリーム
  final _progressController = StreamController<ConversionProgress>.broadcast();

  /// 現在実行中のプロセス
  Process? _currentProcess;

  /// 変換がキャンセルされたか
  bool _isCancelled = false;

  /// 進捗ストリームを取得
  Stream<ConversionProgress> get progressStream => _progressController.stream;

  /// py3dtiles_converterのパスを取得
  /// 
  /// システムのPythonにインストールされたpy3dtilesを優先使用
  Future<String?> _getConverterPath() async {
    // まずシステムのPythonでpy3dtilesが利用可能か確認（最も安定）
    try {
      final pythonResult = await Process.run(
        'python3', 
        ['-c', 'import py3dtiles; print("OK")'],
      );
      if (pythonResult.exitCode == 0 && 
          (pythonResult.stdout as String).contains('OK')) {
        logInfo('Using py3dtiles via system python3');
        return 'python3';
      }
    } catch (e) {
      logWarning('Failed to check python3 py3dtiles: $e');
    }

    // システムパスからpy3dtiles_converterバイナリを探す
    try {
      final whichResult = await Process.run('which', ['py3dtiles_converter']);
      if (whichResult.exitCode == 0) {
        final systemPath = (whichResult.stdout as String).trim();
        if (systemPath.isNotEmpty) {
          logInfo('Found converter in system path: $systemPath');
          return systemPath;
        }
      }
    } catch (e) {
      logWarning('Failed to run which command: $e');
    }

    // PyInstallerでビルドしたバイナリは安定性の問題があるため、最後の手段として使用
    final candidatePaths = <String>[];

    // macOSアプリバンドル内のパスを確認
    final bundlePath = Platform.resolvedExecutable;
    final appDir = path.dirname(path.dirname(bundlePath));
    candidatePaths.add(path.join(appDir, 'Resources', 'tools', 'py3dtiles_converter'));

    // 開発環境用のパス（flutter run時）
    var currentDir = Directory(bundlePath);
    for (var i = 0; i < 10; i++) {
      currentDir = currentDir.parent;
      final macosRunnerResources = path.join(
        currentDir.path, 'macos', 'Runner', 'Resources', 'tools', 'py3dtiles_converter'
      );
      if (await File(macosRunnerResources).exists()) {
        candidatePaths.add(macosRunnerResources);
        break;
      }
    }

    // 候補パスを順番に確認
    for (final candidatePath in candidatePaths) {
      logInfo('Checking converter path: $candidatePath');
      if (await File(candidatePath).exists()) {
        logInfo('Found bundled converter at: $candidatePath (fallback)');
        return candidatePath;
      }
    }

    logError('py3dtiles not found. Please install: pip3 install "py3dtiles[las]"');
    return null;
  }

  /// 点群ファイルを3D Tilesに変換
  /// 
  /// [inputPath] 入力ファイルパス（LAS/LAZ/PLY/E57）
  /// [outputDir] 出力ディレクトリ
  /// [options] 変換オプション
  Future<ConversionResult> convert({
    required String inputPath,
    required String outputDir,
    PointCloudConversionOptions options = const PointCloudConversionOptions(),
  }) async {
    _isCancelled = false;
    final stopwatch = Stopwatch()..start();

    try {
      // 入力ファイルの存在確認
      if (!await File(inputPath).exists()) {
        return ConversionResult.failure('入力ファイルが見つかりません: $inputPath');
      }

      _emitProgress(0.0, 'コンバーターを確認中...');

      // コンバーターのパスを取得
      final converterPath = await _getConverterPath();
      if (converterPath == null) {
        return ConversionResult.failure(
          'py3dtiles_converterが見つかりません。\n'
          'scripts/build_py3dtiles.shを実行してバイナリをビルドしてください。',
        );
      }

      logInfo('Using converter: $converterPath');

      // 出力ディレクトリを作成
      final outputName =
          options.outputName ?? path.basenameWithoutExtension(inputPath);
      final tilesetDir = path.join(outputDir, outputName);
      await Directory(tilesetDir).create(recursive: true);

      _emitProgress(0.1, '変換を開始中...', path.basename(inputPath));

      // コマンドを構築
      List<String> args;
      if (converterPath == 'python3') {
        // Python経由での実行（安定性のためuse_process_pool=Falseを使用）
        // パスをエスケープ（バックスラッシュとクォートを処理）
        final escapedInput = inputPath.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
        final escapedOutput = tilesetDir.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
        // CRS設定：CesiumはECEF座標（EPSG:4978）を期待
        // 入力CRS指定がある場合は強制適用、常に出力をECEFに変換
        final crsInArg = options.sourceCrs != null 
            ? "crs_in=pyproj.CRS.from_epsg(${options.sourceCrs}), force_crs_in=True, " 
            : "";
        final pythonCode = """
import pyproj
from py3dtiles.convert import convert
print("Converting: $escapedInput")
print("Output: $escapedOutput")
print("CRS: ${options.sourceCrs ?? 'auto'} -> ECEF (4978)")
convert(
    '$escapedInput',
    outfolder='$escapedOutput',
    ${crsInArg}crs_out=pyproj.CRS.from_epsg(4978),
    jobs=${options.jobs},
    use_process_pool=False,
    overwrite=True,
    verbose=1
)
print("Conversion completed successfully.")
""";
        args = ['-c', pythonCode];
      } else {
        // バイナリ実行
        args = [inputPath, tilesetDir];
        if (options.sourceCrs != null) {
          args.addAll(['--srs', options.sourceCrs.toString()]);
        }
        args.addAll(['--jobs', options.jobs.toString()]);
      }

      logInfo('Running: $converterPath ${args.length > 1 && args[0] == "-c" ? "(Python script)" : args.join(' ')}');

      // プロセスを実行
      _currentProcess = await Process.start(
        converterPath,
        args,
        runInShell: false,
      );

      // 標準出力を監視
      _currentProcess!.stdout.transform(const SystemEncoding().decoder).listen(
        (data) {
          logInfo('[py3dtiles] $data');
          _parseProgressFromOutput(data);
        },
      );

      // 標準エラー出力を監視
      _currentProcess!.stderr.transform(const SystemEncoding().decoder).listen(
        (data) {
          logWarning('[py3dtiles stderr] $data');
        },
      );

      // プロセスの終了を待つ
      final exitCode = await _currentProcess!.exitCode;
      _currentProcess = null;

      if (_isCancelled) {
        return ConversionResult.failure('変換がキャンセルされました');
      }

      if (exitCode != 0) {
        return ConversionResult.failure('変換に失敗しました (exit code: $exitCode)');
      }

      // tileset.jsonの存在確認
      final tilesetJsonPath = path.join(tilesetDir, 'tileset.json');
      if (!await File(tilesetJsonPath).exists()) {
        return ConversionResult.failure(
            'tileset.jsonが生成されませんでした: $tilesetJsonPath');
      }

      stopwatch.stop();
      _emitProgress(1.0, '変換完了');

      return ConversionResult.success(
        outputPath: tilesetDir,
        tilesetJsonPath: tilesetJsonPath,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      logError('Conversion failed: $e');
      return ConversionResult.failure('変換中にエラーが発生しました: $e');
    }
  }

  /// 変換をキャンセル
  void cancel() {
    _isCancelled = true;
    _currentProcess?.kill();
    logInfo('Conversion cancelled');
  }

  /// 進捗を発行
  void _emitProgress(double progress, String message, [String? currentFile]) {
    _progressController.add(ConversionProgress(
      progress: progress,
      message: message,
      currentFile: currentFile,
    ));
  }

  /// 出力から進捗を解析
  void _parseProgressFromOutput(String output) {
    // py3dtilesの出力から進捗を推定
    // 例: "Processing tile 50/100"
    final match = RegExp(r'(\d+)/(\d+)').firstMatch(output);
    if (match != null) {
      final current = int.tryParse(match.group(1) ?? '0') ?? 0;
      final total = int.tryParse(match.group(2) ?? '1') ?? 1;
      final progress = 0.1 + (current / total) * 0.8; // 10%-90%の範囲
      _emitProgress(progress, '変換中...', '$current / $total');
    } else if (output.contains('Writing tileset')) {
      _emitProgress(0.9, 'tileset.jsonを書き込み中...');
    } else if (output.contains('Done') || output.contains('completed')) {
      _emitProgress(0.95, '完了処理中...');
    }
  }

  /// リソースを解放
  void dispose() {
    cancel();
    _progressController.close();
  }
}
