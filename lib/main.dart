import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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

  @override
  Widget build(BuildContext context) {
    return ShadApp.material(
      title: 'Docume',
      localizationsDelegates: const [
        ...FlutterQuillLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      themeMode: _themeMode,
      theme: ShadThemeData(
        colorScheme: const ShadSlateColorScheme.light(),
        brightness: Brightness.light,
      ),
      darkTheme: ShadThemeData(
        colorScheme: const ShadSlateColorScheme.dark(),
        brightness: Brightness.dark,
      ),
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _workspaceConfig == null
          ? WorkspaceSetupScreen(onComplete: _completeSetup)
          : PageListScreen(
              workspaceConfig: _workspaceConfig!,
              themeMode: _themeMode,
              onThemeModeChanged: _setThemeMode,
            ),
    );
  }
}
