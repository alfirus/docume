import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/doc_page.dart';
import '../models/workspace_config.dart';
import 'google_drive_service.dart';

class PageRepository {
  PageRepository({required WorkspaceConfig workspaceConfig})
      : _workspaceConfig = workspaceConfig,
        _namespace = workspaceConfig.namespace;

  final WorkspaceConfig _workspaceConfig;
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
      final drivePages = await _readGoogleDrivePages();
      if (drivePages != null) {
        return _sortPages(drivePages);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    final pages = decoded
        .map((entry) => DocPage.fromMap(entry as Map<String, dynamic>))
        .toList();
    return _sortPages(pages);
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
      if (wroteToDrive) {
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(pages.map((page) => page.toMap()).toList());
    await prefs.setString(_storageKey, raw);
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
      final folderId = _driveFolderId;
      if (folderId == null) {
        return null;
      }

      final googleSignIn = GoogleSignIn(
        scopes: const [
          'email',
          'https://www.googleapis.com/auth/drive.file',
        ],
      );

      final driveService = GoogleDriveService(googleSignIn: googleSignIn);
      return await driveService.readPages(folderId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeGoogleDrivePages(List<DocPage> pages) async {
    try {
      final folderId = _driveFolderId;
      if (folderId == null) {
        return false;
      }

      final googleSignIn = GoogleSignIn(
        scopes: const [
          'email',
          'https://www.googleapis.com/auth/drive.file',
        ],
      );

      final driveService = GoogleDriveService(googleSignIn: googleSignIn);
      await driveService.writePages(folderId, pages);
      return true;
    } catch (_) {
      return false;
    }
  }
}
