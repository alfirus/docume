import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../models/workspace_config.dart';
import '../services/workspace_connector_service.dart';

class WorkspaceSetupScreen extends StatefulWidget {
  const WorkspaceSetupScreen({
    super.key,
    required this.onComplete,
  });

  final Future<void> Function(WorkspaceConfig config) onComplete;

  @override
  State<WorkspaceSetupScreen> createState() => _WorkspaceSetupScreenState();
}

class _WorkspaceSetupScreenState extends State<WorkspaceSetupScreen> {
  static const _enabledProviders = [WorkspaceProvider.local];

  WorkspaceProvider _provider = WorkspaceProvider.local;
  final WorkspaceConnectorService _connectorService = WorkspaceConnectorService();
  final TextEditingController _directoryController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _directoryController.text = '/DocumeWorkspace';
  }

  @override
  void dispose() {
    _directoryController.dispose();
    super.dispose();
  }

  Future<void> _connectProvider() async {
    try {
      final path = await _connectorService.chooseWorkspaceDirectory(
        provider: _provider,
        currentValue: _directoryController.text,
      );

      if (path == null || !mounted) {
        return;
      }

      setState(() {
        _directoryController.text = path;
      });
    } on WorkspaceConnectorException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to connect provider. Check your provider setup and try again.'),
        ),
      );
    }
  }

  String _providerActionLabel() {
    switch (_provider) {
      case WorkspaceProvider.local:
        return 'Choose Directory';
      case WorkspaceProvider.googleDrive:
        return 'Connect Google Drive';
      case WorkspaceProvider.iCloud:
        return 'Use iCloud Path';
      case WorkspaceProvider.synologyDrive:
        return 'Use Synology Path';
    }
  }

  Future<void> _saveSetup() async {
    final directory = _directoryController.text.trim();

    if (directory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace directory is required.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final config = WorkspaceConfig(
      provider: _provider,
      directory: directory,
    );

    await widget.onComplete(config);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Workspace'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Choose workspace storage',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'For first-time installation, select where Docume workspace is located.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Google Drive, iCloud, and Synology are temporarily disabled.',
            ),
            const SizedBox(height: 12),
            SegmentedButton<WorkspaceProvider>(
              showSelectedIcon: false,
              segments: [
                for (final option in _enabledProviders)
                  ButtonSegment<WorkspaceProvider>(
                    value: option,
                    label: Text(option.label),
                  ),
              ],
              selected: {_provider},
              onSelectionChanged: (value) {
                setState(() {
                  _provider = value.first;
                });
              },
            ),
            const SizedBox(height: 12),
            shad.TextField(
              controller: _directoryController,
              placeholder: const Text('/Users/name/DocumeWorkspace'),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Text('Workspace Directory', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                shad.OutlineButton(
                  onPressed: _connectProvider,
                  leading: const Icon(Icons.folder_open, size: 16),
                  child: Text(_providerActionLabel()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: shad.PrimaryButton(
                onPressed: _isSaving ? null : _saveSetup,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
