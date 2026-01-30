import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import '../../core/utils/logger.dart';
import '../models/geo_position.dart';

/// ジオリファレンス情報
/// 
/// ファイルから抽出された位置・座標系情報
class GeoReference {
  /// 座標系（EPSG）
  final int? epsg;

  /// 原点座標
  final GeoPosition? origin;

  /// バウンディングボックス
  final BoundingBox? boundingBox;

  /// 検出方法
  final String detectionMethod;

  const GeoReference({
    this.epsg,
    this.origin,
    this.boundingBox,
    this.detectionMethod = 'auto',
  });

  Map<String, dynamic> toJson() => {
        if (epsg != null) 'epsg': epsg,
        if (origin != null) 'origin': origin!.toJson(),
        if (boundingBox != null) 'boundingBox': boundingBox!.toJson(),
        'detectionMethod': detectionMethod,
      };
}

/// バウンディングボックス
/// 
/// 3D空間内の範囲を表す
class BoundingBox {
  final double minX;
  final double minY;
  final double minZ;
  final double maxX;
  final double maxY;
  final double maxZ;

  const BoundingBox({
    required this.minX,
    required this.minY,
    required this.minZ,
    required this.maxX,
    required this.maxY,
    required this.maxZ,
  });

  /// 幅（X方向）
  double get width => maxX - minX;

  /// 高さ（Y方向）
  double get height => maxY - minY;

  /// 深さ（Z方向）
  double get depth => maxZ - minZ;

  /// 中心座標
  GeoPosition get center => GeoPosition(
        longitude: (minX + maxX) / 2,
        latitude: (minY + maxY) / 2,
        height: (minZ + maxZ) / 2,
      );

  Map<String, dynamic> toJson() => {
        'minX': minX,
        'minY': minY,
        'minZ': minZ,
        'maxX': maxX,
        'maxY': maxY,
        'maxZ': maxZ,
      };

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
        minX: (json['minX'] as num).toDouble(),
        minY: (json['minY'] as num).toDouble(),
        minZ: (json['minZ'] as num).toDouble(),
        maxX: (json['maxX'] as num).toDouble(),
        maxY: (json['maxY'] as num).toDouble(),
        maxZ: (json['maxZ'] as num).toDouble(),
      );
}

/// 点群ファイル情報
/// 
/// 点群ファイルから解析された情報
class PointCloudFileInfo {
  /// ファイルパス
  final String filePath;

  /// ファイル名
  final String fileName;

  /// ファイルサイズ（バイト）
  final int fileSize;

  /// フォーマットバージョン
  final String? formatVersion;

  /// 点数
  final int? pointCount;

  /// ジオリファレンス情報
  final GeoReference? geoReference;

  /// 点データフォーマット（LASの場合）
  final int? pointDataFormat;

  /// 色情報を持つか
  final bool hasColor;

  /// 強度情報を持つか
  final bool hasIntensity;

  /// 分類情報を持つか
  final bool hasClassification;

  const PointCloudFileInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.formatVersion,
    this.pointCount,
    this.geoReference,
    this.pointDataFormat,
    this.hasColor = false,
    this.hasIntensity = false,
    this.hasClassification = false,
  });

  /// ファイルサイズの表示用文字列
  String get fileSizeDisplay {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 点数の表示用文字列
  String get pointCountDisplay {
    if (pointCount == null) return '不明';
    if (pointCount! < 1000) {
      return pointCount.toString();
    } else if (pointCount! < 1000000) {
      return '${(pointCount! / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(pointCount! / 1000000).toStringAsFixed(2)}M';
    }
  }
}

/// ファイル解析サービス
/// 
/// インポートファイルのヘッダ情報を解析し、
/// ジオリファレンス情報等を抽出する
class FileAnalyzerService with LoggableMixin {
  /// ファイルを解析してジオリファレンス情報を取得
  Future<GeoReference?> analyzeFile(String filePath) async {
    final ext = path.extension(filePath).toLowerCase();

    switch (ext) {
      case '.las':
      case '.laz':
        return await _analyzeLas(filePath);
      case '.ply':
        return await _analyzePly(filePath);
      case '.e57':
        return await _analyzeE57(filePath);
      case '.obj':
        return await _analyzeObj(filePath);
      case '.gltf':
      case '.glb':
        return await _analyzeGltf(filePath);
      default:
        return null;
    }
  }

  /// 点群ファイルの詳細情報を取得
  Future<PointCloudFileInfo?> analyzePointCloudFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      logWarning('File not found: $filePath');
      return null;
    }

    final ext = path.extension(filePath).toLowerCase();
    final fileSize = await file.length();
    final fileName = path.basename(filePath);

    switch (ext) {
      case '.las':
      case '.laz':
        return await _analyzeLasDetailed(filePath, fileName, fileSize);
      case '.ply':
        return await _analyzePlyDetailed(filePath, fileName, fileSize);
      case '.e57':
        return await _analyzeE57Detailed(filePath, fileName, fileSize);
      default:
        return PointCloudFileInfo(
          filePath: filePath,
          fileName: fileName,
          fileSize: fileSize,
        );
    }
  }

  /// LAS/LAZファイルの解析
  Future<GeoReference?> _analyzeLas(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.openRead(0, 375).fold<List<int>>(
        [],
        (prev, chunk) => prev..addAll(chunk),
      );

      if (bytes.length < 375) return null;

      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));

      // File Signature確認
      final signature = String.fromCharCodes(bytes.sublist(0, 4));
      if (signature != 'LASF') return null;

      // Offsets
      final offsetX = byteData.getFloat64(131, Endian.little);
      final offsetY = byteData.getFloat64(139, Endian.little);
      final offsetZ = byteData.getFloat64(147, Endian.little);

      // Bounding Box
      final maxX = byteData.getFloat64(179, Endian.little);
      final minX = byteData.getFloat64(187, Endian.little);
      final maxY = byteData.getFloat64(195, Endian.little);
      final minY = byteData.getFloat64(203, Endian.little);
      final maxZ = byteData.getFloat64(211, Endian.little);
      final minZ = byteData.getFloat64(219, Endian.little);

      return GeoReference(
        origin: GeoPosition(
          longitude: offsetX,
          latitude: offsetY,
          height: offsetZ,
        ),
        boundingBox: BoundingBox(
          minX: minX,
          minY: minY,
          minZ: minZ,
          maxX: maxX,
          maxY: maxY,
          maxZ: maxZ,
        ),
        detectionMethod: 'las_header',
      );
    } catch (e) {
      logError('Failed to analyze LAS file: $e');
      return null;
    }
  }

  /// LAS/LAZファイルの詳細解析
  Future<PointCloudFileInfo> _analyzeLasDetailed(
    String filePath,
    String fileName,
    int fileSize,
  ) async {
    try {
      final file = File(filePath);
      final bytes = await file.openRead(0, 375).fold<List<int>>(
        [],
        (prev, chunk) => prev..addAll(chunk),
      );

      if (bytes.length < 375) {
        return PointCloudFileInfo(
          filePath: filePath,
          fileName: fileName,
          fileSize: fileSize,
        );
      }

      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));

      // File Signature確認
      final signature = String.fromCharCodes(bytes.sublist(0, 4));
      if (signature != 'LASF') {
        return PointCloudFileInfo(
          filePath: filePath,
          fileName: fileName,
          fileSize: fileSize,
        );
      }

      // Version
      final versionMajor = bytes[24];
      final versionMinor = bytes[25];
      final formatVersion = '$versionMajor.$versionMinor';

      // Point Data Format
      final pointDataFormat = bytes[104];

      // Point Count（LAS 1.4ではoffset 247、1.0-1.3ではoffset 107）
      int pointCount;
      if (versionMajor == 1 && versionMinor >= 4) {
        // LAS 1.4: 64-bit point count at offset 247
        if (bytes.length >= 255) {
          pointCount = byteData.getUint64(247, Endian.little);
        } else {
          pointCount = byteData.getUint32(107, Endian.little);
        }
      } else {
        // LAS 1.0-1.3: 32-bit point count at offset 107
        pointCount = byteData.getUint32(107, Endian.little);
      }

      // Offsets
      final offsetX = byteData.getFloat64(131, Endian.little);
      final offsetY = byteData.getFloat64(139, Endian.little);
      final offsetZ = byteData.getFloat64(147, Endian.little);

      // Bounding Box
      final maxX = byteData.getFloat64(179, Endian.little);
      final minX = byteData.getFloat64(187, Endian.little);
      final maxY = byteData.getFloat64(195, Endian.little);
      final minY = byteData.getFloat64(203, Endian.little);
      final maxZ = byteData.getFloat64(211, Endian.little);
      final minZ = byteData.getFloat64(219, Endian.little);

      // Point Data Formatから属性を判定
      // Format 2, 3, 5, 7, 8, 10 は色情報を持つ
      final hasColor = [2, 3, 5, 7, 8, 10].contains(pointDataFormat);
      // 全てのFormatは強度情報を持つ
      const hasIntensity = true;
      // 全てのFormatは分類情報を持つ
      const hasClassification = true;

      final geoRef = GeoReference(
        origin: GeoPosition(
          longitude: offsetX,
          latitude: offsetY,
          height: offsetZ,
        ),
        boundingBox: BoundingBox(
          minX: minX,
          minY: minY,
          minZ: minZ,
          maxX: maxX,
          maxY: maxY,
          maxZ: maxZ,
        ),
        detectionMethod: 'las_header',
      );

      return PointCloudFileInfo(
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
        formatVersion: 'LAS $formatVersion',
        pointCount: pointCount,
        geoReference: geoRef,
        pointDataFormat: pointDataFormat,
        hasColor: hasColor,
        hasIntensity: hasIntensity,
        hasClassification: hasClassification,
      );
    } catch (e) {
      logError('Failed to analyze LAS file in detail: $e');
      return PointCloudFileInfo(
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
      );
    }
  }

  /// PLYファイルの解析
  Future<GeoReference?> _analyzePly(String filePath) async {
    try {
      final file = File(filePath);
      final lines = await file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(100)
          .toList();

      // PLYヘッダ解析
      bool hasGeoRef = false;
      int? epsg;

      for (final line in lines) {
        if (line.contains('comment') && line.contains('EPSG')) {
          hasGeoRef = true;
          // コメントからEPSG番号を抽出
          final match = RegExp(r'EPSG[:\s]*(\d+)').firstMatch(line);
          if (match != null) {
            epsg = int.tryParse(match.group(1) ?? '');
          }
        }
        if (line == 'end_header') break;
      }

      return hasGeoRef
          ? GeoReference(epsg: epsg, detectionMethod: 'ply_comment')
          : null;
    } catch (e) {
      logError('Failed to analyze PLY file: $e');
      return null;
    }
  }

  /// PLYファイルの詳細解析
  Future<PointCloudFileInfo> _analyzePlyDetailed(
    String filePath,
    String fileName,
    int fileSize,
  ) async {
    try {
      final file = File(filePath);
      final lines = await file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(100)
          .toList();

      int? vertexCount;
      bool hasColor = false;
      bool isBinary = false;
      String format = 'PLY';

      for (final line in lines) {
        if (line.startsWith('format')) {
          if (line.contains('binary')) {
            isBinary = true;
            format = 'PLY (binary)';
          } else {
            format = 'PLY (ascii)';
          }
        }
        if (line.startsWith('element vertex')) {
          vertexCount = int.tryParse(line.split(' ').last);
        }
        if (line.startsWith('property') &&
            (line.contains('red') ||
                line.contains('green') ||
                line.contains('blue'))) {
          hasColor = true;
        }
        if (line == 'end_header') break;
      }

      return PointCloudFileInfo(
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
        formatVersion: format,
        pointCount: vertexCount,
        hasColor: hasColor,
      );
    } catch (e) {
      logError('Failed to analyze PLY file in detail: $e');
      return PointCloudFileInfo(
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
      );
    }
  }

  /// E57ファイルの解析
  Future<GeoReference?> _analyzeE57(String filePath) async {
    // E57は複雑なXML/バイナリ形式のため、簡易解析のみ
    // 完全な解析にはlibE57が必要
    logInfo('E57 analysis is limited - full parsing requires libE57');
    return null;
  }

  /// E57ファイルの詳細解析
  Future<PointCloudFileInfo> _analyzeE57Detailed(
    String filePath,
    String fileName,
    int fileSize,
  ) async {
    // E57は複雑なフォーマットのため、基本情報のみ返す
    return PointCloudFileInfo(
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      formatVersion: 'E57',
    );
  }

  /// OBJファイルの解析
  Future<GeoReference?> _analyzeObj(String filePath) async {
    // .prjファイルを探す
    final prjPath = filePath.replaceAll('.obj', '.prj');
    if (await File(prjPath).exists()) {
      final wkt = await File(prjPath).readAsString();
      // 簡易的にEPSGを探す
      final match = RegExp(r'EPSG[",:\s]*(\d+)').firstMatch(wkt);
      final epsg = match != null ? int.tryParse(match.group(1) ?? '') : null;

      return GeoReference(
        epsg: epsg,
        detectionMethod: 'prj_file',
      );
    }
    return null;
  }

  /// glTF/GLBファイルの解析
  Future<GeoReference?> _analyzeGltf(String filePath) async {
    try {
      final ext = path.extension(filePath).toLowerCase();

      if (ext == '.glb') {
        // GLBバイナリ解析は複雑なため、スキップ
        return null;
      } else {
        // glTF JSON解析
        final file = File(filePath);
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        // extensionsから位置情報を探す
        if (json.containsKey('extensions')) {
          final extensions = json['extensions'] as Map<String, dynamic>;
          if (extensions.containsKey('CESIUM_RTC')) {
            final rtc = extensions['CESIUM_RTC'] as Map<String, dynamic>;
            final center = rtc['center'] as List<dynamic>;
            return GeoReference(
              origin: GeoPosition(
                longitude: (center[0] as num).toDouble(),
                latitude: (center[1] as num).toDouble(),
                height: (center[2] as num).toDouble(),
              ),
              detectionMethod: 'gltf_cesium_rtc',
            );
          }
        }
      }
    } catch (e) {
      logError('Failed to analyze glTF file: $e');
    }
    return null;
  }

  /// ファイルサイズを取得
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    return await file.length();
  }

  /// 点群の概算点数を取得
  Future<int?> estimatePointCount(String filePath) async {
    final ext = path.extension(filePath).toLowerCase();

    if (ext == '.las' || ext == '.laz') {
      try {
        final file = File(filePath);
        final bytes = await file.openRead(0, 255).fold<List<int>>(
          [],
          (prev, chunk) => prev..addAll(chunk),
        );

        if (bytes.length >= 247) {
          final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
          // Legacy Point Count (32-bit)
          return byteData.getUint32(107, Endian.little);
        }
      } catch (e) {
        logError('Failed to estimate point count: $e');
      }
    }

    return null;
  }
}
