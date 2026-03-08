import 'dart:convert';
import 'dart:io';

import '../models/doc_page.dart';

class SynologyDriveService {
  SynologyDriveService({String? homeDirectory, bool? isTestEnvironment})
    : _homeDirectory = homeDirectory ?? Platform.environment['HOME'],
      _isTestEnvironment =
          isTestEnvironment ?? Platform.environment.containsKey('FLUTTER_TEST');

  static const _synologyScheme = 'synology:/';

  final String? _homeDirectory;
  final bool _isTestEnvironment;

  String? resolveWorkspacePath(String workspaceDirectory) {
    final trimmed = workspaceDirectory.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    // Allow direct absolute paths for custom Synology Drive folders.
    if (trimmed.startsWith('/')) {
      return trimmed;
    }

    if (!trimmed.startsWith(_synologyScheme)) {
      return null;
    }

    // Widget/integration tests should avoid host filesystem dependencies.
    if (_isTestEnvironment ||
        _homeDirectory == null ||
        _homeDirectory!.isEmpty) {
      return null;
    }

    final relativePath = trimmed
        .substring(_synologyScheme.length)
        .replaceFirst(RegExp(r'^/+'), '');

    final synologyRoot = '$_homeDirectory/SynologyDrive';
    if (relativePath.isEmpty) {
      return synologyRoot;
    }

    return '$synologyRoot/$relativePath';
  }

  Future<void> _migrateFromOldFormat(String workspacePath) async {
    try {
      final oldFile = File('$workspacePath/pages.json');
      if (!await oldFile.exists()) {
        return;
      }

      final raw = await oldFile.readAsString();
      if (raw.trim().isEmpty) {
        await oldFile.delete();
        return;
      }

      final decoded = jsonDecode(raw) as List<dynamic>;
      final pages = decoded
          .map((entry) => DocPage.fromMap(entry as Map<String, dynamic>))
          .toList();

      // Write each page as individual file
      final pagesDir = Directory('$workspacePath/pages');
      await pagesDir.create(recursive: true);

      for (final page in pages) {
        final pageFile = File('$workspacePath/pages/${page.id}.json');
        final pageJson = jsonEncode(page.toMap());
        await pageFile.writeAsString(pageJson, flush: true);
      }

      // Delete old pages.json after successful migration
      await oldFile.delete();
    } catch (_) {
      // Migration failed, old file will be retried next time
    }
  }

  Future<List<DocPage>> readPages(String workspaceDirectory) async {
    final workspacePath = resolveWorkspacePath(workspaceDirectory);
    if (workspacePath == null) {
      throw const FormatException('Invalid Synology workspace path.');
    }

    // Check and migrate from old format if needed
    await _migrateFromOldFormat(workspacePath);

    final pagesDir = Directory('$workspacePath/pages');
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
  }

  Future<void> writePages(
    String workspaceDirectory,
    List<DocPage> pages,
  ) async {
    final workspacePath = resolveWorkspacePath(workspaceDirectory);
    if (workspacePath == null) {
      throw const FormatException('Invalid Synology workspace path.');
    }

    final pagesDir = Directory('$workspacePath/pages');
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
      final pageFile = File('$workspacePath/pages/${page.id}.json');
      final pageJson = jsonEncode(page.toMap());
      await pageFile.writeAsString(pageJson, flush: true);
    }

    // Delete page files that no longer exist
    final deletedIds = existingIds.difference(newIds);
    for (final pageId in deletedIds) {
      final pageFile = File('$workspacePath/pages/$pageId.json');
      if (await pageFile.exists()) {
        await pageFile.delete();
      }
    }
  }
}
