import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/data_models.dart';
import '../widgets/common_widgets.dart';

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFileBrowser = false;
  bool _showMediaBrowser = false;
  String _currentPath = '';
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _initializePath();
  }

  Future<void> _initializePath() async {
    final directory = await getApplicationDocumentsDirectory();
    setState(() {
      _currentPath = directory.path;
    });
  }

  Future<void> _loadFiles(String path) async {
    try {
      final dir = Directory(path);
      final List<FileSystemEntity> entities = await dir.list().toList();
      setState(() {
        _files = entities;
        _currentPath = path;
      });
    } catch (e) {
      print('Error loading files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showFileBrowser) {
      return _buildFileBrowser();
    }
    
    if (_showMediaBrowser) {
      return _buildMediaBrowser();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            CommonWidgets.buildStatusBar(context, 'File Explorer'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Files',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Search Bar
                    CupertinoSearchTextField(
                      controller: _searchController,
                      placeholder: 'Search files and folders...',
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Quick Access
                    Text(
                      'Quick Access',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickAccessCard(
                            'Files',
                            '124 files',
                            'Last updated: Oct 26, 2023',
                            Icons.folder,
                            () => setState(() => _showFileBrowser = true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildQuickAccessCard(
                            'Media',
                            '850 files',
                            'Last updated: Nov 01, 2023',
                            Icons.folder,
                            () => setState(() => _showMediaBrowser = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Recent Files
                    Text(
                      'Recent Files',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Expanded(
                      child: ListView.separated(
                        itemCount: recentFiles.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final file = recentFiles[index];
                          return _buildRecentFileItem(file);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles();
          if (result != null) {
            // Handle file selection
          }
        },
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFileBrowser() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File Browser'),
            Text(
              _currentPath,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showFileBrowser = false),
        ),
      ),
      body: FutureBuilder(
        future: _loadFiles(_currentPath),
        builder: (context, snapshot) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _files.length,
            itemBuilder: (context, index) {
              final file = _files[index];
              final isDirectory = file is Directory;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    isDirectory ? Icons.folder : Icons.insert_drive_file,
                    color: isDirectory ? const Color(0xFF1976D2) : Colors.grey,
                    size: 32,
                  ),
                  title: Text(file.path.split('/').last),
                  subtitle: !isDirectory
                      ? Text(_formatFileSize(File(file.path).lengthSync()))
                      : null,
                  trailing: isDirectory
                      ? const Icon(Icons.chevron_right, color: Colors.grey)
                      : null,
                  onTap: isDirectory
                      ? () => _loadFiles(file.path)
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMediaBrowser() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Media Browser'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showMediaBrowser = false),
        ),
      ),
      body: const Center(
        child: Text('Media browser implementation'),
      ),
    );
  }

  Widget _buildQuickAccessCard(
    String title,
    String fileCount,
    String lastUpdated,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: const Color(0xFF1976D2), size: 24),
                const Icon(Icons.more_vert, color: Colors.grey, size: 20),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  fileCount,
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  lastUpdated,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFileItem(RecentFile file) {
    return Row(
      children: [
        Icon(file.icon, color: file.iconColor, size: 40),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${file.size} • ${file.date}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.more_vert, color: Colors.grey, size: 20),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}