import 'dart:io';
import 'package:flutter/services.dart';

class FolderPickerService {
  static const MethodChannel _channel =
      MethodChannel('com.filevaultpro/folder_picker');

  /// Pick a folder using native iOS folder picker
  /// Returns a Map with 'path' and 'name' keys, or null if cancelled
  static Future<Map<String, String>?> pickFolder() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('Folder picker is only supported on iOS');
    }

    try {
      final result = await _channel.invokeMethod<Map>('pickFolder');
      
      if (result == null) {
        return null;
      }

      return {
        'path': result['path'] as String,
        'name': result['name'] as String,
      };
    } on PlatformException catch (e) {
      if (e.code == 'PICKER_CANCELLED') {
        // User cancelled, return null
        return null;
      }
      // Re-throw other errors
      rethrow;
    }
  }
}
