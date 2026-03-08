import 'package:flutter/material.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  Future<void> _loadWorkspace() async {
    final config = await _workspaceService.getWorkspaceConfig();
    if (!mounted) {
      return;
    }
    setState(() {
      _workspaceConfig = config;
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docume',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _workspaceConfig == null
              ? WorkspaceSetupScreen(onComplete: _completeSetup)
              : PageListScreen(workspaceConfig: _workspaceConfig!),
    );
  }
}
