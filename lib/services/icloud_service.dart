import 'dart:convert';
import 'dart:io';

import '../models/doc_page.dart';

class ICloudService {
  ICloudService({bool? isMacOS, String? homeDirectory, bool? isTestEnvironment})
    : _isMacOS = isMacOS ?? Platform.isMacOS,
      _homeDirectory = homeDirectory ?? Platform.environment['HOME'],
      _isTestEnvironment =
          isTestEnvironment ?? Platform.environment.containsKey('FLUTTER_TEST');

  static const _iCloudScheme = 'icloud:/';

  final bool _isMacOS;
  final String? _homeDirectory;
  final bool _isTestEnvironment;

  String? resolveWorkspacePath(String workspaceDirectory) {
    final trimmed = workspaceDirectory.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    // Allow a direct absolute path for development and custom setups.
    if (trimmed.startsWith('/')) {
      return trimmed;
    }

    if (!trimmed.startsWith(_iCloudScheme)) {
      return null;
    }

    // Widget/integration tests should not depend on host iCloud directories.
    if (_isTestEnvironment) {
      return null;
    }

    if (!_isMacOS || _homeDirectory == null || _homeDirectory!.isEmpty) {
      return null;
    }

    final relativePath = trimmed
        .substring(_iCloudScheme.length)
        .replaceFirst(RegExp(r'^/+'), '');

    final iCloudRoot =
        '$_homeDirectory/Library/Mobile Documents/com~apple~CloudDocs';

    if (relativePath.isEmpty) {
      return iCloudRoot;
    }

    return '$iCloudRoot/$relativePath';
  }

  Future<List<DocPage>> readPages(String workspaceDirectory) async {
    final workspacePath = resolveWorkspacePath(workspaceDirectory);
    if (workspacePath == null) {
      throw const FormatException('Invalid iCloud workspace path.');
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
      throw const FormatException('Invalid iCloud workspace path.');
    }

    final file = File('$workspacePath/pages.json');
    await file.parent.create(recursive: true);

    final raw = jsonEncode(pages.map((page) => page.toMap()).toList());
    await file.writeAsString(raw, flush: true);
  }
}
