import 'dart:io';
import 'package:flutter/services.dart';

class CompressionService {
  static const MethodChannel _channel =
      MethodChannel('com.filevaultpro/compression');

  /// Compress a folder to a ZIP file using native iOS compression
  /// 
  /// [sourcePath] - Path to the folder to compress
  /// [destinationPath] - Path where the ZIP file will be created
  /// 
  /// Returns a Map with 'success', 'zipPath', and optionally 'size' keys
  static Future<Map<String, dynamic>> compressFolder({
    required String sourcePath,
    required String destinationPath,
  }) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('Native compression is only supported on iOS');
    }

    try {
      final result = await _channel.invokeMethod<Map>('compressFolder', {
        'sourcePath': sourcePath,
        'destinationPath': destinationPath,
      });

      if (result == null) {
        throw Exception('Compression failed: No result returned');
      }

      return {
        'success': result['success'] as bool,
        'zipPath': result['zipPath'] as String,
        'size': result['size'] as int? ?? 0,
      };
    } on PlatformException catch (e) {
      throw Exception('Compression failed: ${e.message}');
    }
  }

  /// Extract a ZIP file using native iOS extraction
  /// 
  /// [zipPath] - Path to the ZIP file to extract
  /// [destinationPath] - Path where files will be extracted
  /// 
  /// Returns a Map with 'success' and 'extractedPath' keys
  static Future<Map<String, dynamic>> extractZip({
    required String zipPath,
    required String destinationPath,
  }) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('Native extraction is only supported on iOS');
    }

    try {
      final result = await _channel.invokeMethod<Map>('extractZip', {
        'zipPath': zipPath,
        'destinationPath': destinationPath,
      });

      if (result == null) {
        throw Exception('Extraction failed: No result returned');
      }

      return {
        'success': result['success'] as bool,
        'extractedPath': result['extractedPath'] as String,
      };
    } on PlatformException catch (e) {
      throw Exception('Extraction failed: ${e.message}');
    }
  }
}
