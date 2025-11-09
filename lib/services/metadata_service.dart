import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Model for file metadata
class FileMetadata {
  final String fileName;
  final String source;
  final String detailedSource;
  final int size;
  final DateTime importedAt;
  final String originalPath;

  FileMetadata({
    required this.fileName,
    required this.source,
    required this.detailedSource,
    required this.size,
    required this.importedAt,
    required this.originalPath,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'source': source,
        'detailedSource': detailedSource,
        'size': size,
        'importedAt': importedAt.toIso8601String(),
        'originalPath': originalPath,
      };

  factory FileMetadata.fromJson(Map<String, dynamic> json) => FileMetadata(
        fileName: json['fileName'],
        source: json['source'],
        detailedSource: json['detailedSource'],
        size: json['size'],
        importedAt: DateTime.parse(json['importedAt']),
        originalPath: json['originalPath'],
      );
}

/// Service for managing file metadata
class MetadataService {
  static const String _metadataFileName = 'metadata.json';

  /// Get metadata file path
  static Future<File> _getMetadataFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final metadataPath = path.join(appDir.path, 'imports', _metadataFileName);
    return File(metadataPath);
  }

  /// Load all metadata
  static Future<List<FileMetadata>> loadAllMetadata() async {
    try {
      final file = await _getMetadataFile();
      
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      
      return jsonList.map((json) => FileMetadata.fromJson(json)).toList();
    } catch (e) {
      print('Error loading metadata: $e');
      return [];
    }
  }

  /// Save metadata for a file
  static Future<void> saveMetadata(FileMetadata metadata) async {
    try {
      final allMetadata = await loadAllMetadata();
      
      // Remove existing metadata for same file
      allMetadata.removeWhere((m) => m.fileName == metadata.fileName);
      
      // Add new metadata
      allMetadata.add(metadata);

      // Save all metadata
      final file = await _getMetadataFile();
      final jsonList = allMetadata.map((m) => m.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error saving metadata: $e');
    }
  }

  /// Get metadata for a specific file
  static Future<FileMetadata?> getMetadata(String fileName) async {
    try {
      final allMetadata = await loadAllMetadata();
      return allMetadata.firstWhere(
        (m) => m.fileName == fileName,
        orElse: () => throw Exception('Not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Delete metadata for a file
  static Future<void> deleteMetadata(String fileName) async {
    try {
      final allMetadata = await loadAllMetadata();
      allMetadata.removeWhere((m) => m.fileName == fileName);

      final file = await _getMetadataFile();
      final jsonList = allMetadata.map((m) => m.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error deleting metadata: $e');
    }
  }

  /// Get files grouped by source
  static Future<Map<String, List<FileMetadata>>> getFilesBySource() async {
    final allMetadata = await loadAllMetadata();
    final Map<String, List<FileMetadata>> grouped = {};

    for (var metadata in allMetadata) {
      if (!grouped.containsKey(metadata.source)) {
        grouped[metadata.source] = [];
      }
      grouped[metadata.source]!.add(metadata);
    }

    return grouped;
  }

  /// Get statistics
  static Future<Map<String, dynamic>> getStatistics() async {
    final allMetadata = await loadAllMetadata();
    final grouped = await getFilesBySource();

    int totalSize = 0;
    for (var metadata in allMetadata) {
      totalSize += metadata.size;
    }

    return {
      'totalFiles': allMetadata.length,
      'totalSize': totalSize,
      'bySource': grouped.map((source, files) => MapEntry(
            source,
            {
              'count': files.length,
              'size': files.fold<int>(0, (sum, f) => sum + f.size),
            },
          )),
      'recentFiles': allMetadata
          .where((m) => DateTime.now().difference(m.importedAt).inHours < 24)
          .length,
    };
  }
}
