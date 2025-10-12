// ========================================
// ADD THIS IMPORT AT THE TOP
// ========================================
import 'package:file_vault_pro/services/compression_service.dart';

// ========================================
// ADD THESE METHODS TO YOUR _FileExplorerScreenState CLASS
// ========================================

/// Compress selected items into a ZIP file
Future<void> _compressSelected() async {
  if (_selectedItems.isEmpty) {
    _showSnackBar('Please select items to compress', isError: true);
    return;
  }

  // Show compression dialog
  final zipName = await showDialog<String>(
    context: context,
    builder: (context) => _CompressDialog(
      itemCount: _selectedItems.length,
      items: _selectedItems,
    ),
  );

  if (zipName == null || !mounted) return;

  try {
    // Show loading dialog
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

    // Get full paths of selected items
    final paths = _selectedItems.map((item) => item.path).toList();

    // Compress using native code
    final zipPath = await CompressionService.compressFolders(
      paths: paths,
      outputName: zipName.endsWith('.zip') ? zipName : '$zipName.zip',
      preserveStructure: true,
    );

    // Close loading dialog
    if (mounted) Navigator.of(context).pop();

    // Show success
    final zipFile = File(zipPath);
    final zipStat = await zipFile.stat();
    final zipSize = CompressionService.formatBytes(zipStat.size);

    if (mounted) {
      _showSnackBar(
        '✅ Created ${path.basename(zipPath)} ($zipSize)',
        isError: false,
      );
    }

    // Refresh and clear selection
    setState(() {
      _selectedItems.clear();
      _selectionMode = false;
    });
    
    await _loadItems();

  } catch (e) {
    // Close loading dialog
    if (mounted) Navigator.of(context).pop();
    
    // Show error
    if (mounted) {
      _showSnackBar('❌ Compression failed: $e', isError: true);
    }
  }
}

/// Show snackbar helper
void _showSnackBar(String message, {required bool isError}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: const Duration(seconds: 3),
    ),
  );
}

// ========================================
// UPDATE YOUR FLOATING ACTION BUTTON / APP BAR
// Add a compress button when items are selected
// ========================================

// Example: Add to AppBar actions when in selection mode
AppBar(
  title: _selectionMode
      ? Text('${_selectedItems.length} selected')
      : const Text('File Explorer'),
  actions: [
    if (_selectionMode) ...[
      IconButton(
        icon: const Icon(Icons.archive),
        tooltip: 'Compress Selected',
        onPressed: _compressSelected,
      ),
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          setState(() {
            _selectedItems.clear();
            _selectionMode = false;
          });
        },
      ),
    ] else ...[
      // Your existing action buttons
    ],
  ],
)

// OR add a FloatingActionButton when items are selected:
floatingActionButton: _selectionMode && _selectedItems.isNotEmpty
    ? FloatingActionButton.extended(
        onPressed: _compressSelected,
        icon: const Icon(Icons.archive),
        label: Text('Compress (${_selectedItems.length})'),
        backgroundColor: Colors.deepPurple,
      )
    : null, // Your existing FAB

// ========================================
// ADD THIS DIALOG WIDGET AT THE BOTTOM OF THE FILE
// (Outside the _FileExplorerScreenState class)
// ========================================

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
          // Stats section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
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
          
          // File name input
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
          
          // Info message
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Folder structure will be preserved',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
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
        Icon(icon, size: 16, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}