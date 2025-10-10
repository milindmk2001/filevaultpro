import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/file_system_models.dart';
import '../widgets/common_widgets.dart';

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  late FileSystemNode _rootNode;
  List<BreadcrumbItem> _breadcrumbs = [];
  FileSystemNode? _currentNode;
  bool _isGridView = false;
  
  // Clipboard for cut/copy/paste
  FileSystemEntity? _clipboardItem;
  bool _isCutOperation = false;

  @override
  void initState() {
    super.initState();
    _initializeFileSystem();
  }

  Future<void> _initializeFileSystem() async {
    setState(() {
      _rootNode = FileSystemNodeFactory.createVirtualRoot();
      _currentNode = _rootNode;
      _breadcrumbs = [
        BreadcrumbItem(name: 'Files', depth: 0),
      ];
    });
    
    // Load real file system data for accessible directories
    await _loadOnMyIPhoneData();
  }

  Future<void> _loadOnMyIPhoneData() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final libDir = await getApplicationSupportDirectory();
      final tempDir = await getTemporaryDirectory();
      
      // Find On My iPhone node and populate it
      final onMyIPhoneIndex = _rootNode.children.indexWhere(
        (node) => node.category == RootCategory.onMyIPhone
      );
      
      if (onMyIPhoneIndex != -1) {
        final children = [
          await _createNodeFromDirectory(docDir, 'Documents'),
          await _createNodeFromDirectory(libDir, 'App Support'),
          await _createNodeFromDirectory(tempDir, 'Temporary'),
        ];
        
        final updatedNode = _rootNode.children[onMyIPhoneIndex].copyWith(
          children: children,
          path: docDir.parent.path,
        );
        
        final updatedChildren = List<FileSystemNode>.from(_rootNode.children);
        updatedChildren[onMyIPhoneIndex] = updatedNode;
        
        setState(() {
          _rootNode = _rootNode.copyWith(children: updatedChildren);
        });
      }
    } catch (e) {
      debugPrint('Error loading file system: $e');
    }
  }

  Future<FileSystemNode> _createNodeFromDirectory(Directory dir, String displayName) async {
    return FileSystemNode(
      name: displayName,
      path: dir.path,
      type: FileSystemNodeType.directory,
      icon: Icons.folder,
      iconColor: const Color(0xFF1976D2),
      entity: dir,
    );
  }

  Future<List<FileSystemNode>> _loadDirectoryContents(String path) async {
    try {
      final dir = Directory(path);
      final entities = await dir.list().toList();
      
      final nodes = <FileSystemNode>[];
      
      for (final entity in entities) {
        final name = entity.path.split('/').last;
        final isDirectory = entity is Directory;
        
        FileStat? stat;
        try {
          stat = await entity.stat();
        } catch (e) {
          debugPrint('Error getting stat for $name: $e');
        }
        
        nodes.add(FileSystemNode(
          name: name,
          path: entity.path,
          type: isDirectory ? FileSystemNodeType.directory : FileSystemNodeType.file,
          icon: isDirectory ? Icons.folder : _getFileIcon(name),
          iconColor: isDirectory ? const Color(0xFF1976D2) : Colors.grey,
          entity: entity,
          fileSize: stat?.size,
          modifiedDate: stat?.modified,
        ));
      }
      
      // Sort: directories first, then files
      nodes.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      
      return nodes;
    } catch (e) {
      debugPrint('Error loading directory contents: $e');
      return [];
    }
  }

  Future<void> _navigateToNode(FileSystemNode node, {bool addToBreadcrumb = true}) async {
    if (node.type == FileSystemNodeType.file) {
      _showFilePreview(node);
      return;
    }
    
    FileSystemNode updatedNode = node;
    
    // If node has a real path and no children loaded yet, load them
    if (node.path != null && node.children.isEmpty && node.type == FileSystemNodeType.directory) {
      final children = await _loadDirectoryContents(node.path!);
      updatedNode = node.copyWith(children: children, isExpanded: true);
    } else {
      updatedNode = node.copyWith(isExpanded: !node.isExpanded);
    }
    
    setState(() {
      _currentNode = updatedNode;
      
      if (addToBreadcrumb) {
        _breadcrumbs.add(
          BreadcrumbItem(
            name: node.name,
            path: node.path,
            depth: _breadcrumbs.length,
          ),
        );
      }
    });
  }

  void _navigateToBreadcrumb(int index) {
    if (index < _breadcrumbs.length - 1) {
      setState(() {
        _breadcrumbs = _breadcrumbs.sublist(0, index + 1);
      });
      
      // Navigate back to root or parent
      if (index == 0) {
        setState(() {
          _currentNode = _rootNode;
        });
      } else {
        // Find the node at this breadcrumb level
        // This would require tracking the node path - simplified for now
        _navigateBack();
      }
    }
  }

  void _navigateBack() {
    if (_breadcrumbs.length > 1) {
      setState(() {
        _breadcrumbs.removeLast();
        // Simplified: go back to root if at depth 1
        if (_breadcrumbs.length == 1) {
          _currentNode = _rootNode;
        }
      });
    }
  }

  void _showFilePreview(FileSystemNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(node.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_getFileIcon(node.name), size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Type: ${_getFileExtension(node.name)}'),
            if (node.fileSize != null)
              Text('Size: ${_formatFileSize(node.fileSize!)}'),
            if (node.modifiedDate != null)
              Text('Modified: ${_formatDate(node.modifiedDate!)}'),
            if (node.path != null)
              Text('Path: ${node.path}', style: const TextStyle(fontSize: 12)),
          ],
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

  void _showContextMenu(BuildContext context, FileSystemNode node, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: <PopupMenuEntry<String>>[
        if (!node.isDirectory)
          const PopupMenuItem<String>(
            value: 'open',
            child: Row(
              children: [
                Icon(Icons.open_in_new, size: 20),
                SizedBox(width: 12),
                Text('Open'),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'info',
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 12),
              Text('Info'),
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
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.content_copy, size: 20),
              SizedBox(width: 12),
              Text('Copy'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'move',
          child: Row(
            children: [
              Icon(Icons.drive_file_move, size: 20),
              SizedBox(width: 12),
              Text('Move to'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 20),
              SizedBox(width: 12),
              Text('Share'),
            ],
          ),
        ),
        const PopupMenuDivider(),
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
      if (value != null && mounted) {
        _handleContextMenuAction(value, node);
      }
    });
  }

  void _handleContextMenuAction(String action, FileSystemNode node) {
    switch (action) {
      case 'open':
        _showFilePreview(node);
        break;
      case 'info':
        _showFileInfo(node);
        break;
      case 'rename':
        _showRenameDialog(node);
        break;
      case 'copy':
        _copyNode(node);
        break;
      case 'move':
        _showMoveDialog(node);
        break;
      case 'share':
        _shareNode(node);
        break;
      case 'delete':
        _confirmDelete(node);
        break;
    }
  }

  void _showFileInfo(FileSystemNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(node.icon, color: node.iconColor),
            const SizedBox(width: 8),
            Expanded(child: Text(node.name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Type', node.isDirectory ? 'Folder' : 'File'),
              if (node.path != null)
                _buildInfoRow('Location', node.path!),
              if (node.fileSize != null)
                _buildInfoRow('Size', _formatFileSize(node.fileSize!)),
              if (node.modifiedDate != null)
                _buildInfoRow('Modified', _formatDate(node.modifiedDate!)),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(FileSystemNode node) {
    final controller = TextEditingController(text: node.name);
    
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
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && node.entity != null) {
                _renameNode(node, newName);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameNode(FileSystemNode node, String newName) async {
    if (node.entity == null) return;
    
    try {
      final newPath = '${node.entity!.parent.path}/$newName';
      await node.entity!.rename(newPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Renamed successfully')),
        );
        // Refresh current directory
        if (_currentNode?.path != null) {
          _navigateToNode(_currentNode!, addToBreadcrumb: false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _copyNode(FileSystemNode node) {
    setState(() {
      _clipboardItem = node.entity;
      _isCutOperation = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${node.name} copied to clipboard')),
      );
    }
  }

  void _showMoveDialog(FileSystemNode node) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Move functionality - select destination')),
    );
  }

  void _shareNode(FileSystemNode node) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality would use iOS Share Sheet')),
    );
  }

  void _confirmDelete(FileSystemNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete "${node.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteNode(node);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNode(FileSystemNode node) async {
    if (node.entity == null) return;
    
    try {
      await node.entity!.delete(recursive: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${node.name} deleted')),
        );
        // Refresh current directory
        if (_currentNode?.path != null) {
          _navigateToNode(_currentNode!, addToBreadcrumb: false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'heic': return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi': return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'm4a': return Icons.audio_file;
      case 'doc':
      case 'docx':
      case 'txt': return Icons.description;
      case 'zip':
      case 'rar': return Icons.archive;
      default: return Icons.insert_drive_file;
    }
  }

  String _getFileExtension(String fileName) {
    return fileName.split('.').last.toUpperCase();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            CommonWidgets.buildStatusBar(context, 'File Explorer'),
            
            // Breadcrumb Navigation
            if (_breadcrumbs.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    if (_breadcrumbs.length > 1)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _navigateBack,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _breadcrumbs.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final isLast = index == _breadcrumbs.length - 1;
                            
                            return Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _navigateToBreadcrumb(index),
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      color: isLast ? Colors.black : const Color(0xFF1976D2),
                                      fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (!isLast)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                      onPressed: () => setState(() => _isGridView = !_isGridView),
                    ),
                  ],
                ),
              ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search files and folders...',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            // File/Folder List or Grid
            Expanded(
              child: _currentNode == null
                  ? const Center(child: CircularProgressIndicator())
                  : _isGridView
                      ? _buildGridView()
                      : _buildListView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateMenu,
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildListView() {
    final nodes = _currentNode!.type == FileSystemNodeType.virtualRoot
        ? _currentNode!.children
        : _currentNode!.children;
    
    if (nodes.isEmpty && _currentNode!.type != FileSystemNodeType.virtualRoot) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('This folder is empty', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return _buildListTile(node);
      },
    );
  }

  Widget _buildGridView() {
    final nodes = _currentNode!.children;
    
    if (nodes.isEmpty) {
      return const Center(child: Text('No items'));
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return _buildGridTile(node);
      },
    );
  }

  Widget _buildListTile(FileSystemNode node) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(node.icon, color: node.iconColor, size: 32),
        title: Text(node.name),
        subtitle: node.fileSize != null
            ? Text('${_formatFileSize(node.fileSize!)} • ${_formatDate(node.modifiedDate!)}')
            : node.isDirectory
                ? const Text('Folder')
                : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (node.hasChildren && node.type != FileSystemNodeType.file)
              const Icon(Icons.chevron_right, color: Colors.grey),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final Offset position = box.localToGlobal(Offset.zero);
                _showContextMenu(context, node, position);
              },
            ),
          ],
        ),
        onTap: () => _navigateToNode(node),
        onLongPress: () {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final Offset position = box.localToGlobal(Offset.zero);
          _showContextMenu(context, node, position);
        },
      ),
    );
  }

  Widget _buildGridTile(FileSystemNode node) {
    return GestureDetector(
      onTap: () => _navigateToNode(node),
      onLongPress: () {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset position = box.localToGlobal(Offset.zero);
        _showContextMenu(context, node, position);
      },
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(node.icon, size: 48, color: node.iconColor),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                node.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('New Folder'),
              onTap: () {
                Navigator.pop(context);
                _showNewFolderDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text('New File'),
              onTap: () {
                Navigator.pop(context);
                _showNewFileDialog();
              },
            ),
          ],
        ),
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
              if (name.isNotEmpty && _currentNode?.path != null) {
                await _createNewFolder(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewFolder(String name) async {
    if (_currentNode?.path == null) return;
    
    try {
      final newDir = Directory('${_currentNode!.path}/$name');
      await newDir.create();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder "$name" created')),
        );
        // Refresh current directory
        _navigateToNode(_currentNode!, addToBreadcrumb: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showNewFileDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New file creation - coming soon')),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}