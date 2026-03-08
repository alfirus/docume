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

  Future<List<DocPage>> readPages(String workspaceDirectory) async {
    final workspacePath = resolveWorkspacePath(workspaceDirectory);
    if (workspacePath == null) {
      throw const FormatException('Invalid Synology workspace path.');
    }

    final file = File('$workspacePath/pages.json');
    if (!await file.exists()) {
      return [];
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => DocPage.fromMap(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> writePages(
    String workspaceDirectory,
    List<DocPage> pages,
  ) async {
    final workspacePath = resolveWorkspacePath(workspaceDirectory);
    if (workspacePath == null) {
      throw const FormatException('Invalid Synology workspace path.');
    }

    final file = File('$workspacePath/pages.json');
    await file.parent.create(recursive: true);

    final raw = jsonEncode(pages.map((page) => page.toMap()).toList());
    await file.writeAsString(raw, flush: true);
  }
}
