import 'package:flutter/material.dart';

// Data Models
class RecentFile {
  final String name;
  final String size;
  final String date;
  final IconData icon;
  final Color iconColor;

  RecentFile({
    required this.name,
    required this.size,
    required this.date,
    required this.icon,
    required this.iconColor,
  });
}

class AnalyticsItem {
  final String name;
  final String size;
  final String date;
  final String description;
  final String status;
  final IconData icon;

  AnalyticsItem({
    required this.name,
    required this.size,
    required this.date,
    required this.description,
    required this.status,
    required this.icon,
  });
}

class Activity {
  final String title;
  final String time;
  final IconData icon;
  final Color iconColor;

  Activity({
    required this.title,
    required this.time,
    required this.icon,
    required this.iconColor,
  });
}

// Sample Data
final List<RecentFile> recentFiles = [
  RecentFile(
    name: 'Important Project Report.pdf',
    size: '3.2 MB',
    date: 'Oct 28, 2023',
    icon: Icons.picture_as_pdf,
    iconColor: const Color(0xFF1976D2),
  ),
  RecentFile(
    name: 'Vacation Photos 2023.jpg',
    size: '12.5 MB',
    date: 'Oct 27, 2023',
    icon: Icons.image,
    iconColor: const Color(0xFF4CAF50),
  ),
  RecentFile(
    name: 'Favourite Playlist.mp3',
    size: '5.1 MB',
    date: 'Oct 25, 2023',
    icon: Icons.audio_file,
    iconColor: const Color(0xFF9C27B0),
  ),
  RecentFile(
    name: 'Family Event.mp4',
    size: '21.8 MB',
    date: 'Oct 24, 2023',
    icon: Icons.video_file,
    iconColor: const Color(0xFFF44336),
  ),
  RecentFile(
    name: 'Meeting Notes.docx',
    size: '1.1 MB',
    date: 'Oct 23, 2023',
    icon: Icons.description,
    iconColor: const Color(0xFF1976D2),
  ),
  RecentFile(
    name: 'Work Documents',
    size: '50 files',
    date: '',
    icon: Icons.folder,
    iconColor: const Color(0xFFFF9800),
  ),
];

final List<AnalyticsItem> suspiciousFiles = [
  AnalyticsItem(
    name: 'invoice_unknown_sender.pdf',
    size: '1.2 MB',
    date: '2023-11-20',
    description: 'Unverified Source',
    status: 'Suspicious',
    icon: Icons.description,
  ),
  AnalyticsItem(
    name: 'sketchy_installer.exe',
    size: '5.8 MB',
    date: '2023-11-18',
    description: 'Uncommon Extension',
    status: 'Suspicious',
    icon: Icons.description,
  ),
];

final List<AnalyticsItem> duplicateFiles = [
  AnalyticsItem(
    name: 'IMG_4567.jpg',
    size: '3.1 MB',
    date: '2023-10-15',
    description: 'Duplicate of IMG_4567_copy.jpg',
    status: 'Duplicate',
    icon: Icons.image,
  ),
  AnalyticsItem(
    name: 'My_Project_Final_v2.docx',
    size: '2.5 MB',
    date: '2023-09-01',
    description: 'Duplicate of My_Project_Final.docx',
    status: 'Duplicate',
    icon: Icons.description,
  ),
];

final List<AnalyticsItem> largeFiles = [
  AnalyticsItem(
    name: 'Holiday_Video_2023.mp4',
    size: '1.5 GB',
    date: '2023-12-05',
    description: 'High-Resolution',
    status: 'Large',
    icon: Icons.video_file,
  ),
  AnalyticsItem(
    name: 'System_Backup_Oct.zip',
    size: '800 MB',
    date: '2023-10-28',
    description: 'Old Backup',
    status: 'Large',
    icon: Icons.archive,
  ),
];

final List<AnalyticsItem> geoTaggedMedia = [
  AnalyticsItem(
    name: 'Trip_Hawaii_Sunset.jpg',
    size: '4.2 MB',
    date: '2023-07-30',
    description: 'Location: Hawaii',
    status: 'Geo-tagged',
    icon: Icons.image,
  ),
];

final List<AnalyticsItem> documentsByFormat = [
  AnalyticsItem(
    name: 'Annual_Report_2023.pdf',
    size: '4.5 MB',
    date: '2023-12-10',
    description: 'PDF',
    status: '',
    icon: Icons.picture_as_pdf,
  ),
  AnalyticsItem(
    name: 'Project_Proposal.docx',
    size: '1.1 MB',
    date: '2023-11-25',
    description: 'DOCX',
    status: '',
    icon: Icons.description,
  ),
];

final List<Activity> activities = [
  Activity(
    title: 'Suspicious file detected in Downloads folder.',
    time: 'Just now',
    icon: Icons.warning,
    iconColor: const Color(0xFFF44336),
  ),
  Activity(
    title: 'Antivirus database updated successfully.',
    time: '2 hours ago',
    icon: Icons.security,
    iconColor: const Color(0xFF4CAF50),
  ),
  Activity(
    title: 'Unused apps consuming too much battery.',
    time: 'Yesterday',
    icon: Icons.warning,
    iconColor: const Color(0xFFFF9800),
  ),
];