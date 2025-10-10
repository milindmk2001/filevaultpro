import 'dart:io';
import 'package:flutter/material.dart';

enum FileSystemNodeType {
  virtualRoot,
  directory,
  file,
}

enum RootCategory {
  onMyIPhone,
  iCloudDrive,
  media,
  appData,
}

class FileSystemNode {
  final String name;
  final String? path;
  final FileSystemNodeType type;
  final IconData icon;
  final Color iconColor;
  final RootCategory? category;
  final List<FileSystemNode> children;
  final bool isExpanded;
  final FileSystemEntity? entity;
  final int? fileSize;
  final DateTime? modifiedDate;

  FileSystemNode({
    required this.name,
    this.path,
    required this.type,
    required this.icon,
    required this.iconColor,
    this.category,
    this.children = const [],
    this.isExpanded = false,
    this.entity,
    this.fileSize,
    this.modifiedDate,
  });

  FileSystemNode copyWith({
    String? name,
    String? path,
    FileSystemNodeType? type,
    IconData? icon,
    Color? iconColor,
    RootCategory? category,
    List<FileSystemNode>? children,
    bool? isExpanded,
    FileSystemEntity? entity,
    int? fileSize,
    DateTime? modifiedDate,
  }) {
    return FileSystemNode(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      category: category ?? this.category,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
      entity: entity ?? this.entity,
      fileSize: fileSize ?? this.fileSize,
      modifiedDate: modifiedDate ?? this.modifiedDate,
    );
  }

  bool get hasChildren => children.isNotEmpty || type == FileSystemNodeType.directory;
  bool get isDirectory => type == FileSystemNodeType.directory || type == FileSystemNodeType.virtualRoot;
}

class BreadcrumbItem {
  final String name;
  final String? path;
  final int depth;

  BreadcrumbItem({
    required this.name,
    this.path,
    required this.depth,
  });
}

class FileSystemNodeFactory {
  static FileSystemNode createVirtualRoot() {
    return FileSystemNode(
      name: 'Files',
      type: FileSystemNodeType.virtualRoot,
      icon: Icons.folder,
      iconColor: const Color(0xFF1976D2),
      children: [
        createOnMyIPhoneRoot(),
        createICloudDriveRoot(),
        createMediaRoot(),
        createAppDataRoot(),
      ],
    );
  }

  static FileSystemNode createOnMyIPhoneRoot() {
    return FileSystemNode(
      name: 'On My iPhone',
      type: FileSystemNodeType.directory,
      icon: Icons.phone_iphone,
      iconColor: const Color(0xFF4CAF50),
      category: RootCategory.onMyIPhone,
      children: [],
    );
  }

  static FileSystemNode createICloudDriveRoot() {
    return FileSystemNode(
      name: 'iCloud Drive',
      type: FileSystemNodeType.directory,
      icon: Icons.cloud,
      iconColor: const Color(0xFF2196F3),
      category: RootCategory.iCloudDrive,
      children: [],
    );
  }

  static FileSystemNode createMediaRoot() {
    return FileSystemNode(
      name: 'Media',
      type: FileSystemNodeType.directory,
      icon: Icons.photo_library,
      iconColor: const Color(0xFFFF9800),
      category: RootCategory.media,
      children: [
        FileSystemNode(
          name: 'Camera Roll',
          type: FileSystemNodeType.directory,
          icon: Icons.camera_alt,
          iconColor: const Color(0xFFE91E63),
        ),
        FileSystemNode(
          name: 'WhatsApp',
          type: FileSystemNodeType.directory,
          icon: Icons.chat,
          iconColor: const Color(0xFF25D366),
        ),
        FileSystemNode(
          name: 'Telegram',
          type: FileSystemNodeType.directory,
          icon: Icons.telegram,
          iconColor: const Color(0xFF0088cc),
        ),
        FileSystemNode(
          name: 'Recordings',
          type: FileSystemNodeType.directory,
          icon: Icons.mic,
          iconColor: const Color(0xFF9C27B0),
        ),
      ],
    );
  }

  static FileSystemNode createAppDataRoot() {
    return FileSystemNode(
      name: 'App Data',
      type: FileSystemNodeType.directory,
      icon: Icons.folder_special,
      iconColor: const Color(0xFF795548),
      category: RootCategory.appData,
      children: [
        FileSystemNode(
          name: 'Preferences',
          type: FileSystemNodeType.directory,
          icon: Icons.settings,
          iconColor: Colors.grey,
        ),
        FileSystemNode(
          name: 'Notes',
          type: FileSystemNodeType.directory,
          icon: Icons.note,
          iconColor: Colors.amber,
        ),
      ],
    );
  }
}