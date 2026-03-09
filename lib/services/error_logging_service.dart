import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for logging errors to a file in the workspace directory
class ErrorLoggingService {
  ErrorLoggingService._internal();

  static final ErrorLoggingService _instance = ErrorLoggingService._internal();

  factory ErrorLoggingService() => _instance;

  static const _maxLogFileSize = 5 * 1024 * 1024; // 5 MB
  static const _maxLogLines = 1000;

  String? _workspacePath;
  bool _initialized = false;
  String? _lastPreferredPathFailure;

  /// Initialize the error logging service with workspace path
  Future<void> initialize(String? workspacePath) async {
    final trimmed = workspacePath?.trim();
    _workspacePath = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _initialized = true;
  }

  /// Log an error to the error.log file
  Future<void> logError(
    Object error,
    StackTrace? stackTrace, {
    String? context,
  }) async {
    if (!_initialized) {
      // Fallback mode: still try logging even if initialize() was not called yet.
      _initialized = true;
    }

    try {
      final logFile = await _getLogFile();
      if (logFile == null) {
        debugPrint('Unable to get log file');
        return;
      }

      final timestamp = DateTime.now().toIso8601String();
      final buffer = StringBuffer();

      buffer.writeln('[$timestamp] ERROR');
      if (context != null) {
        buffer.writeln('Context: $context');
      }
      buffer.writeln('Error: $error');
      if (stackTrace != null) {
        buffer.writeln('Stack trace:');
        buffer.writeln(stackTrace.toString());
      }
      buffer.writeln('---');

      // Append to log file
      await logFile.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
      );

      // Check and rotate log if needed
      await _rotateLogIfNeeded(logFile);
    } catch (e) {
      // If logging fails, at least print to console
      debugPrint('Failed to log error: $e');
    }
  }

  /// Log a Flutter framework error
  Future<void> logFlutterError(FlutterErrorDetails details) async {
    await logError(
      details.exception,
      details.stack,
      context: details.context?.toString(),
    );
  }

  /// Log a general message (info, warning, etc.)
  Future<void> logMessage(String message, {String? level}) async {
    if (!_initialized) {
      _initialized = true;
    }

    try {
      final logFile = await _getLogFile();
      if (logFile == null) {
        return;
      }

      final timestamp = DateTime.now().toIso8601String();
      final logLevel = level ?? 'INFO';
      final entry = '[$timestamp] $logLevel: $message\n';

      await logFile.writeAsString(
        entry,
        mode: FileMode.append,
      );

      await _rotateLogIfNeeded(logFile);
    } catch (e) {
      debugPrint('Failed to log message: $e');
    }
  }

  /// Get the error log file
  Future<File?> _getLogFile() async {
    try {
      final preferredPath = await _resolvePreferredLogPath();
      if (preferredPath != null) {
        try {
          return await _ensureLogFileAtPath(preferredPath);
        } catch (e) {
          // Workspace paths can be sandbox-restricted on macOS (e.g. Documents)
          // unless persisted security-scoped access is available.
          // Fallback silently to app documents and avoid repeated log spam.
          if (_lastPreferredPathFailure != preferredPath) {
            _lastPreferredPathFailure = preferredPath;
            debugPrint(
              'Workspace error.log unavailable, using app documents fallback.',
            );
          }
        }
      }

      // Fallback to app documents directory if workspace path is unavailable/unwritable.
      final appDir = await getApplicationDocumentsDirectory();
      final fallbackPath = '${appDir.path}/error.log';
      return await _ensureLogFileAtPath(fallbackPath);
    } catch (e) {
      debugPrint('Failed to get log file: $e');
      return null;
    }
  }

  Future<String?> _resolvePreferredLogPath() async {
    final workspacePath = _workspacePath;
    if (workspacePath == null || workspacePath.isEmpty) {
      return null;
    }

    if (workspacePath.startsWith('gdrive:')) {
      // Google Drive uses cloud URI; keep a local log.
      return null;
    }

    if (workspacePath.startsWith('icloud:')) {
      final icloudPath = workspacePath.substring('icloud:'.length);
      final homeDir = Platform.environment['HOME'] ?? '';
      final fullPath =
          '$homeDir/Library/Mobile Documents/com~apple~CloudDocs$icloudPath';
      return '$fullPath/error.log';
    }

    if (workspacePath.startsWith('synology:')) {
      final synologyPath = workspacePath.substring('synology:'.length);
      final homeDir = Platform.environment['HOME'] ?? '';
      final fullPath = '$homeDir/SynologyDrive$synologyPath';
      return '$fullPath/error.log';
    }

    if (workspacePath.startsWith('local:')) {
      final localPath = workspacePath.substring('local:'.length).trim();
      return '$localPath/error.log';
    }

    if (workspacePath.startsWith('file://')) {
      final uri = Uri.parse(workspacePath);
      final filePath = uri.toFilePath();
      return '$filePath/error.log';
    }

    // Default local workspace path.
    return '$workspacePath/error.log';
  }

  Future<File> _ensureLogFileAtPath(String logPath) async {
      final file = File(logPath);

      // Create parent directory if it doesn't exist
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      // Create file if it doesn't exist
      if (!await file.exists()) {
        await file.create();
      }

      return file;
  }

  /// Rotate log file if it's too large
  Future<void> _rotateLogIfNeeded(File logFile) async {
    try {
      final stat = await logFile.stat();
      
      if (stat.size > _maxLogFileSize) {
        // Read all lines
        final lines = await logFile.readAsLines();
        
        // Keep only the most recent lines
        final keptLines = lines.length > _maxLogLines
            ? lines.sublist(lines.length - _maxLogLines)
            : lines;
        
        // Rewrite file with kept lines
        await logFile.writeAsString(keptLines.join('\n') + '\n');
        
        // Log rotation event
        final timestamp = DateTime.now().toIso8601String();
        await logFile.writeAsString(
          '[$timestamp] INFO: Log file rotated (size: ${stat.size} bytes)\n',
          mode: FileMode.append,
        );
      }
    } catch (e) {
      debugPrint('Failed to rotate log: $e');
    }
  }

  /// Clear all logs
  Future<void> clearLogs() async {
    try {
      final logFile = await _getLogFile();
      if (logFile != null && await logFile.exists()) {
        await logFile.delete();
      }
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }

  /// Get the current log file path
  Future<String?> getLogFilePath() async {
    final logFile = await _getLogFile();
    return logFile?.path;
  }

  /// Read all logs
  Future<String?> readLogs() async {
    try {
      final logFile = await _getLogFile();
      if (logFile != null && await logFile.exists()) {
        return await logFile.readAsString();
      }
      return null;
    } catch (e) {
      debugPrint('Failed to read logs: $e');
      return null;
    }
  }
}
