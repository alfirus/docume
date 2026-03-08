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
      final cachedPages = await _readCachedPages();
      final localPages = await _readLocalPages();
      if (localPages != null && localPages.isNotEmpty) {
        await _writeCachedPages(localPages);
        return _sortPages(localPages);
      }

      if (cachedPages.isNotEmpty) {
        // Best-effort mirror back to local files if local storage is available.
        await _writeLocalPages(cachedPages);
        return _sortPages(cachedPages);
      }

      return [];
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
      await _writeCachedPages(pages);
      if (wroteToLocal) {
        return;
      }
      return;
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

  String get _localPagesDirectory {
    final directory = _workspaceConfig.directory.trim();
    return '$directory/pages';
  }

  String get _oldLocalFilePath {
    final directory = _workspaceConfig.directory.trim();
    return '$directory/pages.json';
  }

  Future<void> _migrateFromOldFormat() async {
    try {
      final oldFile = File(_oldLocalFilePath);
      if (!await oldFile.exists()) {
        return;
      }

      final raw = await oldFile.readAsString();
      if (raw.isEmpty) {
        await oldFile.delete();
        return;
      }

      final decoded = jsonDecode(raw) as List<dynamic>;
      final pages = decoded
          .map((entry) => DocPage.fromMap(entry as Map<String, dynamic>))
          .toList();

      // Write each page as individual file
      final pagesDir = Directory(_localPagesDirectory);
      await pagesDir.create(recursive: true);

      for (final page in pages) {
        final pageFile = File('$_localPagesDirectory/${page.id}.json');
        final pageJson = jsonEncode(page.toMap());
        await pageFile.writeAsString(pageJson, flush: true);
      }

      // Delete old pages.json after successful migration
      await oldFile.delete();
    } catch (_) {
      // Migration failed, old file will be retried next time
    }
  }

  Future<List<DocPage>?> _readLocalPages() async {
    try {
      // Check and migrate from old format if needed
      await _migrateFromOldFormat();

      final pagesDir = Directory(_localPagesDirectory);
      if (!await pagesDir.exists()) {
        return [];
      }

      final pages = <DocPage>[];
      await for (final entity in pagesDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final raw = await entity.readAsString();
            if (raw.isNotEmpty) {
              final decoded = jsonDecode(raw) as Map<String, dynamic>;
              pages.add(DocPage.fromMap(decoded));
            }
          } catch (_) {
            // Skip corrupted page files
            continue;
          }
        }
      }

      return pages;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeLocalPages(List<DocPage> pages) async {
    try {
      final pagesDir = Directory(_localPagesDirectory);
      await pagesDir.create(recursive: true);

      // Get existing page IDs
      final existingIds = <String>{};
      if (await pagesDir.exists()) {
        await for (final entity in pagesDir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            final fileName = entity.path.split('/').last;
            final pageId = fileName.substring(0, fileName.length - 5);
            existingIds.add(pageId);
          }
        }
      }

      // Write each page as individual file
      final newIds = <String>{};
      for (final page in pages) {
        newIds.add(page.id);
        final pageFile = File('$_localPagesDirectory/${page.id}.json');
        final pageJson = jsonEncode(page.toMap());
        await pageFile.writeAsString(pageJson, flush: true);
      }

      // Delete page files that no longer exist
      final deletedIds = existingIds.difference(newIds);
      for (final pageId in deletedIds) {
        final pageFile = File('${_localPagesDirectory}/$pageId.json');
        if (await pageFile.exists()) {
          await pageFile.delete();
        }
      }

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
