import 'package:file_selector/file_selector.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/workspace_config.dart';
import 'google_drive_service.dart';

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
        return _connectGoogleDrive(currentValue);
      case WorkspaceProvider.iCloud:
        return _normalizeCloudPath(
          currentValue,
          fallback: 'icloud:/DocumeWorkspace',
        );
      case WorkspaceProvider.synologyDrive:
        return _normalizeCloudPath(
          currentValue,
          fallback: 'synology:/DocumeWorkspace',
        );
    }
  }

  Future<String> _connectGoogleDrive(String currentValue) async {
    final googleSignIn = GoogleSignIn(
      scopes: const [
        'email',
        'https://www.googleapis.com/auth/drive.file',
      ],
    );

    final account = await googleSignIn.signIn();
    if (account == null) {
      throw const WorkspaceConnectorException('Google sign-in was cancelled.');
    }

    final driveService = GoogleDriveService(googleSignIn: googleSignIn);
    final folderId = await driveService.getOrCreateFolder('DocumeWorkspace');

    return 'gdrive:/${account.email}/$folderId';
  }

  String _normalizeCloudPath(
    String currentValue, {
    required String fallback,
  }) {
    final trimmed = currentValue.trim();
    if (trimmed.isEmpty || trimmed == '/DocumeWorkspace') {
      return fallback;
    }
    return trimmed;
  }
}
