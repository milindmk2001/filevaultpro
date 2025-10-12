import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/file_system_models.dart';
import '../widgets/common_widgets.dart';
import '../services/compression_service.dart';

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
  bool _isImporting = false;
  
  FileSystemEntity? _clipboardItem;
  bool _isCutOperation = false;

  bool _selectionMode = false;
  final List<FileSystemNode> _selectedItems = [];

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
    await _loadOnMyIPhoneData();
  }

  Future<void> _loadOnMyIPhoneData() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final libDir = await getApplicationSupportDirectory();
      final tempDir = await getTemporaryDirectory();
      
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

  void _toggleSelectionMode(FileSystemNode node) {
    setState(() {
      if (_selectionMode) {
        if (_selectedItems.contains(node)) {
          _selectedItems.remove(node);
          if (_selectedItems.isEmpty) {
            _selectionMode = false;
          }
        } else {
          _selectedItems.add(node);
        }
      } else {
        _selectionMode = true;
        _selectedItems.clear();
        _selectedItems.add(node);
      }
    });
  }

  Future<void> _compressSelected() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select items to compress')),
      );
      return;
    }

    final zipName = await showDialog<String>(
      context: context,
      builder: (context) => _CompressDialog(
        itemCount: _selectedItems.length,
        items: _selectedItems.map((n) => n.entity!).toList(),
      ),
    );

    if (zipName == null || !mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Compressing...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Creating ${zipName.endsWith('.zip') ? zipName : '$zipName.zip'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );

      final paths = _selectedItems.map((item) => item.path!).toList();

      final zipPath = await CompressionService.compressFolders(
        paths: paths,
        outputName: zipName.endsWith('.zip') ? zipName : '$zipName.zip',
        preserveStructure: true,
      );

      if (mounted) Navigator.of(context).pop();

      final zipFile = File(zipPath);
      final zipStat = await zipFile.stat();
      final zipSize = CompressionService.formatBytes(zipStat.size);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Created ${path.basename(zipPath)} ($zipSize)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      setState(() {
        _selectedItems.clear();
        _selectionMode = false;
      });
      
      if (_currentNode?.path != null) {
        _navigateToNode(_currentNode!, addToBreadcrumb: false);
      }

    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Compression failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _smartFolderImport() async {
    try {
      setState(() => _isImporting = true);
      
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder_special, color: Color(0xFF4CAF50)),
              SizedBox(width: 8),
              Text('Smart Folder Import'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How it works:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('1️⃣ You\'ll select a folder from Files app'),
              SizedBox(height: 8),
              Text('2️⃣ App will automatically compress it'),
              SizedBox(height: 8),
              Text('3️⃣ Import with full folder structure'),
              SizedBox(height: 16),
              Text(
                '✨ Completely automatic!',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
              child: const Text('Select Folder'),
            ),
          ],
        ),
      );
      
      if (shouldContinue != true) {
        setState(() => _isImporting = false);
        return;
      }
      
      final directoryPath = await FilePicker.platform.getDirectoryPath();
      
      if (directoryPath != null) {
        await _compressAndImportFolder(directoryPath);
      } else {
        if (mounted) {
          _showFolderImportFallbackDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  void _showFolderImportFallbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📂 Smart Folder Import'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ iOS doesn\'t allow direct folder selection',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('📁 For Single Folder:'),
            SizedBox(height: 8),
            Text('① Open iOS Files App'),
            Text('② Long-press the folder'),
            Text('③ Tap "Compress"'),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),
            Text(
              '⭐ 📦 For Multiple Folders (BULK):',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
            ),
            SizedBox(height: 8),
            Text('① Open Files App'),
            Text('② Go to "On My iPhone"'),
            Text('③ Tap "Select" (top-right)'),
            Text('④ Select all folders you want'),
            Text('⑤ Tap share icon (bottom)'),
            Text('⑥ Tap "Compress"'),
            SizedBox(height: 12),
            Text(
              '✨ Creates one ZIP with all folders!',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '🎯 Then come back here:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Tap "Import ZIP" to import all folders!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _importZipFile();
            },
            child: const Text('Go to Import ZIP'),
          ),
        ],
      ),
    );
  }

  Future<void> _compressAndImportFolder(String folderPath) async {
    try {
      final folderName = folderPath.split('/').last;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Compressing "$folderName"...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      final archive = Archive();
      await _addDirectoryToArchive(archive, folderPath, folderPath);
      
      if (archive.files.isEmpty) {
        throw Exception('Folder is empty or inaccessible');
      }
      
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        throw Exception('Failed to compress folder');
      }
      
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Folder Compressed!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Compressed "$folderName"'),
              Text('${archive.files.length} items'),
              const SizedBox(height: 16),
              const Text('What would you like to do?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'extract'),
              child: const Text('Import Now (Extract)'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save as ZIP'),
            ),
          ],
        ),
      );
      
      if (action == 'extract') {
        final docDir = await getApplicationDocumentsDirectory();
        final targetDir = _currentNode?.path ?? docDir.path;
        
        int fileCount = 0;
        int folderCount = 0;
        
        for (final file in archive.files) {
          final filename = file.name;
          final filePath = '$targetDir/$filename';
          
          if (file.isFile) {
            final outFile = File(filePath);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
            fileCount++;
          } else {
            await Directory(filePath).create(recursive: true);
            folderCount++;
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported "$folderName"\n$fileCount files, $folderCount folders'),
              duration: const Duration(seconds: 3),
            ),
          );
          
          if (_currentNode?.path != null) {
            _navigateToNode(_currentNode!, addToBreadcrumb: false);
          }
        }
      } else if (action == 'save') {
        final docDir = await getApplicationDocumentsDirectory();
        final targetDir = _currentNode?.path ?? docDir.path;
        final zipPath = '$targetDir/$folderName.zip';
        await File(zipPath).writeAsBytes(zipData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved as $folderName.zip')),
          );
          
          if (_currentNode?.path != null) {
            _navigateToNode(_currentNode!, addToBreadcrumb: false);
          }
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

  Future<void> _importAndAutoOrganize() async {
    try {
      setState(() => _isImporting = true);
      
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        await _showOrganizeFolderDialog(result.files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _showOrganizeFolderDialog(List<PlatformFile> files) async {
    final controller = TextEditingController(
      text: 'Imported_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    final shouldOrganize = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Organize Files'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Found ${files.length} files'),
            const SizedBox(height: 16),
            const Text('Create a folder to organize them?'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Folder name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Import Without Folder'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create Folder'),
          ),
        ],
      ),
    );
    
    if (shouldOrganize == true) {
      final folderName = controller.text.trim();
      if (folderName.isNotEmpty) {
        await _importFilesIntoNewFolder(files, folderName);
        return;
      }
    }
    
    await _copyFilesToDocuments(files);
  }

  Future<void> _importFilesIntoNewFolder(
    List<PlatformFile> files,
    String folderName,
  ) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = _currentNode?.path ?? docDir.path;
      
      final newFolder = Directory('$targetDir/$folderName');
      await newFolder.create(recursive: true);
      
      int successCount = 0;
      int failCount = 0;
      
      for (final file in files) {
        if (file.path == null) {
          failCount++;
          continue;
        }
        
        try {
          final sourceFile = File(file.path!);
          final targetPath = '${newFolder.path}/${file.name}';
          
          if (await File(targetPath).exists()) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final nameParts = file.name.split('.');
            final ext = nameParts.length > 1 ? nameParts.last : '';
            final baseName = nameParts.length > 1 
                ? nameParts.sublist(0, nameParts.length - 1).join('.')
                : file.name;
            final uniqueName = ext.isNotEmpty 
                ? '${baseName}_$timestamp.$ext'
                : '${baseName}_$timestamp';
            await sourceFile.copy('${newFolder.path}/$uniqueName');
          } else {
            await sourceFile.copy(targetPath);
          }
          
          successCount++;
        } catch (e) {
          debugPrint('Error copying file ${file.name}: $e');
          failCount++;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Created "$folderName" with $successCount files'
              '${failCount > 0 ? ' ($failCount failed)' : ''}',
            ),
          ),
        );
        
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

  Future<void> _createZipFromMultipleFiles() async {
    try {
      setState(() => _isImporting = true);
      
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        await _compressFilesToZip(result.files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _compressFilesToZip(List<PlatformFile> files) async {
    try {
      final archive = Archive();
      
      for (final file in files) {
        if (file.path == null) continue;
        
        try {
          final fileBytes = await File(file.path!).readAsBytes();
          final archiveFile = ArchiveFile(file.name, fileBytes.length, fileBytes);
          archive.addFile(archiveFile);
        } catch (e) {
          debugPrint('Error adding ${file.name} to archive: $e');
        }
      }
      
      if (archive.files.isEmpty) {
        throw Exception('No files could be added to archive');
      }
      
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        throw Exception('Failed to create ZIP file');
      }
      
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ZIP Created'),
          content: Text('Compressed ${archive.files.length} files\n\nWhat do you want to do?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'extract'),
              child: const Text('Extract Here'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save ZIP File'),
            ),
          ],
        ),
      );
      
      if (action == 'extract') {
        final docDir = await getApplicationDocumentsDirectory();
        final targetDir = _currentNode?.path ?? docDir.path;
        
        int fileCount = 0;
        for (final file in archive.files) {
          if (file.isFile) {
            final filePath = '$targetDir/${file.name}';
            final outFile = File(filePath);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
            fileCount++;
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Extracted $fileCount files')),
          );
          
          if (_currentNode?.path != null) {
            _navigateToNode(_currentNode!, addToBreadcrumb: false);
          }
        }
      } else if (action == 'save') {
        final docDir = await getApplicationDocumentsDirectory();
        final targetDir = _currentNode?.path ?? docDir.path;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final zipPath = '$targetDir/archive_$timestamp.zip';
        await File(zipPath).writeAsBytes(zipData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ZIP file saved')),
          );
          
          if (_currentNode?.path != null) {
            _navigateToNode(_currentNode!, addToBreadcrumb: false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating ZIP: $e')),
        );
      }
    }
  }

  Future<void> _importZipFile() async {
    try {
      setState(() => _isImporting = true);
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: false,
      );
      
      if (result != null && result.files.single.path != null) {
        await _extractZipFile(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing ZIP: $e')),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _extractZipFile(String zipPath) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = _currentNode?.path ?? docDir.path;
      
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      int fileCount = 0;
      int folderCount = 0;
      
      for (final file in archive) {
        final filename = file.name;
        final filePath = '$targetDir/$filename';
        
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
          fileCount++;
        } else {
          await Directory(filePath).create(recursive: true);
          folderCount++;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Extracted: $fileCount files, $folderCount folders',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        
        if (_currentNode?.path != null) {
          _navigateToNode(_currentNode!, addToBreadcrumb: false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting ZIP: $e')),
        );
      }
    }
  }

  Future<void> _exportFolderAsZip(FileSystemNode node) async {
    if (!node.isDirectory || node.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Can only export folders')),
      );
      return;
    }
    
    try {
      setState(() => _isImporting = true);
      
      final archive = Archive();
      await _addDirectoryToArchive(archive, node.path!, node.path!);
      
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        throw Exception('Failed to create ZIP file');
      }
      
      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/${node.name}.zip';
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${node.name}.zip'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => _shareFile(zipPath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    String dirPath,
    String basePath,
  ) async {
    final dir = Directory(dirPath);
    final entities = await dir.list().toList();
    
    for (final entity in entities) {
      final relativePath = entity.path.substring(basePath.length + 1);
      
      if (entity is File) {
        final bytes = await entity.readAsBytes();
        final file = ArchiveFile(relativePath, bytes.length, bytes);
        archive.addFile(file);
      } else if (entity is Directory) {
        final file = ArchiveFile('$relativePath/', 0, []);
        archive.addFile(file);
        await _addDirectoryToArchive(archive, entity.path, basePath);
      }
    }
  }

  void _shareFile(String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality - use iOS Share Sheet')),
    );
  }

  Future<void> _importFiles() async {
    try {
      setState(() => _isImporting = true);
      
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        await _copyFilesToDocuments(result.files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing files: $e')),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _importFromPhotos() async {
    try {
      setState(() => _isImporting = true);
      
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        await _copyFilesToDocuments(result.files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing photos: $e')),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _importDocuments() async {
    try {
      setState(() => _isImporting = true);
      
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'],
        withData: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        await _copyFilesToDocuments(result.files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing documents: $e')),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _copyFilesToDocuments(List<PlatformFile> files) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = _currentNode?.path ?? docDir.path;
      
      int successCount = 0;
      int failCount = 0;
      
      for (final file in files) {
        if (file.path == null) {
          failCount++;
          continue;
        }
        
        try {
          final sourceFile = File(file.path!);
          final targetPath = '$targetDir/${file.name}';
          
          if (await File(targetPath).exists()) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final nameParts = file.name.split('.');
            final ext = nameParts.length > 1 ? nameParts.last : '';
            final baseName = nameParts.length > 1 
                ? nameParts.sublist(0, nameParts.length - 1).join('.')
                : file.name;
            final uniqueName = ext.isNotEmpty 
                ? '${baseName}_$timestamp.$ext'
                : '${baseName}_$timestamp';
            final uniquePath = '$targetDir/$uniqueName';
            await sourceFile.copy(uniquePath);
          } else {
            await sourceFile.copy(targetPath);
          }
          
          successCount++;
        } catch (e) {
          debugPrint('Error copying file ${file.name}: $e');
          failCount++;
        }
      }
      
      if (mounted) {
        String message = 'Imported $successCount file${successCount != 1 ? 's' : ''}';
        if (failCount > 0) {
          message += ' ($failCount failed)';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        
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

  Future<void> _navigateToNode(FileSystemNode node, {bool addToBreadcrumb = true}) async {
    if (node.type == FileSystemNodeType.file) {
      _showFilePreview(node);
      return;
    }
    
    FileSystemNode updatedNode = node;
    
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
      
      if (index == 0) {
        setState(() {
          _currentNode = _rootNode;
        });
      } else {
        _navigateBack();
      }
    }
  }

  void _navigateBack() {
    if (_breadcrumbs.length > 1) {
      setState(() {
        _breadcrumbs.removeLast();
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
          value: 'select',
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF4CAF50)),
              SizedBox(width: 12),
              Text('Select'),
            ],
          ),
        ),
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
        if (node.isDirectory)
          const PopupMenuItem<String>(
            value: 'export_zip',
            child: Row(
              children: [
                Icon(Icons.folder_zip, size: 20, color: Color(0xFF1976D2)),
                SizedBox(width: 12),
                Text('Export as ZIP'),
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
      case 'select':
        _toggleSelectionMode(node);
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
      case 'export_zip':
        _exportFolderAsZip(node);
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
                    if (_selectionMode && _selectedItems.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.archive, color: Color(0xFF4CAF50)),
                        tooltip: 'Compress Selected',
                        onPressed: _compressSelected,
                      ),
                    if (_selectionMode)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Cancel Selection',
                        onPressed: () {
                          setState(() {
                            _selectionMode = false;
                            _selectedItems.clear();
                          });
                        },
                      ),
                    IconButton(
                      icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                      onPressed: () => setState(() => _isGridView = !_isGridView),
                    ),
                  ],
                ),
              ),
            
            if (_selectionMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFE8F5E9),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedItems.length} item(s) selected',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: _compressSelected,
                      child: const Text('COMPRESS'),
                    ),
                  ],
                ),
              ),
            
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
            
            Expanded(
              child: _isImporting
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Processing files...'),
                        ],
                      ),
                    )
                  : _currentNode == null
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
    final nodes = _currentNode!.children;
    
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
    final isSelected = _selectedItems.contains(node);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? const Color(0xFFE8F5E9) : null,
      child: ListTile(
        leading: Stack(
          children: [
            Icon(node.icon, color: node.iconColor, size: 32),
            if (isSelected)
              const Positioned(
                right: 0,
                bottom: 0,
                child: Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
              ),
          ],
        ),
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
        onTap: () {
          if (_selectionMode) {
            _toggleSelectionMode(node);
          } else {
            _navigateToNode(node);
          }
        },
        onLongPress: () => _toggleSelectionMode(node),
      ),
    );
  }

  Widget _buildGridTile(FileSystemNode node) {
    final isSelected = _selectedItems.contains(node);
    
    return GestureDetector(
      onTap: () {
        if (_selectionMode) {
          _toggleSelectionMode(node);
        } else {
          _navigateToNode(node);
        }
      },
      onLongPress: () => _toggleSelectionMode(node),
      child: Card(
        color: isSelected ? const Color(0xFFE8F5E9) : null,
        child: Stack(
          children: [
            Column(
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
            if (isSelected)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Add to FilevaultPro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: const Text(
                        '🤖 AUTOMATIC (No Manual Work)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                    
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4CAF50).withOpacity(0.2),
                            const Color(0xFF8BC34A).withOpacity(0.2),
                          ],
                        ),
                        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.folder_special,
                          color: Color(0xFF4CAF50),
                          size: 36,
                        ),
                        title: const Text(
                          '📂 Smart Folder Import',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: const Text(
                          'SELECT FOLDER → Auto-compress → Import\n⭐ Best for importing complete folders!',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.stars, color: Color(0xFFFFB300), size: 28),
                        onTap: () {
                          Navigator.pop(context);
                          _smartFolderImport();
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Container(
                      color: const Color(0xFFE8F5E9),
                      child: ListTile(
                        leading: const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF4CAF50),
                          size: 32,
                        ),
                        title: const Text(
                          'Smart Import & Organize',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Select files → Auto-creates folder → Organizes',
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _importAndAutoOrganize();
                        },
                      ),
                    ),
                    
                    ListTile(
                      leading: const Icon(
                        Icons.compress,
                        color: Color(0xFF4CAF50),
                      ),
                      title: const Text('Auto-ZIP Multiple Files'),
                      subtitle: const Text(
                        'Select files → App compresses → Extract or save',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _createZipFromMultipleFiles();
                      },
                    ),
                    
                    const Divider(),
                    
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: const Text(
                        '📦 MANUAL (You Create ZIP First)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    
                    ListTile(
                      leading: const Icon(
                        Icons.folder_zip,
                        color: Color(0xFF1976D2),
                      ),
                      title: const Text('Import ZIP File'),
                      subtitle: const Text(
                        'If you already compressed folders externally',
                        style: TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _importZipFile();
                      },
                    ),
                    
                    const Divider(),
                    
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: const Text(
                        '📄 REGULAR IMPORT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    
                    ListTile(
                      leading: const Icon(Icons.file_upload, color: Color(0xFF1976D2)),
                      title: const Text('Import Any Files'),
                      subtitle: const Text('From Files app, iCloud Drive, etc.'),
                      onTap: () {
                        Navigator.pop(context);
                        _importFiles();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library, color: Color(0xFF4CAF50)),
                      title: const Text('Import Photos'),
                      subtitle: const Text('Images from anywhere'),
                      onTap: () {
                        Navigator.pop(context);
                        _importFromPhotos();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.description, color: Color(0xFFFF9800)),
                      title: const Text('Import Documents'),
                      subtitle: const Text('PDFs, Word, Excel, etc.'),
                      onTap: () {
                        Navigator.pop(context);
                        _importDocuments();
                      },
                    ),
                    
                    const Divider(),
                    
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: const Text(
                        '➕ CREATE NEW',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    
                    ListTile(
                      leading: const Icon(Icons.create_new_folder),
                      title: const Text('New Folder'),
                      subtitle: const Text('Create an empty folder'),
                      onTap: () {
                        Navigator.pop(context);
                        _showNewFolderDialog();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.note_add),
                      title: const Text('New Text File'),
                      onTap: () {
                        Navigator.pop(context);
                        _showNewFileDialog();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
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

class _CompressDialog extends StatefulWidget {
  final int itemCount;
  final List<FileSystemEntity> items;

  const _CompressDialog({
    required this.itemCount,
    required this.items,
  });

  @override
  State<_CompressDialog> createState() => _CompressDialogState();
}

class _CompressDialogState extends State<_CompressDialog> {
  late final TextEditingController _controller;
  bool _isCalculating = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: 'Archive_${DateTime.now().millisecondsSinceEpoch}',
    );
    _calculateStats();
  }

  Future<void> _calculateStats() async {
    try {
      final paths = widget.items.map((e) => e.path).toList();
      final stats = await CompressionService.getCompressionStats(paths);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isCalculating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCalculating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.archive, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Compress Selected'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildStatRow(
                  Icons.folder_outlined,
                  'Items:',
                  _isCalculating ? '...' : '${widget.itemCount} selected',
                ),
                if (_stats != null) ...[
                  const SizedBox(height: 4),
                  _buildStatRow(
                    Icons.insert_drive_file_outlined,
                    'Total Files:',
                    '${_stats!['totalItems']} files',
                  ),
                  const SizedBox(height: 4),
                  _buildStatRow(
                    Icons.storage,
                    'Total Size:',
                    _stats!['formattedSize'],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'ZIP File Name',
              suffixText: '.zip',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.file_present),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Folder structure will be preserved',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, _controller.text),
          icon: const Icon(Icons.check),
          label: const Text('Compress'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}