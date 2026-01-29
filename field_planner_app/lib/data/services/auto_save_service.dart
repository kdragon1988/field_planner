import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';

/// 自動保存サービス
///
/// 定期的にプロジェクトをバックアップし、クラッシュ時の復旧をサポート
class AutoSaveService with LoggableMixin {
  Timer? _timer;
  String? _projectPath;
  bool _isDirty = false;

  /// 自動保存の間隔
  final Duration interval;

  /// バックアップの最大世代数
  final int maxBackupGenerations;

  AutoSaveService({
    Duration? interval,
    this.maxBackupGenerations = AppConstants.maxBackupGenerations,
  }) : interval = interval ??
            Duration(seconds: AppConstants.autoSaveIntervalSeconds);

  /// 自動保存を開始
  void start(String projectPath) {
    _projectPath = projectPath;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _performAutoSave());
    logInfo('Auto-save started for: $projectPath');
  }

  /// 自動保存を停止
  void stop() {
    _timer?.cancel();
    _timer = null;
    _projectPath = null;
    logInfo('Auto-save stopped');
  }

  /// 変更フラグを設定
  void markDirty() {
    _isDirty = true;
  }

  /// 変更フラグをクリア
  void markClean() {
    _isDirty = false;
  }

  /// 自動保存を実行
  Future<void> _performAutoSave() async {
    if (_projectPath == null || !_isDirty) return;

    try {
      await _createBackup();
      _isDirty = false;
      logInfo('Auto-save completed');
    } catch (e) {
      logError('Auto-save failed', e);
    }
  }

  /// バックアップを作成
  Future<void> _createBackup() async {
    if (_projectPath == null) return;

    final backupsDir = Directory(p.join(_projectPath!, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupDir = Directory(p.join(backupsDir.path, timestamp));
    await backupDir.create();

    // 主要なファイルをバックアップ
    final filesToBackup = ['project.json', 'placements.json', 'measurements.json'];
    for (final fileName in filesToBackup) {
      final sourceFile = File(p.join(_projectPath!, fileName));
      if (await sourceFile.exists()) {
        await sourceFile.copy(p.join(backupDir.path, fileName));
      }
    }

    // 古いバックアップを削除
    await _cleanupOldBackups(backupsDir);
  }

  /// 古いバックアップを削除
  Future<void> _cleanupOldBackups(Directory backupsDir) async {
    final backups = await backupsDir.list().toList();
    if (backups.length <= maxBackupGenerations) return;

    // 作成日時でソート
    final sortedBackups = backups.whereType<Directory>().toList()
      ..sort((a, b) {
        final aName = p.basename(a.path);
        final bName = p.basename(b.path);
        return bName.compareTo(aName); // 新しい順
      });

    // 古いものを削除
    for (var i = maxBackupGenerations; i < sortedBackups.length; i++) {
      await sortedBackups[i].delete(recursive: true);
      logDebug('Deleted old backup: ${sortedBackups[i].path}');
    }
  }

  /// 最新のバックアップから復旧
  Future<bool> recoverFromBackup(String projectPath) async {
    final backupsDir = Directory(p.join(projectPath, 'backups'));
    if (!await backupsDir.exists()) {
      return false;
    }

    final backups = await backupsDir.list().whereType<Directory>().toList();
    if (backups.isEmpty) {
      return false;
    }

    // 最新のバックアップを取得
    backups.sort((a, b) {
      final aName = p.basename(a.path);
      final bName = p.basename(b.path);
      return bName.compareTo(aName);
    });

    final latestBackup = backups.first;

    // ファイルを復元
    await for (final entity in latestBackup.list()) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        await entity.copy(p.join(projectPath, fileName));
      }
    }

    logInfo('Recovered from backup: ${latestBackup.path}');
    return true;
  }

  void dispose() {
    stop();
  }
}

/// クラッシュ復旧サービス
class RecoveryService with LoggableMixin {
  static const String _recoveryFileName = '.recovery';

  /// 起動時に復旧チェックを行う
  Future<bool> checkForRecovery(String projectPath) async {
    final recoveryFile = File(p.join(projectPath, _recoveryFileName));
    return recoveryFile.exists();
  }

  /// 復旧マーカーを作成
  Future<void> createRecoveryMarker(String projectPath) async {
    final recoveryFile = File(p.join(projectPath, _recoveryFileName));
    await recoveryFile.writeAsString(DateTime.now().toIso8601String());
  }

  /// 復旧マーカーを削除（正常終了時）
  Future<void> removeRecoveryMarker(String projectPath) async {
    final recoveryFile = File(p.join(projectPath, _recoveryFileName));
    if (await recoveryFile.exists()) {
      await recoveryFile.delete();
    }
  }
}
