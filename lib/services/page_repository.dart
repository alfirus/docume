import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/doc_page.dart';
import '../models/workspace_config.dart';
import 'google_drive_service.dart';
import 'google_sign_in_factory.dart';
import 'google_drive_sync_queue_service.dart';
import 'icloud_service.dart';
import 'synology_drive_service.dart';

class PageRepository {
  PageRepository({
    required WorkspaceConfig workspaceConfig,
    GoogleDriveSyncQueueService? googleDriveSyncQueueService,
    ICloudService? iCloudService,
    SynologyDriveService? synologyDriveService,
  }) : _workspaceConfig = workspaceConfig,
       _googleDriveSyncQueueService =
           googleDriveSyncQueueService ??
           GoogleDriveSyncQueueService(namespace: workspaceConfig.namespace),
       _iCloudService = iCloudService ?? ICloudService(),
       _synologyDriveService = synologyDriveService ?? SynologyDriveService(),
       _namespace = workspaceConfig.namespace;

  final WorkspaceConfig _workspaceConfig;
  final GoogleDriveSyncQueueService _googleDriveSyncQueueService;
  final ICloudService _iCloudService;
  final SynologyDriveService _synologyDriveService;
  final String _namespace;

  String get _storageKey {
    final encoded = base64Url.encode(utf8.encode(_namespace));
    return 'docume_pages_$encoded';
  }

  Future<List<DocPage>> getAllPages() async {
    if (_workspaceConfig.provider == WorkspaceProvider.local) {
      final localPages = await _readLocalPages();
      if (localPages != null) {
        return _sortPages(localPages);
      }
    }

    if (_workspaceConfig.provider == WorkspaceProvider.googleDrive) {
      final cachedPages = await _readCachedPages();
      await _flushGoogleDriveQueue();
      final drivePages = await _readGoogleDrivePages();
      if (drivePages != null) {
        await _writeCachedPages(drivePages);
        return _sortPages(drivePages);
      }
      return _sortPages(cachedPages);
    }

    if (_workspaceConfig.provider == WorkspaceProvider.iCloud) {
      final cachedPages = await _readCachedPages();
      final iCloudPages = await _readICloudPages();
      if (iCloudPages != null && iCloudPages.isNotEmpty) {
        return _sortPages(iCloudPages);
      }
      return _sortPages(cachedPages);
    }

    if (_workspaceConfig.provider == WorkspaceProvider.synologyDrive) {
      final cachedPages = await _readCachedPages();
      final synologyPages = await _readSynologyPages();
      if (synologyPages != null && synologyPages.isNotEmpty) {
        return _sortPages(synologyPages);
      }
      return _sortPages(cachedPages);
    }

    final cachedPages = await _readCachedPages();
    return _sortPages(cachedPages);
  }

  Future<void> savePages(List<DocPage> pages) async {
    if (_workspaceConfig.provider == WorkspaceProvider.local) {
      final wroteToLocal = await _writeLocalPages(pages);
      if (wroteToLocal) {
        return;
      }
    }

    if (_workspaceConfig.provider == WorkspaceProvider.googleDrive) {
      final wroteToDrive = await _writeGoogleDrivePages(pages);
      await _writeCachedPages(pages);
      if (wroteToDrive) {
        await _googleDriveSyncQueueService.clear();
        return;
      }
      await _googleDriveSyncQueueService.enqueuePagesSnapshot(pages);
      return;
    }

    if (_workspaceConfig.provider == WorkspaceProvider.iCloud) {
      final wroteToICloud = await _writeICloudPages(pages);
      await _writeCachedPages(pages);
      if (wroteToICloud) {
        return;
      }
    }

    if (_workspaceConfig.provider == WorkspaceProvider.synologyDrive) {
      final wroteToSynology = await _writeSynologyPages(pages);
      await _writeCachedPages(pages);
      if (wroteToSynology) {
        return;
      }
    }

    await _writeCachedPages(pages);
  }

  List<DocPage> _sortPages(List<DocPage> pages) {
    pages.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return pages;
  }

  String get _localFilePath {
    final directory = _workspaceConfig.directory.trim();
    return '$directory/pages.json';
  }

  Future<List<DocPage>?> _readLocalPages() async {
    try {
      final file = File(_localFilePath);
      if (!await file.exists()) {
        return [];
      }

      final raw = await file.readAsString();
      if (raw.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => DocPage.fromMap(entry as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeLocalPages(List<DocPage> pages) async {
    try {
      final file = File(_localFilePath);
      await file.parent.create(recursive: true);
      final raw = jsonEncode(pages.map((page) => page.toMap()).toList());
      await file.writeAsString(raw, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  String? get _driveFolderId {
    if (_workspaceConfig.provider != WorkspaceProvider.googleDrive) {
      return null;
    }
    final parts = _workspaceConfig.directory.split('/');
    return parts.length >= 3 ? parts[2] : null;
  }

  Future<List<DocPage>?> _readGoogleDrivePages() async {
    try {
      ensureGoogleSignInConfiguredForCurrentPlatform();

      final folderId = _driveFolderId;
      if (folderId == null) {
        return null;
      }

      final googleSignIn = createGoogleSignIn(
        scopes: const ['email', 'https://www.googleapis.com/auth/drive.file'],
      );

      final driveService = GoogleDriveService(googleSignIn: googleSignIn);
      return await driveService.readPages(folderId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeGoogleDrivePages(List<DocPage> pages) async {
    try {
      ensureGoogleSignInConfiguredForCurrentPlatform();

      final folderId = _driveFolderId;
      if (folderId == null) {
        return false;
      }

      final googleSignIn = createGoogleSignIn(
        scopes: const ['email', 'https://www.googleapis.com/auth/drive.file'],
      );

      final driveService = GoogleDriveService(googleSignIn: googleSignIn);
      await driveService.writePages(folderId, pages);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _flushGoogleDriveQueue() async {
    if (_workspaceConfig.provider != WorkspaceProvider.googleDrive) {
      return;
    }

    final folderId = _driveFolderId;
    if (folderId == null) {
      return;
    }

    final snapshots = await _googleDriveSyncQueueService.getQueuedSnapshots();
    if (snapshots.isEmpty) {
      return;
    }

    for (final snapshot in snapshots) {
      final wrote = await _writeGoogleDrivePages(snapshot.pages);
      if (!wrote) {
        return;
      }
    }

    await _googleDriveSyncQueueService.clear();
  }

  Future<List<DocPage>?> _readICloudPages() async {
    try {
      return await _iCloudService.readPages(_workspaceConfig.directory);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeICloudPages(List<DocPage> pages) async {
    try {
      await _iCloudService.writePages(_workspaceConfig.directory, pages);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<DocPage>?> _readSynologyPages() async {
    try {
      return await _synologyDriveService.readPages(_workspaceConfig.directory);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeSynologyPages(List<DocPage> pages) async {
    try {
      await _synologyDriveService.writePages(_workspaceConfig.directory, pages);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<DocPage>> _readCachedPages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => DocPage.fromMap(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeCachedPages(List<DocPage> pages) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(pages.map((page) => page.toMap()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
