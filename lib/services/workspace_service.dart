import 'package:shared_preferences/shared_preferences.dart';

import '../models/workspace_config.dart';

class WorkspaceService {
  static const _providerKey = 'workspace_provider';
  static const _directoryKey = 'workspace_directory';

  Future<WorkspaceConfig?> getWorkspaceConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final providerValue = prefs.getString(_providerKey);
    final directory = prefs.getString(_directoryKey);

    if (providerValue == null || directory == null || directory.trim().isEmpty) {
      return null;
    }

    final provider = WorkspaceProviderX.fromValue(providerValue);
    if (provider == null) {
      return null;
    }

    return WorkspaceConfig(
      provider: provider,
      directory: directory,
    );
  }

  Future<void> saveWorkspaceConfig(WorkspaceConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, config.provider.value);
    await prefs.setString(_directoryKey, config.directory.trim());
  }
}
