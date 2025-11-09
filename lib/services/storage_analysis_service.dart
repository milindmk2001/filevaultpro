import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'metadata_service.dart';
import '../utils/source_classifier.dart';

/// Storage category by size
enum SizeCategory {
  tiny,      // 0-10 MB
  small,     // 10-50 MB
  medium,    // 50-100 MB
  large,     // 100-500 MB
  huge,      // 500 MB - 1 GB
  massive,   // > 1 GB
}

/// Storage category by age
enum AgeCategory {
  today,       // < 1 day
  thisWeek,    // 1-7 days
  thisMonth,   // 7-30 days
  last3Months, // 30-90 days
  last6Months, // 90-180 days
  older,       // > 180 days
}

/// Model for storage breakdown item
class StorageBreakdownItem {
  final String category;
  final int fileCount;
  final int totalSize;
  final List<FileMetadata> files;
  final String icon;
  final String color;

  StorageBreakdownItem({
    required this.category,
    required this.fileCount,
    required this.totalSize,
    required this.files,
    required this.icon,
    required this.color,
  });

  double get percentage {
    // Calculate percentage (will be set by parent)
    return 0.0;
  }
}

/// Service for analyzing storage
class StorageAnalysisService {
  /// Get device storage information
  static Future<Map<String, dynamic>> getDeviceStorage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      
      // Get total device storage (this is an approximation)
      // In production, you'd use disk_space plugin for accurate info
      final stat = await FileStat.stat(appDir.path);
      
      // For now, return app directory info
      final importsDir = Directory(path.join(appDir.path, 'imports'));
      int appUsedSpace = 0;
      
      if (await importsDir.exists()) {
        final files = await importsDir.list().toList();
        for (var file in files) {
          if (file is File) {
            appUsedSpace += await file.length();
          }
        }
      }

      // Mock device storage (you can enhance with disk_space plugin)
      final totalSpace = 128 * 1024 * 1024 * 1024; // 128 GB (mock)
      final usedSpace = 83 * 1024 * 1024 * 1024 + appUsedSpace; // Mock + real app
      final availableSpace = totalSpace - usedSpace;

      return {
        'totalSpace': totalSpace,
        'usedSpace': usedSpace,
        'availableSpace': availableSpace,
        'appUsedSpace': appUsedSpace,
        'percentUsed': (usedSpace / totalSpace * 100).round(),
        'percentAvailable': (availableSpace / totalSpace * 100).round(),
      };
    } catch (e) {
      print('Error getting device storage: $e');
      return {
        'totalSpace': 0,
        'usedSpace': 0,
        'availableSpace': 0,
        'appUsedSpace': 0,
        'percentUsed': 0,
        'percentAvailable': 100,
      };
    }
  }

  /// Calculate storage by file type
  static Future<List<StorageBreakdownItem>> calculateByType() async {
    final allMetadata = await MetadataService.loadAllMetadata();
    
    final Map<String, List<FileMetadata>> grouped = {
      'Documents': [],
      'Images': [],
      'Videos': [],
      'Audio': [],
      'Others': [],
    };

    for (var metadata in allMetadata) {
      final fileType = _getFileType(metadata.fileName);
      grouped[fileType]!.add(metadata);
    }

    final items = <StorageBreakdownItem>[];
    final totalSize = allMetadata.fold<int>(0, (sum, m) => sum + m.size);

    grouped.forEach((type, files) {
      if (files.isNotEmpty) {
        final typeSize = files.fold<int>(0, (sum, f) => sum + f.size);
        items.add(StorageBreakdownItem(
          category: type,
          fileCount: files.length,
          totalSize: typeSize,
          files: files,
          icon: _getTypeIcon(type),
          color: _getTypeColor(type),
        ));
      }
    });

    // Sort by size (largest first)
    items.sort((a, b) => b.totalSize.compareTo(a.totalSize));
    
    return items;
  }

  /// Calculate storage by source
  static Future<List<StorageBreakdownItem>> calculateBySource() async {
    final grouped = await MetadataService.getFilesBySource();
    final items = <StorageBreakdownItem>[];

    grouped.forEach((source, files) {
      if (files.isNotEmpty) {
        final sourceSize = files.fold<int>(0, (sum, f) => sum + f.size);
        items.add(StorageBreakdownItem(
          category: source,
          fileCount: files.length,
          totalSize: sourceSize,
          files: files,
          icon: SourceClassifier.getSourceIcon(source),
          color: _getSourceColor(source),
        ));
      }
    });

    // Sort by size (largest first)
    items.sort((a, b) => b.totalSize.compareTo(a.totalSize));
    
    return items;
  }

  /// Calculate storage by file size
  static Future<List<StorageBreakdownItem>> calculateBySize() async {
    final allMetadata = await MetadataService.loadAllMetadata();
    
    final Map<String, List<FileMetadata>> grouped = {
      'Massive (>1GB)': [],
      'Huge (500MB-1GB)': [],
      'Large (100-500MB)': [],
      'Medium (50-100MB)': [],
      'Small (10-50MB)': [],
      'Tiny (<10MB)': [],
    };

    for (var metadata in allMetadata) {
      final category = _getSizeCategory(metadata.size);
      grouped[category]!.add(metadata);
    }

    final items = <StorageBreakdownItem>[];

    grouped.forEach((category, files) {
      if (files.isNotEmpty) {
        final categorySize = files.fold<int>(0, (sum, f) => sum + f.size);
        items.add(StorageBreakdownItem(
          category: category,
          fileCount: files.length,
          totalSize: categorySize,
          files: files,
          icon: _getSizeIcon(category),
          color: _getSizeColor(category),
        ));
      }
    });

    // Keep order: Massive to Tiny
    final order = [
      'Massive (>1GB)',
      'Huge (500MB-1GB)',
      'Large (100-500MB)',
      'Medium (50-100MB)',
      'Small (10-50MB)',
      'Tiny (<10MB)',
    ];
    
    items.sort((a, b) => order.indexOf(a.category).compareTo(order.indexOf(b.category)));
    
    return items;
  }

  /// Calculate storage by age
  static Future<List<StorageBreakdownItem>> calculateByAge() async {
    final allMetadata = await MetadataService.loadAllMetadata();
    final now = DateTime.now();
    
    final Map<String, List<FileMetadata>> grouped = {
      'Today': [],
      'This Week': [],
      'This Month': [],
      'Last 3 Months': [],
      'Last 6 Months': [],
      'Older': [],
    };

    for (var metadata in allMetadata) {
      final category = _getAgeCategory(metadata.importedAt, now);
      grouped[category]!.add(metadata);
    }

    final items = <StorageBreakdownItem>[];

    grouped.forEach((category, files) {
      if (files.isNotEmpty) {
        final categorySize = files.fold<int>(0, (sum, f) => sum + f.size);
        items.add(StorageBreakdownItem(
          category: category,
          fileCount: files.length,
          totalSize: categorySize,
          files: files,
          icon: _getAgeIcon(category),
          color: _getAgeColor(category),
        ));
      }
    });

    // Keep order: Today to Older
    final order = [
      'Today',
      'This Week',
      'This Month',
      'Last 3 Months',
      'Last 6 Months',
      'Older',
    ];
    
    items.sort((a, b) => order.indexOf(a.category).compareTo(order.indexOf(b.category)));
    
    return items;
  }

  // Helper methods
  
  static String _getFileType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    
    // Documents
    if (['.pdf', '.doc', '.docx', '.txt', '.rtf', '.pages', '.xls', '.xlsx', '.ppt', '.pptx'].contains(ext)) {
      return 'Documents';
    }
    
    // Images
    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic', '.svg'].contains(ext)) {
      return 'Images';
    }
    
    // Videos
    if (['.mp4', '.mov', '.avi', '.mkv', '.wmv', '.flv', '.webm', '.m4v'].contains(ext)) {
      return 'Videos';
    }
    
    // Audio
    if (['.mp3', '.wav', '.aac', '.flac', '.m4a', '.ogg', '.wma'].contains(ext)) {
      return 'Audio';
    }
    
    return 'Others';
  }

  static String _getTypeIcon(String type) {
    switch (type) {
      case 'Documents':
        return '📄';
      case 'Images':
        return '🖼️';
      case 'Videos':
        return '🎥';
      case 'Audio':
        return '🎵';
      case 'Others':
      default:
        return '📁';
    }
  }

  static String _getTypeColor(String type) {
    switch (type) {
      case 'Documents':
        return '0xFF2196F3'; // Blue
      case 'Images':
        return '0xFF4CAF50'; // Green
      case 'Videos':
        return '0xFFF44336'; // Red
      case 'Audio':
        return '0xFFFF9800'; // Orange
      case 'Others':
      default:
        return '0xFF9C27B0'; // Purple
    }
  }

  static String _getSourceColor(String source) {
    switch (source) {
      case SourceClassifier.CAMERA:
        return '0xFF2196F3'; // Blue
      case SourceClassifier.MESSENGER:
        return '0xFF9C27B0'; // Purple
      case SourceClassifier.DOWNLOADS:
        return '0xFF4CAF50'; // Green
      case SourceClassifier.COMPUTER:
        return '0xFFFF9800'; // Orange
      case SourceClassifier.CLOUD:
        return '0xFF00BCD4'; // Cyan
      case SourceClassifier.APPS:
        return '0xFFE91E63'; // Pink
      default:
        return '0xFF9E9E9E'; // Grey
    }
  }

  static String _getSizeCategory(int bytes) {
    const mb = 1024 * 1024;
    const gb = 1024 * mb;
    
    if (bytes > gb) return 'Massive (>1GB)';
    if (bytes > 500 * mb) return 'Huge (500MB-1GB)';
    if (bytes > 100 * mb) return 'Large (100-500MB)';
    if (bytes > 50 * mb) return 'Medium (50-100MB)';
    if (bytes > 10 * mb) return 'Small (10-50MB)';
    return 'Tiny (<10MB)';
  }

  static String _getSizeIcon(String category) {
    if (category.contains('Massive')) return '🟣';
    if (category.contains('Huge')) return '🔴';
    if (category.contains('Large')) return '🟠';
    if (category.contains('Medium')) return '🟡';
    if (category.contains('Small')) return '🟢';
    return '🔵'; // Tiny
  }

  static String _getSizeColor(String category) {
    if (category.contains('Massive')) return '0xFF9C27B0'; // Purple
    if (category.contains('Huge')) return '0xFFF44336'; // Red
    if (category.contains('Large')) return '0xFFFF9800'; // Orange
    if (category.contains('Medium')) return '0xFFFFEB3B'; // Yellow
    if (category.contains('Small')) return '0xFF4CAF50'; // Green
    return '0xFF2196F3'; // Blue (Tiny)
  }

  static String _getAgeCategory(DateTime importDate, DateTime now) {
    final difference = now.difference(importDate);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays <= 7) return 'This Week';
    if (difference.inDays <= 30) return 'This Month';
    if (difference.inDays <= 90) return 'Last 3 Months';
    if (difference.inDays <= 180) return 'Last 6 Months';
    return 'Older';
  }

  static String _getAgeIcon(String category) {
    switch (category) {
      case 'Today':
        return '🟢';
      case 'This Week':
        return '🔵';
      case 'This Month':
        return '🟡';
      case 'Last 3 Months':
        return '🟠';
      case 'Last 6 Months':
        return '🔴';
      case 'Older':
      default:
        return '🟣';
    }
  }

  static String _getAgeColor(String category) {
    switch (category) {
      case 'Today':
        return '0xFF4CAF50'; // Green
      case 'This Week':
        return '0xFF2196F3'; // Blue
      case 'This Month':
        return '0xFFFFEB3B'; // Yellow
      case 'Last 3 Months':
        return '0xFFFF9800'; // Orange
      case 'Last 6 Months':
        return '0xFFF44336'; // Red
      case 'Older':
      default:
        return '0xFF9C27B0'; // Purple
    }
  }
}
