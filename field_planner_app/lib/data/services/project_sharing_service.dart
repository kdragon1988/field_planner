import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../core/exceptions/app_exceptions.dart';
import '../../core/utils/logger.dart';

/// プロジェクト共有サービス
///
/// プロジェクトのZIPエクスポート/インポートを行う
class ProjectSharingService with LoggableMixin {
  /// プロジェクトをZIPにエクスポート
  ///
  /// [projectPath] プロジェクトフォルダのパス
  /// [outputPath] 出力先ZIPファイルのパス
  /// [includeImports] インポートファイルを含めるか
  Future<String> exportToZip(
    String projectPath,
    String outputPath, {
    bool includeImports = false,
  }) async {
    logInfo('Exporting project to ZIP: $outputPath');

    final archive = Archive();
    final projectDir = Directory(projectPath);
    final projectName = p.basename(projectPath);

    await for (final entity in projectDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: projectPath);

        // 除外するファイル/フォルダ
        if (relativePath.startsWith('backups/') ||
            relativePath == '.recovery' ||
            relativePath.endsWith('.DS_Store')) {
          continue;
        }

        // importsフォルダの処理
        if (relativePath.startsWith('imports/') && !includeImports) {
          continue;
        }

        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(
          '$projectName/$relativePath',
          bytes.length,
          bytes,
        ));
      }
    }

    // ZIPファイルを書き出し
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    if (zipData == null) {
      throw const ExportException('ZIPエンコードに失敗しました');
    }

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(zipData);

    logInfo('Export completed: $outputPath');
    return outputPath;
  }

  /// ZIPからプロジェクトをインポート
  ///
  /// [zipPath] ZIPファイルのパス
  /// [destinationDir] 展開先ディレクトリ
  ///
  /// Returns: インポートされたプロジェクトのパス
  Future<String> importFromZip(
    String zipPath,
    String destinationDir,
  ) async {
    logInfo('Importing project from ZIP: $zipPath');

    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw ImportException('ZIPファイルが見つかりません: $zipPath');
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // プロジェクト名を取得
    String? projectName;
    for (final file in archive) {
      final parts = file.name.split('/');
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        projectName = parts[0];
        break;
      }
    }

    if (projectName == null) {
      throw const ImportException('ZIPファイルの形式が不正です');
    }

    // 展開先を決定
    var extractPath = p.join(destinationDir, projectName);

    // 既存プロジェクトがある場合はリネーム
    var counter = 1;
    while (await Directory(extractPath).exists()) {
      extractPath = p.join(destinationDir, '${projectName}_$counter');
      counter++;
    }

    // ファイルを展開
    for (final file in archive) {
      if (file.isFile) {
        // プロジェクト名部分を除去して展開
        final relativePath = file.name.substring(projectName.length + 1);
        if (relativePath.isEmpty) continue;

        final outputPath = p.join(extractPath, relativePath);
        final outputFile = File(outputPath);
        await outputFile.create(recursive: true);
        await outputFile.writeAsBytes(file.content as List<int>);
      }
    }

    // project.jsonの存在確認
    final projectJson = File(p.join(extractPath, 'project.json'));
    if (!await projectJson.exists()) {
      // クリーンアップして例外をスロー
      await Directory(extractPath).delete(recursive: true);
      throw const ImportException('有効なプロジェクトファイルが見つかりません');
    }

    logInfo('Import completed: $extractPath');
    return extractPath;
  }

  /// ZIPファイルを検証
  Future<ProjectArchiveInfo?> validateZip(String zipPath) async {
    try {
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) return null;

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      String? projectName;
      bool hasProjectJson = false;
      int fileCount = 0;
      int totalSize = 0;

      for (final file in archive) {
        fileCount++;
        totalSize += file.size;

        final parts = file.name.split('/');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          projectName ??= parts[0];

          if (parts.length > 1 && parts[1] == 'project.json') {
            hasProjectJson = true;
          }
        }
      }

      if (projectName == null || !hasProjectJson) return null;

      return ProjectArchiveInfo(
        projectName: projectName,
        fileCount: fileCount,
        totalSize: totalSize,
      );
    } catch (e) {
      logError('Failed to validate ZIP', e);
      return null;
    }
  }
}

/// プロジェクトアーカイブ情報
class ProjectArchiveInfo {
  final String projectName;
  final int fileCount;
  final int totalSize;

  ProjectArchiveInfo({
    required this.projectName,
    required this.fileCount,
    required this.totalSize,
  });

  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
