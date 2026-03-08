import 'package:file_selector/file_selector.dart';
import 'dart:io';

import '../models/workspace_config.dart';

class WorkspaceConnectorException implements Exception {
  const WorkspaceConnectorException(this.message);

  final String message;
}

class WorkspaceConnectorService {
  String? _resolveInitialDirectory(String currentValue) {
    final value = currentValue.trim();
    if (value.isEmpty) {
      return null;
    }

    final candidate = Directory(value);
    if (!candidate.isAbsolute) {
      return null;
    }

    if (!candidate.existsSync()) {
      return null;
    }

    return value;
  }

  Future<String?> _chooseLocalDirectory(String currentValue) async {
    final initialDirectory = _resolveInitialDirectory(currentValue);

    try {
      return await getDirectoryPath(
        confirmButtonText: 'Use Workspace',
        initialDirectory: initialDirectory,
      );
    } catch (_) {
      if (initialDirectory == null) {
        rethrow;
      }

      // Some platforms can fail when an initial path is rejected by the OS.
      // Retry without initial directory so picker still opens.
      return getDirectoryPath(confirmButtonText: 'Use Workspace');
    }
  }

  Future<String?> chooseWorkspaceDirectory({
    required WorkspaceProvider provider,
    required String currentValue,
  }) async {
    switch (provider) {
      case WorkspaceProvider.local:
        return _chooseLocalDirectory(currentValue);
      case WorkspaceProvider.googleDrive:
        throw const WorkspaceConnectorException(
          'Google Drive is temporarily disabled.',
        );
      case WorkspaceProvider.iCloud:
        throw const WorkspaceConnectorException(
          'iCloud is temporarily disabled.',
        );
      case WorkspaceProvider.synologyDrive:
        throw const WorkspaceConnectorException(
          'Synology Drive is temporarily disabled.',
        );
    }
  }
}
