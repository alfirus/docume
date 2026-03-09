import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ai_command.dart';

class AiAuditService {
  Future<void> logEvent({
    required String workspacePath,
    required String phase,
    required AiProvider provider,
    required String prompt,
    String? summary,
    List<AiAction>? actions,
    String? details,
  }) async {
    try {
      final logFile = await _getLogFile(workspacePath);
      final payload = {
        'timestamp': DateTime.now().toIso8601String(),
        'phase': phase,
        'provider': provider.value,
        'prompt': prompt,
        'summary': summary,
        'actions': actions?.map((action) => action.toHumanLabel()).toList(),
        'details': details,
      };

      await logFile.writeAsString(
        '${jsonEncode(payload)}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      debugPrint('AI audit logging failed: $e');
    }
  }

  Future<String?> readLogs(String workspacePath) async {
    try {
      final logFile = await _getLogFile(workspacePath);
      if (!await logFile.exists()) {
        return null;
      }
      return logFile.readAsString();
    } catch (e) {
      debugPrint('AI audit read failed: $e');
      return null;
    }
  }

  Future<void> clearLogs(String workspacePath) async {
    try {
      final logFile = await _getLogFile(workspacePath);
      if (await logFile.exists()) {
        await logFile.delete();
      }
    } catch (e) {
      debugPrint('AI audit clear failed: $e');
    }
  }

  Future<File> _getLogFile(String workspacePath) async {
    final preferredPath = await _resolvePreferredLogPath(workspacePath);
    final preferredFile = File(preferredPath);
    final preparedPreferred = await _tryPrepareFile(preferredFile);
    if (preparedPreferred != null) {
      return preparedPreferred;
    }

    final fallbackPath = await _fallbackLogPath();
    final fallbackFile = File(fallbackPath);
    final preparedFallback = await _tryPrepareFile(fallbackFile);
    if (preparedFallback != null) {
      return preparedFallback;
    }

    throw FileSystemException('Unable to access audit log file', preferredPath);
  }

  Future<String> _resolvePreferredLogPath(String workspacePath) async {
    final trimmed = workspacePath.trim();
    if (trimmed.isNotEmpty &&
        !trimmed.startsWith('gdrive:') &&
        !trimmed.startsWith('icloud:') &&
        !trimmed.startsWith('synology:')) {
      return '$trimmed/ai_actions.log';
    }

    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/ai_actions.log';
  }

  Future<String> _fallbackLogPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/ai_actions.log';
  }

  Future<File?> _tryPrepareFile(File file) async {
    try {
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      if (!await file.exists()) {
        await file.create();
      }
      return file;
    } catch (_) {
      return null;
    }
  }
}
