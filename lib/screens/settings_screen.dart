import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _automaticBackup = true;
  bool _backupOnMobileData = false;
  String _networkPreference = 'Wi-Fi Only';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            CommonWidgets.buildStatusBar(context, 'Backup Settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('Backup Features'),
                  const SizedBox(height: 16),
                  
                  _buildToggleItem(
                    'Automatic Backup',
                    'Automatically back up your files in the background when connected to power.',
                    _automaticBackup,
                    (value) => setState(() => _automaticBackup = value),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildToggleItem(
                    'Backup on Mobile Data',
                    'Allow backups to proceed using your mobile data connection when Wi-Fi is unavailable. This may incur data charges.',
                    _backupOnMobileData,
                    (value) => setState(() => _backupOnMobileData = value),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Backup Schedule'),
                  const SizedBox(height: 16),
                  
                  _buildMenuItem('Frequency', 'Daily'),
                  const SizedBox(height: 12),
                  _buildMenuItem('Time', '02:00 AM'),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Network Preferences'),
                  const SizedBox(height: 16),
                  
                  _buildRadioOption('Wi-Fi Only', _networkPreference == 'Wi-Fi Only'),
                  _buildRadioOption('Wi-Fi & Mobile Data', _networkPreference == 'Wi-Fi & Mobile Data'),
                  _buildRadioOption('Ask Every Time', _networkPreference == 'Ask Every Time'),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Manage Backup Content'),
                  const SizedBox(height: 16),
                  
                  _buildMenuItem('Select Files and Folders', '500 GB'),
                  const SizedBox(height: 12),
                  _buildMenuItem('Exclude File Types', '0 excluded'),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('Advanced Settings'),
                  const SizedBox(height: 16),
                  
                  _buildMenuItem('Encryption & Security', 'Default'),
                  const SizedBox(height: 12),
                  _buildMenuItem('Backup Destination', 'Cloud Storage'),
                  const SizedBox(height: 12),
                  _buildMenuItem('Version History', '30 days'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildToggleItem(
    String title,
    String description,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1976D2),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, String value) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String title, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _networkPreference = title),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Radio<String>(
              value: title,
              groupValue: _networkPreference,
              onChanged: (value) => setState(() => _networkPreference = value!),
              activeColor: const Color(0xFF1976D2),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}