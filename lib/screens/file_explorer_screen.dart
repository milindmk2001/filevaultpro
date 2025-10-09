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
  bool _isLoading = false;
  
  // Clipboard for cut/copy/paste
  FileSystemEntity? _clipboardItem;
  bool _isCutOperation = false;

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
    setState(() {
      _isLoading = true;
    });
    
    try {
      final dir = Directory(path);
      final List<FileSystemEntity> entities = await dir.list().toList();
      
      // Sort: directories first, then files, both alphabetically
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      
      setState(() {
        _files = entities;
        _currentPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $e')),
        );
      }
    }
  }

  Future<void> _goToParentDirectory() async {
    final parentDir = Directory(_currentPath).parent;
    if (parentDir.path != _currentPath) {
      await _loadFiles(parentDir.path);
    }
  }

  void _showContextMenu(BuildContext context, FileSystemEntity entity, Offset position) {
    final isDirectory = entity is Directory;
    
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'properties',
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 12),
              Text('Properties'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'cut',
          child: Row(
            children: [
              Icon(Icons.content_cut, size: 20),
              SizedBox(width: 12),
              Text('Cut'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.content_copy, size: 20),
              SizedBox(width: 12),
              Text('Copy'),
            ],
          ),
        ),
        if (_clipboardItem != null)
          const PopupMenuItem<String>(
            value: 'paste',
            child: Row(
              children: [
                Icon(Icons.content_paste, size: 20),
                SizedBox(width: 12),
                Text('Paste Here'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.drive_file_rename_outline, size: 20),
              SizedBox(width: 12),
              Text('Rename'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'properties':
            _showPropertiesDialog(entity);
            break;
          case 'cut':
            setState(() {
              _clipboardItem = entity;
              _isCutOperation = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${_getEntityName(entity)} cut to clipboard')),
            );
            break;
          case 'copy':
            setState(() {
              _clipboardItem = entity;
              _isCutOperation = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${_getEntityName(entity)} copied to clipboard')),
            );
            break;
          case 'paste':
            _pasteItem(isDirectory ? entity.path : _currentPath);
            break;
          case 'rename':
            _showRenameDialog(entity);
            break;
          case 'delete':
            _confirmDelete(entity);
            break;
        }
      }
    });
  }

  Future<void> _pasteItem(String destinationPath) async {
    if (_clipboardItem == null) return;
    
    try {
      final fileName = _getEntityName(_clipboardItem!);
      final newPath = '$destinationPath/$fileName';
      
      if (_isCutOperation) {
        // Move operation
        await _clipboardItem!.rename(newPath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName moved successfully')),
        );
      } else {
        // Copy operation
        if (_clipboardItem is File) {
          await File(_clipboardItem!.path).copy(newPath);
        } else if (_clipboardItem is Directory) {
          await _copyDirectory(Directory(_clipboardItem!.path), Directory(newPath));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName copied successfully')),
        );
      }
      
      setState(() {
        _clipboardItem = null;
        _isCutOperation = false;
      });
      
      await _loadFiles(_currentPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory = Directory('${destination.path}/${entity.path.split('/').last}');
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        await entity.copy('${destination.path}/${entity.path.split('/').last}');
      }
    }
  }

  void _showPropertiesDialog(FileSystemEntity entity) {
    final isDirectory = entity is Directory;
    final name = _getEntityName(entity);
    
    FileStat stat = FileStat.statSync(entity.path);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isDirectory ? Icons.folder : Icons.insert_drive_file),
            const SizedBox(width: 8),
            Expanded(child: Text(name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPropertyRow('Type', isDirectory ? 'Folder' : 'File'),
              _buildPropertyRow('Location', entity.parent.path),
              if (!isDirectory)
                _buildPropertyRow('Size', _formatFileSize(stat.size)),
              _buildPropertyRow('Modified', _formatDate(stat.modified)),
              _buildPropertyRow('Accessed', _formatDate(stat.accessed)),
              _buildPropertyRow('Changed', _formatDate(stat.changed)),
              const Divider(),
              _buildPropertyRow('Path', entity.path),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(FileSystemEntity entity) {
    final controller = TextEditingController(text: _getEntityName(entity));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              
              try {
                final newPath = '${entity.parent.path}/$newName';
                await entity.rename(newPath);
                Navigator.pop(context);
                await _loadFiles(_currentPath);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Renamed successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(FileSystemEntity entity) {
    final name = _getEntityName(entity);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await entity.delete(recursive: true);
                Navigator.pop(context);
                await _loadFiles(_currentPath);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name deleted')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getEntityName(FileSystemEntity entity) {
    return entity.path.split('/').last;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
                            () async {
                              setState(() => _showFileBrowser = true);
                              await _loadFiles(_currentPath);
                            },
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selected: ${result.files.first.name}')),
            );
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
            const Text('File Browser', style: TextStyle(fontSize: 18)),
            Text(
              _currentPath.length > 40 
                ? '...${_currentPath.substring(_currentPath.length - 40)}'
                : _currentPath,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _showFileBrowser = false;
            _files.clear();
          }),
        ),
        actions: [
          if (_currentPath.isNotEmpty && Directory(_currentPath).parent.path != _currentPath)
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              tooltip: 'Parent Directory',
              onPressed: _goToParentDirectory,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _loadFiles(_currentPath),
          ),
          if (_clipboardItem != null)
            IconButton(
              icon: Icon(
                _isCutOperation ? Icons.content_cut : Icons.content_copy,
                color: Colors.orange,
              ),
              tooltip: 'Paste',
              onPressed: () => _pasteItem(_currentPath),
            ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _files.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'This folder is empty',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                final isDirectory = file is Directory;
                final fileName = _getEntityName(file);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      isDirectory ? Icons.folder : _getFileIcon(fileName),
                      color: isDirectory ? const Color(0xFF1976D2) : Colors.grey,
                      size: 32,
                    ),
                    title: Text(fileName),
                    subtitle: !isDirectory
                        ? FutureBuilder<FileStat>(
                            future: file.stat(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Text(
                                  '${_formatFileSize(snapshot.data!.size)} • ${_formatDate(snapshot.data!.modified)}',
                                  style: const TextStyle(fontSize: 12),
                                );
                              }
                              return const Text('Loading...');
                            },
                          )
                        : const Text('Folder'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDirectory)
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onPressed: () {
                            final RenderBox box = context.findRenderObject() as RenderBox;
                            final Offset position = box.localToGlobal(Offset.zero);
                            _showContextMenu(context, file, position);
                          },
                        ),
                      ],
                    ),
                    onTap: isDirectory ? () => _loadFiles(file.path) : null,
                    onLongPress: () {
                      final RenderBox box = context.findRenderObject() as RenderBox;
                      final Offset position = box.localToGlobal(Offset.zero);
                      _showContextMenu(context, file, position);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewFolderDialog(),
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.create_new_folder, color: Colors.white),
      ),
    );
  }

  void _showNewFolderDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              
              try {
                final newDir = Directory('$_currentPath/$name');
                await newDir.create();
                Navigator.pop(context);
                await _loadFiles(_currentPath);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Folder "$name" created')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audio_file;
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}