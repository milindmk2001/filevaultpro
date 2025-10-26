import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../services/folder_picker_service.dart';
import '../services/compression_service.dart';

/// File Explorer Screen with Working Smart Folder Import
class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({Key? key}) : super(key: key);

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = false;
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final importsDir = Directory(path.join(appDir.path, 'imports'));

      if (!await importsDir.exists()) {
        await importsDir.create(recursive: true);
      }

      _currentPath = importsDir.path;

      final files = await importsDir
          .list()
          .where((entity) => entity is File)
          .toList();

      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading files: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        _showErrorDialog('Failed to load files: $e');
      }
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
                'How it works:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              _buildStep(1, 'Files app opens with a green button'),
              _buildStep(2, 'Navigate INTO the folder you want'),
              _buildStep(3, 'Tap on any file or folder inside'),
              _buildStep(4, 'Click the green "Select This Folder" button'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, color: Colors.amber.shade900, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Go inside the folder, tap any item, then click green button!',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Text('✨ ', style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: Text(
                      'All subfolders included automatically!',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
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
      // Show loading dialog
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

      // Small delay to show the dialog
      await Future.delayed(Duration(milliseconds: 300));

      // Step 1: Pick folder
      final folderResult = await FolderPickerService.pickFolder();

      // Close loading dialog
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

      // Show compression progress
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

      // Step 2: Compress folder
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

      // Close compression dialog
      if (mounted) Navigator.pop(context);

      if (compressionResult['success'] == true) {
        final fileSize = compressionResult['size'] as int;
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

        await _loadFiles();

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

      _showErrorDialog('Import failed: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  IconData _getFileIcon(String filePath) {
    final ext = _getFileExtension(filePath);
    switch (ext) {
      case '.zip':
        return Icons.folder_zip;
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.jpg':
      case '.jpeg':
      case '.png':
        return Icons.image;
      case '.mp4':
      case '.mov':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('File Explorer'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Icon(Icons.folder, size: 20, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Documents/imports/',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Text(
                  '${_files.length} files',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No files yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap + to import folders',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index] as File;
                          final fileName = path.basename(file.path);
                          final fileSize = file.lengthSync();

                          return ListTile(
                            leading: Icon(
                              _getFileIcon(file.path),
                              size: 40,
                              color: Colors.blue,
                            ),
                            title: Text(
                              fileName,
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(_formatFileSize(fileSize)),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Tapped: $fileName'),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showSmartFolderImportDialog,
        backgroundColor: Colors.green,
        child: Icon(Icons.add),
        tooltip: 'Smart Folder Import',
      ),
    );
  }
}
