import 'dart:io';

/// Utility class for detecting file source based on path
class SourceClassifier {
  static const String CAMERA = 'Camera';
  static const String DOWNLOADS = 'Downloads';
  static const String MESSENGER = 'Messenger Apps';
  static const String COMPUTER = 'Computer';
  static const String CLOUD = 'Cloud';
  static const String APPS = 'Apps';
  static const String OTHER = 'Other';

  /// Detect source from file/folder path
  static String detectSource(String path) {
    final lowerPath = path.toLowerCase();

    // Camera / Photos
    if (_isCamera(lowerPath)) return CAMERA;

    // Downloads
    if (_isDownloads(lowerPath)) return DOWNLOADS;

    // Messenger Apps (WhatsApp, Telegram, Signal, etc.)
    if (_isMessenger(lowerPath)) return MESSENGER;

    // Computer (AirDrop, Bluetooth, USB)
    if (_isComputer(lowerPath)) return COMPUTER;

    // Cloud (iCloud, Dropbox, Google Drive)
    if (_isCloud(lowerPath)) return CLOUD;

    // Other Apps
    if (_isApps(lowerPath)) return APPS;

    // Default
    return OTHER;
  }

  static bool _isCamera(String path) {
    return path.contains('/dcim/') ||
           path.contains('/camera') ||
           path.contains('photos/') ||
           path.contains('camera roll') ||
           path.contains('/media/camera') ||
           path.contains('100apple') ||
           path.contains('img_') ||
           path.contains('/pictures/');
  }

  static bool _isDownloads(String path) {
    return path.contains('/downloads/') ||
           path.contains('download/');
  }

  static bool _isMessenger(String path) {
    return path.contains('whatsapp') ||
           path.contains('telegram') ||
           path.contains('signal') ||
           path.contains('messenger') ||
           path.contains('wechat') ||
           path.contains('line/') ||
           path.contains('viber') ||
           path.contains('messages/') ||
           path.contains('imessage') ||
           path.contains('sms/');
  }

  static bool _isComputer(String path) {
    return path.contains('airdrop') ||
           path.contains('bluetooth') ||
           path.contains('usb') ||
           path.contains('transfer') ||
           path.contains('itunes') ||
           path.contains('finder');
  }

  static bool _isCloud(String path) {
    return path.contains('icloud') ||
           path.contains('cloud') ||
           path.contains('dropbox') ||
           path.contains('google drive') ||
           path.contains('onedrive') ||
           path.contains('box.com') ||
           path.contains('com~apple~clouddocs');
  }

  static bool _isApps(String path) {
    return path.contains('/documents/') ||
           path.contains('/app/') ||
           path.contains('/data/application') ||
           path.contains('library/application');
  }

  /// Get icon for source
  static String getSourceIcon(String source) {
    switch (source) {
      case CAMERA:
        return '📸';
      case DOWNLOADS:
        return '📥';
      case MESSENGER:
        return '💬';
      case COMPUTER:
        return '💻';
      case CLOUD:
        return '☁️';
      case APPS:
        return '📱';
      case OTHER:
      default:
        return '📁';
    }
  }

  /// Get detailed app name if possible
  static String getDetailedSource(String path) {
    final lowerPath = path.toLowerCase();

    // Messenger apps
    if (lowerPath.contains('whatsapp')) return 'WhatsApp';
    if (lowerPath.contains('telegram')) return 'Telegram';
    if (lowerPath.contains('signal')) return 'Signal';
    if (lowerPath.contains('messenger')) return 'Messenger';
    if (lowerPath.contains('wechat')) return 'WeChat';
    if (lowerPath.contains('line')) return 'LINE';
    if (lowerPath.contains('viber')) return 'Viber';

    // Cloud services
    if (lowerPath.contains('icloud')) return 'iCloud';
    if (lowerPath.contains('dropbox')) return 'Dropbox';
    if (lowerPath.contains('google drive')) return 'Google Drive';
    if (lowerPath.contains('onedrive')) return 'OneDrive';

    // Computer
    if (lowerPath.contains('airdrop')) return 'AirDrop';
    if (lowerPath.contains('bluetooth')) return 'Bluetooth';
    if (lowerPath.contains('usb')) return 'USB Transfer';

    // Return generic source
    return detectSource(path);
  }
}
