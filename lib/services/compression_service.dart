import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class CompressionService {
  static const MethodChannel _channel = MethodChannel('com.filevaultpro/compression');

  /// Compress multiple folders/files into a single ZIP
  /// 
  /// [paths] - List of file/folder paths to compress
  /// [outputName] - Name for the ZIP file (optional, auto-generated if null)
  /// [preserveStructure] - If true, maintains folder hierarchy (default: true)
  /// 
  /// Returns the path to the created ZIP file
  static Future<String> compressFolders({
    required List<String> paths,
    String? outputName,
    bool preserveStructure = true,
  }) async {
    if (paths.isEmpty) {
      throw Exception('No paths provided for compression');
    }

    try {
      // Generate output path in same directory as first item
      final directory = Directory(paths[0]).parent;
      final zipName = outputName ?? 'Archive_${DateTime.now().millisecondsSinceEpoch}.zip';
      final outputPath = path.join(directory.path, zipName);

      // Call native iOS compression
      final result = await _channel.invokeMethod('compressFolders', {
        'paths': paths,
        'outputPath': outputPath,
        'preserveStructure': preserveStructure,
      });

      if (result is Map && result['success'] == true) {
        return result['path'] as String;
      } else {
        throw Exception('Compression failed: ${result['message'] ?? 'Unknown error'}');
      }
    } on PlatformException catch (e) {
      throw Exception('Platform error: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Compression error: $e');
    }
  }

  /// Get the total size of a directory (recursive)
  static Future<int> getDirectorySize(String dirPath) async {
    try {
      final size = await _channel.invokeMethod('getDirectorySize', {
        'path': dirPath,
      });
      return size as int;
    } on PlatformException catch (e) {
      throw Exception('Failed to get directory size: ${e.message}');
    }
  }

  /// Count total items in directory (recursive)
  static Future<int> countItems(String dirPath) async {
    try {
      final count = await _channel.invokeMethod('countItems', {
        'path': dirPath,
      });
      return count as int;
    } on PlatformException catch (e) {
      throw Exception('Failed to count items: ${e.message}');
    }
  }

  /// Format bytes to human-readable size
  static String formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes == 0) return '0 B';
    
    var size = bytes.toDouble();
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  /// Get compression statistics for multiple paths
  static Future<Map<String, dynamic>> getCompressionStats(List<String> paths) async {
    int totalSize = 0;
    int totalItems = 0;

    for (final itemPath in paths) {
      final stat = await File(itemPath).stat();
      
      if (stat.type == FileSystemEntityType.directory) {
        final size = await getDirectorySize(itemPath);
        final count = await countItems(itemPath);
        totalSize += size;
        totalItems += count;
      } else {
        totalSize += stat.size;
        totalItems += 1;
      }
    }

    return {
      'totalSize': totalSize,
      'formattedSize': formatBytes(totalSize),
      'totalItems': totalItems,
      'pathCount': paths.length,
    };
  }
}