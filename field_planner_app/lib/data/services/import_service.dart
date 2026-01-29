import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/exceptions/app_exceptions.dart';
import '../../core/utils/logger.dart';
import '../models/import_job.dart';

/// インポートサービス
///
/// 3Dデータ・点群ファイルのインポートを管理
class ImportService with LoggableMixin {
  final _jobController = StreamController<ImportJob>.broadcast();

  /// ジョブ更新ストリーム
  Stream<ImportJob> get jobUpdates => _jobController.stream;

  /// 現在のジョブ一覧
  final List<ImportJob> _jobs = [];
  List<ImportJob> get jobs => List.unmodifiable(_jobs);

  /// ファイルをインポート
  ///
  /// [filePath] インポートするファイルのパス
  /// [projectPath] プロジェクトフォルダのパス
  /// [options] インポートオプション
  ///
  /// Returns: インポートジョブ
  Future<ImportJob> importFile(
    String filePath,
    String projectPath,
    ImportOptions options,
  ) async {
    // フォーマットを判定
    final extension = p.extension(filePath);
    final format = ImportFormat.fromExtension(extension);

    if (format == null) {
      throw UnsupportedFormatException(extension);
    }

    // ジョブを作成
    var job = ImportJob(
      id: const Uuid().v4(),
      sourcePath: filePath,
      format: format,
      status: ImportStatus.analyzing,
      createdAt: DateTime.now(),
    );

    _jobs.add(job);
    _jobController.add(job);

    try {
      // ファイル解析
      logInfo('Analyzing file: $filePath');
      final geoRef = await _analyzeFile(filePath, format);
      job = job.copyWith(
        geoReference: geoRef,
        progress: 0.2,
      );
      _updateJob(job);

      // プロジェクトにコピー
      if (options.copyToProject) {
        job = job.copyWith(status: ImportStatus.copying, progress: 0.4);
        _updateJob(job);

        final destPath = await _copyToProject(filePath, projectPath);
        job = job.copyWith(
          outputPath: destPath,
          progress: 0.6,
        );
        _updateJob(job);
      } else {
        job = job.copyWith(outputPath: filePath, progress: 0.6);
        _updateJob(job);
      }

      // 完了
      job = job.copyWith(
        status: ImportStatus.completed,
        progress: 1.0,
        completedAt: DateTime.now(),
      );
      _updateJob(job);

      logInfo('Import completed: ${job.fileName}');
      return job;
    } catch (e) {
      logError('Import failed: $filePath', e);
      job = job.copyWith(
        status: ImportStatus.failed,
        errorMessage: e.toString(),
      );
      _updateJob(job);
      throw ImportException('インポートに失敗しました: $e', cause: e);
    }
  }

  /// ファイルを解析
  Future<GeoReference?> _analyzeFile(String filePath, ImportFormat format) async {
    // 簡易的な解析（実際にはフォーマットごとに詳細な解析が必要）
    final file = File(filePath);
    if (!await file.exists()) {
      throw ImportException('ファイルが見つかりません: $filePath');
    }

    // LASファイルの場合、ヘッダーを解析
    if (format == ImportFormat.las || format == ImportFormat.laz) {
      return await _analyzeLasFile(filePath);
    }

    return null;
  }

  /// LASファイルのヘッダーを解析
  Future<GeoReference?> _analyzeLasFile(String filePath) async {
    try {
      final file = File(filePath);
      final raf = await file.open();

      // LASファイルシグネチャをチェック（"LASF"）
      final signature = await raf.read(4);
      if (String.fromCharCodes(signature) != 'LASF') {
        await raf.close();
        return null;
      }

      // ヘッダーの一部を読み込み（簡易版）
      // 実際のLAS 1.4仕様に基づいた解析が必要
      await raf.setPosition(131); // バウンディングボックスの位置
      final buffer = await raf.read(48); // 6つのdouble値

      if (buffer.length == 48) {
        final values = List.generate(6, (i) {
          final bytes = buffer.sublist(i * 8, (i + 1) * 8);
          return bytes.buffer.asByteData().getFloat64(0, Endian.little);
        });

        await raf.close();
        return GeoReference(
          maxX: values[0],
          minX: values[1],
          maxY: values[2],
          minY: values[3],
          maxZ: values[4],
          minZ: values[5],
        );
      }

      await raf.close();
      return null;
    } catch (e) {
      logWarning('Failed to analyze LAS file: $e');
      return null;
    }
  }

  /// プロジェクトフォルダにコピー
  Future<String> _copyToProject(String sourcePath, String projectPath) async {
    final importsDir = Directory(p.join(projectPath, 'imports'));
    if (!await importsDir.exists()) {
      await importsDir.create(recursive: true);
    }

    final fileName = p.basename(sourcePath);
    final destPath = p.join(importsDir.path, fileName);

    // 同名ファイルが存在する場合はリネーム
    var finalPath = destPath;
    var counter = 1;
    while (await File(finalPath).exists()) {
      final ext = p.extension(fileName);
      final name = p.basenameWithoutExtension(fileName);
      finalPath = p.join(importsDir.path, '${name}_$counter$ext');
      counter++;
    }

    await File(sourcePath).copy(finalPath);

    // 関連ファイルもコピー（OBJの場合はMTLなど）
    await _copyRelatedFiles(sourcePath, p.dirname(finalPath));

    return finalPath;
  }

  /// 関連ファイルをコピー
  Future<void> _copyRelatedFiles(String sourcePath, String destDir) async {
    final ext = p.extension(sourcePath).toLowerCase();
    final baseName = p.basenameWithoutExtension(sourcePath);
    final sourceDir = p.dirname(sourcePath);

    if (ext == '.obj') {
      // MTLファイルをコピー
      final mtlPath = p.join(sourceDir, '$baseName.mtl');
      if (await File(mtlPath).exists()) {
        await File(mtlPath).copy(p.join(destDir, '$baseName.mtl'));
      }
    }
  }

  /// ジョブを更新
  void _updateJob(ImportJob job) {
    final index = _jobs.indexWhere((j) => j.id == job.id);
    if (index >= 0) {
      _jobs[index] = job;
    }
    _jobController.add(job);
  }

  /// ジョブをキャンセル
  void cancelJob(String jobId) {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index >= 0) {
      final job = _jobs[index].copyWith(status: ImportStatus.cancelled);
      _jobs[index] = job;
      _jobController.add(job);
    }
  }

  /// 完了したジョブをクリア
  void clearCompletedJobs() {
    _jobs.removeWhere(
        (j) => j.status == ImportStatus.completed || j.status == ImportStatus.cancelled);
  }

  void dispose() {
    _jobController.close();
  }
}
