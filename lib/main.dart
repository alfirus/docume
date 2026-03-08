import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import 'models/workspace_config.dart';
import 'screens/workspace_setup_screen.dart';
import 'services/workspace_service.dart';
import 'screens/page_list_screen.dart';

void main() {
  runApp(const DocumeApp());
}

class DocumeApp extends StatefulWidget {
  const DocumeApp({super.key});

  @override
  State<DocumeApp> createState() => _DocumeAppState();
}

class _DocumeAppState extends State<DocumeApp> {
  final WorkspaceService _workspaceService = WorkspaceService();
  final shad.ThemeData _lightShadTheme = shad.ThemeData(
    colorScheme: shad.LegacyColorSchemes.zinc(shad.ThemeMode.light),
    radius: 0.5,
  );
  final shad.ThemeData _darkShadTheme = shad.ThemeData(
    colorScheme: shad.LegacyColorSchemes.zinc(shad.ThemeMode.dark),
    radius: 0.5,
  );
  WorkspaceConfig? _workspaceConfig;
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  Future<void> _loadWorkspace() async {
    final config = await _workspaceService.getWorkspaceConfig();
    final themeMode = await _workspaceService.getThemeMode();
    if (!mounted) {
      return;
    }
    setState(() {
      _workspaceConfig = config;
      _themeMode = themeMode;
      _isLoading = false;
    });
  }

  Future<void> _completeSetup(WorkspaceConfig config) async {
    await _workspaceService.saveWorkspaceConfig(config);
    if (!mounted) {
      return;
    }
    setState(() {
      _workspaceConfig = config;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await _workspaceService.saveThemeMode(mode);
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> _resetWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    final pageKeys = prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith('docume_pages_') ||
              key.startsWith('docume_gdrive_queue_'),
        )
        .toList();

    for (final key in pageKeys) {
      await prefs.remove(key);
    }

    await _workspaceService.clearWorkspaceConfig();

    if (!mounted) {
      return;
    }

    setState(() {
      _workspaceConfig = null;
    });
  }

  ThemeData _buildMaterialTheme(shad.ThemeData activeTheme) {
    return ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: activeTheme.colorScheme.primary,
        brightness: activeTheme.brightness,
        surface: activeTheme.colorScheme.background,
        primary: activeTheme.colorScheme.primary,
        secondary: activeTheme.colorScheme.secondary,
        error: activeTheme.colorScheme.destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeMode == ThemeMode.dark;
    final activeShadTheme = isDark ? _darkShadTheme : _lightShadTheme;

    return shad.ShadcnApp(
      title: 'Docume',
      localizationsDelegates: const [
        ...FlutterQuillLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      themeMode: isDark ? shad.ThemeMode.dark : shad.ThemeMode.light,
      theme: _lightShadTheme,
      darkTheme: _darkShadTheme,
      materialTheme: _buildMaterialTheme(activeShadTheme),
      cupertinoTheme: CupertinoThemeData(
        brightness: activeShadTheme.brightness,
        primaryColor: activeShadTheme.colorScheme.primary,
        barBackgroundColor: activeShadTheme.colorScheme.accent,
        scaffoldBackgroundColor: activeShadTheme.colorScheme.background,
        applyThemeToAll: true,
        primaryContrastingColor: activeShadTheme.colorScheme.primaryForeground,
      ),
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _workspaceConfig == null
          ? WorkspaceSetupScreen(onComplete: _completeSetup)
          : PageListScreen(
              workspaceConfig: _workspaceConfig!,
              themeMode: _themeMode,
              onThemeModeChanged: _setThemeMode,
              onResetRequested: _resetWorkspace,
            ),
    );
  }
}
