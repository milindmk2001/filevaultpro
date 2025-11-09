import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/folder_picker_service.dart';
import '../services/compression_service.dart';
import '../services/metadata_service.dart';
import '../utils/source_classifier.dart';

/// Enhanced File Explorer - Full Browse + File Opening + Smart Import
/// Fixed: Copies files to temp before opening (iOS security)
class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({Key? key}) : super(key: key);

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  String _currentView = 'browse';
  List<FileSystemEntity> _importedFiles = [];
  bool _isLoading = false;
  Directory? _currentDirectory;
  List<FileSystemEntity> _currentItems = [];
  final List<Directory> _navigationHistory = [];

  @override
  void initState() {
    super.initState();
    _loadImportedFiles();
  }

  Future<void> _loadImportedFiles() async {
    setState(() => _isLoading = true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final importsDir = Directory(path.join(appDir.path, 'imports'));

      if (!await importsDir.exists()) {
        await importsDir.create(recursive: true);
      }

      final files = await importsDir
          .list()
          .where((entity) => entity is File)
          .toList();

      setState(() {
        _importedFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load files: $e');
    }
  }

  Future<void> _switchToBrowseMode() async {
    setState(() {
      _currentView = 'browse';
      _currentDirectory = null;
      _navigationHistory.clear();
    });
  }

  void _switchToImportsMode() {
    setState(() {
      _currentView = 'imports';
      _currentDirectory = null;
      _navigationHistory.clear();
    });
    _loadImportedFiles();
  }

  Future<void> _loadDirectory(Directory directory) async {
    setState(() => _isLoading = true);

    try {
      final items = await directory.list().toList();
      
      items.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        
        return path.basename(a.path).toLowerCase()
            .compareTo(path.basename(b.path).toLowerCase());
      });

      setState(() {
        if (_currentDirectory != null) {
          _navigationHistory.add(_currentDirectory!);
        }
        _currentDirectory = directory;
        _currentItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Cannot access this folder: $e');
    }
  }

  void _navigateBack() {
    if (_navigationHistory.isEmpty) {
      _switchToBrowseMode();
    } else {
      final previousDir = _navigationHistory.removeLast();
      setState(() {
        _currentDirectory = previousDir;
      });
      _loadDirectory(previousDir);
    }
  }

  Future<void> _browseDeviceFiles(String location) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder_open, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Browse $location')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'iOS file picker will open.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text(
                'You can:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _buildBrowseStep('📁 Browse all locations'),
              _buildBrowseStep('👀 Select files to view'),
              _buildBrowseStep('📂 Navigate folders'),
              _buildBrowseStep('📤 Open or share files'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Files will be copied to app storage before opening (iOS security requirement)',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openBrowsePicker();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Open Browser', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseStep(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _openBrowsePicker() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(child: Text('Opening browser...')),
              ],
            ),
          ),
        ),
      );

      await Future.delayed(Duration(milliseconds: 300));

      final folderResult = await FolderPickerService.pickFolder();

      if (mounted) Navigator.pop(context);

      if (folderResult != null) {
        final selectedPath = folderResult['path']!;
        final selectedName = folderResult['name']!;
        
        // Check if it's a file or folder
        final entity = FileSystemEntity.typeSync(selectedPath);
        if (entity == FileSystemEntityType.file) {
          // It's a file - copy to temp and show options
          await _handleBrowsedFile(selectedPath, selectedName);
        } else {
          // It's a folder - show folder info
          _showBrowseResultDialog(selectedName, selectedPath);
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Failed to open browser: $e');
    }
  }

  Future<void> _handleBrowsedFile(String originalPath, String fileName) async {
    try {
      // Show copying dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Preparing file...'),
                SizedBox(height: 8),
                Text(
                  fileName,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      // Copy file to temp directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFileName = '${timestamp}_$fileName';
      final tempFilePath = path.join(tempDir.path, tempFileName);

      // Read source file
      final sourceFile = File(originalPath);
      final bytes = await sourceFile.readAsBytes();
      
      // Write to temp
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(bytes);

      if (mounted) Navigator.pop(context);

      // Show file options with temp file
      _showFileOptionsDialog(tempFile, isFromBrowser: true);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Failed to prepare file: $e');
    }
  }

  void _showBrowseResultDialog(String folderName, String folderPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Folder Selected')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📁 $folderName',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              '📍 Path:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              folderPath,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Want to import this folder?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Use the green + button for Smart Folder Import!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _onItemTap(FileSystemEntity item) {
    if (item is Directory) {
      _loadDirectory(item);
    } else if (item is File) {
      _showFileOptionsDialog(item, isFromBrowser: false);
    }
  }

  Future<void> _showFileOptionsDialog(File file, {required bool isFromBrowser}) async {
    final fileName = path.basename(file.path);
    final fileSize = file.lengthSync();
    final fileExt = path.extension(file.path);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getFileIcon(file.path), color: _getFileColor(file.path), size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                fileName,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFileInfoRow(Icons.straighten, 'Size', _formatBytes(fileSize)),
              SizedBox(height: 8),
              _buildFileInfoRow(Icons.description, 'Type', fileExt.isNotEmpty ? fileExt : 'Unknown'),
              SizedBox(height: 8),
              _buildFileInfoRow(Icons.location_on, 'Location', 
                isFromBrowser ? 'Temporary (copied from device)' : path.dirname(file.path)),
              if (isFromBrowser) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'File copied to app storage for opening',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Actions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.open_in_new, size: 16, color: Colors.blue.shade700),
                        SizedBox(width: 4),
                        Text('Open with default app', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.share, size: 16, color: Colors.blue.shade700),
                        SizedBox(width: 4),
                        Text('Share with other apps', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareFile(file);
            },
            icon: Icon(Icons.share),
            label: Text('Share'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openFile(file);
            },
            icon: Icon(Icons.open_in_new),
            label: Text('Open'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openFile(File file) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Opening file...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Small delay to ensure file is ready
      await Future.delayed(Duration(milliseconds: 500));

      final result = await OpenFilex.open(file.path);

      if (mounted) Navigator.pop(context);

      if (result.type != ResultType.done) {
        String message = 'Could not open file';
        
        switch (result.type) {
          case ResultType.noAppToOpen:
            message = 'No app installed to open this file type.\n\nTry using the Share button to open in another app.';
            break;
          case ResultType.fileNotFound:
            message = 'File not found';
            break;
          case ResultType.permissionDenied:
            message = 'Permission denied';
            break;
          case ResultType.error:
            message = 'Error: ${result.message}';
            break;
          default:
            message = 'Could not open file';
        }

        _showError(message);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('File opened successfully!')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Failed to open file: $e');
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sharing ${path.basename(file.path)}',
      );

      if (result.status == ShareResultStatus.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('File shared successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Failed to share file: $e');
    }
  }

  Future<void> _showSmartFolderImportDialog() async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder_special, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Smart Folder Import')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import & compress folders:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              _buildStep(1, 'Files app opens with green button'),
              _buildStep(2, 'Browse to your folder'),
              _buildStep(3, 'Tap any item inside the folder'),
              _buildStep(4, 'Click green "Select This Folder" button'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_zip, color: Colors.green.shade700, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Compresses all subfolders automatically!',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Open Picker', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (shouldProceed == true) {
      await _handleSmartFolderImport();
    }
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: TextStyle(fontSize: 14, height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSmartFolderImport() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(child: Text('Opening folder picker...')),
              ],
            ),
          ),
        ),
      );

      await Future.delayed(Duration(milliseconds: 300));

      final folderResult = await FolderPickerService.pickFolder();

      if (mounted) Navigator.pop(context);

      if (folderResult == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder selection cancelled')),
          );
        }
        return;
      }

      final folderPath = folderResult['path']!;
      final folderName = folderResult['name']!;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Compressing folder...'),
                  SizedBox(height: 8),
                  Text(
                    folderName,
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Including all subfolders',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFileName = '${folderName}_$timestamp.zip';
      final zipPath = path.join(appDir.path, 'imports', zipFileName);

      final importsDir = Directory(path.join(appDir.path, 'imports'));
      if (!await importsDir.exists()) {
        await importsDir.create(recursive: true);
      }

      final compressionResult = await CompressionService.compressFolder(
        sourcePath: folderPath,
        destinationPath: zipPath,
      );

      if (mounted) Navigator.pop(context);

      if (compressionResult['success'] == true) {
        final fileSize = compressionResult['size'] as int;
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
        // Detect source and save metadata
        final source = SourceClassifier.detectSource(folderPath);
        final detailedSource = SourceClassifier.getDetailedSource(folderPath);

        final metadata = FileMetadata(
          fileName: zipFileName,
          source: source,
          detailedSource: detailedSource,
          size: fileSize,
          importedAt: DateTime.now(),
          originalPath: folderPath,
        );

        await MetadataService.saveMetadata(metadata);


        await _loadImportedFiles();
        _switchToImportsMode();

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 32),
                  SizedBox(width: 12),
                  Expanded(child: Text('Import Successful!')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ Folder: $folderName'),
                  SizedBox(height: 8),
                  Text('📦 Size: $fileSizeMB MB'),
                  SizedBox(height: 8),
                  Text('📁 All subfolders included'),
                  SizedBox(height: 8),
                  Text(
                    '📍 Location: Documents/imports/',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Compression failed');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      _showError('Import failed: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        return Icons.image;
      case '.mp4':
      case '.mov':
        return Icons.video_file;
      case '.mp3':
      case '.wav':
        return Icons.audiotrack;
      case '.zip':
      case '.rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.pdf':
        return Colors.red;
      case '.doc':
      case '.docx':
        return Colors.blue;
      case '.jpg':
      case '.jpeg':
      case '.png':
        return Colors.orange;
      case '.mp4':
      case '.mov':
        return Colors.purple;
      case '.zip':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentView == 'browse' ? 'Browse' : 'Imported Files'),
        leading: _currentDirectory != null || _navigationHistory.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: _navigateBack,
              )
            : null,
        actions: [
          if (_currentView == 'imports')
            IconButton(
              icon: Icon(Icons.folder_open),
              onPressed: _switchToBrowseMode,
              tooltip: 'Browse',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _currentView == 'imports' ? _loadImportedFiles : null,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _currentView == 'browse' && _currentDirectory == null
          ? _buildBrowseView()
          : _currentView == 'browse' && _currentDirectory != null
              ? _buildDirectoryView()
              : _buildImportsView(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSmartFolderImportDialog,
        backgroundColor: Colors.green,
        child: Icon(Icons.add),
        tooltip: 'Smart Folder Import',
      ),
    );
  }

  Widget _buildBrowseView() {
    return ListView(
      padding: EdgeInsets.all(8),
      children: [
        _buildSectionHeader('Locations'),
        _buildLocationTile(
          'iCloud Drive',
          'Browse your iCloud files',
          Icons.cloud,
          Colors.blue,
          () => _browseDeviceFiles('iCloud Drive'),
        ),
        _buildLocationTile(
          'On My iPhone',
          'Browse files stored on this device',
          Icons.phone_iphone,
          Colors.blue,
          () => _browseDeviceFiles('On My iPhone'),
        ),
        _buildLocationTile(
          'Documents',
          'Browse app documents folder',
          Icons.description,
          Colors.blue,
          () async {
            final dir = await getApplicationDocumentsDirectory();
            _loadDirectory(dir);
          },
        ),
        SizedBox(height: 16),
        _buildSectionHeader('Favourites'),
        _buildLocationTile(
          'Downloads',
          'Browse downloaded files',
          Icons.download,
          Colors.blue,
          () => _browseDeviceFiles('Downloads'),
        ),
        SizedBox(height: 16),
        _buildSectionHeader('My Imports'),
        _buildLocationTile(
          'Imported Files',
          '${_importedFiles.length} compressed folders',
          Icons.folder_zip,
          Colors.green,
          () => _switchToImportsMode(),
        ),
        SizedBox(height: 16),
        _buildSectionHeader('Tags'),
        _buildTagTile('Red', Colors.red),
        _buildTagTile('Orange', Colors.orange),
        _buildTagTile('Yellow', Colors.yellow),
        _buildTagTile('Green', Colors.green),
        _buildTagTile('Blue', Colors.blue),
      ],
    );
  }

  Widget _buildDirectoryView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Icon(Icons.folder, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  path.basename(_currentDirectory!.path),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${_currentItems.length} items',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _currentItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
                          SizedBox(height: 16),
                          Text('Empty folder', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _currentItems.length,
                      itemBuilder: (context, index) {
                        final item = _currentItems[index];
                        final isDirectory = item is Directory;
                        final name = path.basename(item.path);

                        return ListTile(
                          leading: Icon(
                            isDirectory ? Icons.folder : _getFileIcon(item.path),
                            color: isDirectory ? Colors.amber : _getFileColor(item.path),
                            size: 40,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isDirectory ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                          subtitle: !isDirectory && item is File
                              ? Text(_formatBytes(item.lengthSync()))
                              : null,
                          trailing: Icon(
                            isDirectory ? Icons.chevron_right : Icons.more_vert,
                            color: Colors.grey,
                          ),
                          onTap: () => _onItemTap(item),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildImportsView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Icon(Icons.folder_zip, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Documents/imports/',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${_importedFiles.length} files',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _importedFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
                          SizedBox(height: 16),
                          Text('No imported files', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          SizedBox(height: 8),
                          Text('Tap + to import folders', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _importedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _importedFiles[index] as File;
                        final fileName = path.basename(file.path);
                        final fileSize = file.lengthSync();

                        return ListTile(
                          leading: Icon(Icons.folder_zip, size: 40, color: Colors.green),
                          title: Text(fileName, style: TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(_formatBytes(fileSize)),
                          trailing: Icon(Icons.more_vert, color: Colors.grey),
                          onTap: () => _showFileOptionsDialog(file, isFromBrowser: false),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildLocationTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color, size: 28),
      title: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildTagTile(String name, Color color) {
    return ListTile(
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(name, style: TextStyle(fontSize: 16)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => _showError('Tag filtering not yet implemented'),
    );
  }
}