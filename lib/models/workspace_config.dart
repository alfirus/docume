enum WorkspaceProvider {
  local,
  googleDrive,
  iCloud,
  synologyDrive,
}

extension WorkspaceProviderX on WorkspaceProvider {
  String get label {
    switch (this) {
      case WorkspaceProvider.local:
        return 'Local';
      case WorkspaceProvider.googleDrive:
        return 'Google Drive';
      case WorkspaceProvider.iCloud:
        return 'iCloud';
      case WorkspaceProvider.synologyDrive:
        return 'Synology Drive';
    }
  }

  String get value {
    switch (this) {
      case WorkspaceProvider.local:
        return 'local';
      case WorkspaceProvider.googleDrive:
        return 'google_drive';
      case WorkspaceProvider.iCloud:
        return 'icloud';
      case WorkspaceProvider.synologyDrive:
        return 'synology_drive';
    }
  }

  static WorkspaceProvider? fromValue(String value) {
    for (final provider in WorkspaceProvider.values) {
      if (provider.value == value) {
        return provider;
      }
    }
    return null;
  }
}

class WorkspaceConfig {
  const WorkspaceConfig({
    required this.provider,
    required this.directory,
  });

  final WorkspaceProvider provider;
  final String directory;

  String get namespace => '${provider.value}|${directory.trim()}';
}
