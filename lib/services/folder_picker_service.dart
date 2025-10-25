import 'package:flutter/services.dart';
import 'dart:io';

class FolderPickerService {
  static const MethodChannel _channel = MethodChannel('com.filevaultpro/folder_picker');

  /// Pick a folder using native iOS folder picker
  /// Returns the path where the folder was copied, or null if cancelled
  static Future<String?> pickFolder() async {
    try {
      final result = await _channel.invokeMethod('pickFolder');
      
      if (result is Map && result['success'] == true) {
        return result['path'] as String;
      }
      
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'PICKER_CANCELLED') {
        return null; // User cancelled, not an error
      }
      print('Error picking folder: ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected error picking folder: $e');
      return null;
    }
  }

  /// Pick folder and get detailed information
  static Future<Map<String, dynamic>?> pickFolderWithDetails() async {
    try {
      final result = await _channel.invokeMethod('pickFolder');
      
      if (result is Map && result['success'] == true) {
        return {
          'path': result['path'] as String,
          'folderName': result['folderName'] as String,
        };
      }
      
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'PICKER_CANCELLED') {
        return null;
      }
      throw Exception('Failed to pick folder: ${e.message}');
    }
  }
}
