import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/storage_analysis_service.dart';
import '../services/metadata_service.dart';

/// Enhanced Dashboard Screen with Tabs
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  // Data
  Map<String, dynamic> _deviceStorage = {};
  List<StorageBreakdownItem> _typeData = [];
  List<StorageBreakdownItem> _sourceData = [];
  List<StorageBreakdownItem> _sizeData = [];
  List<StorageBreakdownItem> _ageData = [];
  List<FileMetadata> _recentFiles = [];
  int _totalFiles = 0;
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Load all data in parallel
      final results = await Future.wait([
        StorageAnalysisService.getDeviceStorage(),
        StorageAnalysisService.calculateByType(),
        StorageAnalysisService.calculateBySource(),
        StorageAnalysisService.calculateBySize(),
        StorageAnalysisService.calculateByAge(),
        MetadataService.loadAllMetadata(),
      ]);

      final allMetadata = results[5] as List<FileMetadata>;
      allMetadata.sort((a, b) => b.importedAt.compareTo(a.importedAt));

      setState(() {
        _deviceStorage = results[0] as Map<String, dynamic>;
        _typeData = results[1] as List<StorageBreakdownItem>;
        _sourceData = results[2] as List<StorageBreakdownItem>;
        _sizeData = results[3] as List<StorageBreakdownItem>;
        _ageData = results[4] as List<StorageBreakdownItem>;
        _recentFiles = allMetadata.take(5).toList();
        _totalFiles = allMetadata.length;
        _totalSize = allMetadata.fold<int>(0, (sum, m) => sum + m.size);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load dashboard: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Color _getColorFromString(String colorString) {
    return Color(int.parse(colorString));
  }

  void _showDrillDown(StorageBreakdownItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getColorFromString(item.color).withOpacity(0.1),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Text(
                      item.icon,
                      style: TextStyle(fontSize: 32),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${item.fileCount} files • ${_formatBytes(item.totalSize)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Files list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: item.files.length,
                  itemBuilder: (context, index) {
                    final file = item.files[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          Icons.folder_zip,
                          color: _getColorFromString(item.color),
                          size: 40,
                        ),
                        title: Text(
                          file.fileName,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text('${_formatBytes(file.size)} • ${_getTimeAgo(file.importedAt)}'),
                            if (file.detailedSource != file.source)
                              Text(
                                file.detailedSource,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Navigate to file details
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text('Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: _totalFiles == 0
                  ? _buildEmptyState()
                  : _buildDashboard(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard, size: 80, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text(
            'No files imported yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Use Explorer to import folders',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Overview Card
        _buildOverviewCard(),
        
        SizedBox(height: 16),
        
        // Storage Health
        _buildStorageHealthCard(),
        
        SizedBox(height: 24),
        
        // Storage Breakdown with Tabs
        Text(
          'Storage Breakdown',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        SizedBox(height: 12),
        
        _buildStorageBreakdownSection(),
        
        SizedBox(height: 24),
        
        // Recent Activity
        if (_recentFiles.isNotEmpty) ...[
          Text(
            '📈 Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          ..._recentFiles.map((file) => _buildRecentFileCard(file)).toList(),
        ],
        
        SizedBox(height: 24),
        
        // Quick Actions (Placeholders)
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2196F3).withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Files',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '$_totalFiles',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.storage, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                _formatBytes(_totalSize),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageHealthCard() {
    final percentAvailable = _deviceStorage['percentAvailable'] ?? 100;
    final appUsedSpace = _deviceStorage['appUsedSpace'] ?? 0;
    final availableSpace = _deviceStorage['availableSpace'] ?? 0;
    
    String status;
    Color statusColor;
    String message;
    
    if (percentAvailable > 50) {
      status = 'Excellent';
      statusColor = Color(0xFF4CAF50);
      message = 'Your device has plenty of storage space.';
    } else if (percentAvailable > 30) {
      status = 'Good';
      statusColor = Color(0xFF2196F3);
      message = 'Storage is healthy. Continue monitoring.';
    } else if (percentAvailable > 10) {
      status = 'Warning';
      statusColor = Color(0xFFFF9800);
      message = '⚠️ Storage getting low. Consider cleanup.';
    } else {
      status = 'Critical';
      statusColor = Color(0xFFF44336);
      message = '🚨 Critical: Very low storage! Immediate action required.';
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.storage, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Storage Health',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _formatBytes(availableSpace),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Usage',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _formatBytes(appUsedSpace),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageBreakdownSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Color(0xFF2196F3),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF2196F3),
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'Type'),
                Tab(text: 'Source'),
                Tab(text: 'Size'),
                Tab(text: 'Age'),
              ],
            ),
          ),
          
          // Tab Content
          SizedBox(
            height: 450,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBreakdownView(_typeData),
                _buildBreakdownView(_sourceData),
                _buildBreakdownView(_sizeData),
                _buildBreakdownView(_ageData),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownView(List<StorageBreakdownItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final total = items.fold<int>(0, (sum, item) => sum + item.totalSize);

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Pie Chart
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: items.map((item) {
                final percentage = (item.totalSize / total * 100);
                return PieChartSectionData(
                  color: _getColorFromString(item.color),
                  value: item.totalSize.toDouble(),
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        
        SizedBox(height: 24),
        
        // Legend with tap to drill down
        ...items.map((item) {
          final percentage = (item.totalSize / total * 100);
          return InkWell(
            onTap: () => _showDrillDown(item),
            child: Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getColorFromString(item.color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getColorFromString(item.color).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    item.icon,
                    style: TextStyle(fontSize: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${item.fileCount} files • ${_formatBytes(item.totalSize)} • ${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildRecentFileCard(FileMetadata file) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(0xFF2196F3).withOpacity(0.1),
          child: Text(
            file.source == 'Camera' ? '📸' :
            file.source == 'Messenger Apps' ? '💬' :
            file.source == 'Downloads' ? '📥' :
            file.source == 'Computer' ? '💻' :
            file.source == 'Cloud' ? '☁️' : '📁',
            style: TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          file.fileName,
          style: TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${file.detailedSource} • ${_getTimeAgo(file.importedAt)}',
          style: TextStyle(fontSize: 12),
        ),
        trailing: Text(
          _formatBytes(file.size),
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Implement Quick Scan
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Quick Scan - Coming Soon!')),
            );
          },
          icon: Icon(Icons.play_arrow, color: Colors.white),
          label: Text('Run Quick Scan', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1976D2),
            minimumSize: Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Implement Free Up Space
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Free Up Space - Coming Soon!')),
            );
          },
          icon: Icon(Icons.cleaning_services),
          label: Text('Free Up Space'),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
