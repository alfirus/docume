import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workspace_config.dart';

class WorkspaceService {
  static const _providerKey = 'workspace_provider';
  static const _directoryKey = 'workspace_directory';
  static const _themeModeKey = 'theme_mode';

  Future<WorkspaceConfig?> getWorkspaceConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final providerValue = prefs.getString(_providerKey);
    final directory = prefs.getString(_directoryKey);

    if (providerValue == null ||
        directory == null ||
        directory.trim().isEmpty) {
      return null;
    }

    final provider = WorkspaceProviderX.fromValue(providerValue);
    if (provider == null) {
      return null;
    }

    return WorkspaceConfig(provider: provider, directory: directory);
  }

  Future<void> saveWorkspaceConfig(WorkspaceConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, config.provider.value);
    await prefs.setString(_directoryKey, config.directory.trim());
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeModeKey);

    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = mode == ThemeMode.dark ? 'dark' : 'light';
    await prefs.setString(_themeModeKey, value);
  }

  Future<void> clearWorkspaceConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_providerKey);
    await prefs.remove(_directoryKey);
  }
}
