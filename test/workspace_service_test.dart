import 'package:docume/services/workspace_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WorkspaceService theme mode', () {
    test('defaults to light mode when unset', () async {
      SharedPreferences.setMockInitialValues({});
      final service = WorkspaceService();

      final mode = await service.getThemeMode();
      expect(mode, ThemeMode.light);
    });

    test('persists and reads dark mode', () async {
      SharedPreferences.setMockInitialValues({});
      final service = WorkspaceService();

      await service.saveThemeMode(ThemeMode.dark);

      final mode = await service.getThemeMode();
      expect(mode, ThemeMode.dark);
    });
  });
}
