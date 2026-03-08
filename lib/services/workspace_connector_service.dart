import 'package:file_selector/file_selector.dart';

import '../models/workspace_config.dart';
class WorkspaceConnectorException implements Exception {
  const WorkspaceConnectorException(this.message);

  final String message;
}

class WorkspaceConnectorService {
  Future<String?> chooseWorkspaceDirectory({
    required WorkspaceProvider provider,
    required String currentValue,
  }) async {
    switch (provider) {
      case WorkspaceProvider.local:
        return getDirectoryPath(confirmButtonText: 'Use Workspace');
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
