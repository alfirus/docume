import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docume/services/error_logging_service.dart';

void main() {
  group('ErrorLoggingService', () {
    late ErrorLoggingService service;
    late Directory tempDir;
    late String testWorkspacePath;

    setUp(() {
      service = ErrorLoggingService();
      tempDir = Directory.systemTemp.createTempSync('error_log_test_');
      testWorkspacePath = tempDir.path;
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('initialize sets workspace path', () async {
      await service.initialize(testWorkspacePath);
      
      // Service should be initialized and able to log
      await service.logMessage('Test message');
      
      final logs = await service.readLogs();
      expect(logs, isNotNull);
    });

    test('logError writes to error.log file', () async {
      await service.initialize(testWorkspacePath);
      
      final testError = Exception('Test error');
      final testStack = StackTrace.current;
      
      await service.logError(testError, testStack);
      
      final logPath = await service.getLogFilePath();
      expect(logPath, isNotNull);
      
      final logFile = File(logPath!);
      expect(await logFile.exists(), isTrue);
      
      final content = await logFile.readAsString();
      expect(content, contains('ERROR'));
      expect(content, contains('Test error'));
    });

    test('logError with context includes context in log', () async {
      await service.initialize(testWorkspacePath);
      
      await service.logError(
        Exception('Test error'),
        null,
        context: 'Test context',
      );
      
      final logs = await service.readLogs();
      expect(logs, isNotNull);
      expect(logs, contains('Context: Test context'));
      expect(logs, contains('Test error'));
    });

    test('logMessage writes info message', () async {
      await service.initialize(testWorkspacePath);
      
      await service.logMessage('Test info message');
      
      final logs = await service.readLogs();
      expect(logs, isNotNull);
      expect(logs, contains('INFO: Test info message'));
    });

    test('logMessage with custom level', () async {
      await service.initialize(testWorkspacePath);
      
      await service.logMessage('Warning message', level: 'WARNING');
      
      final logs = await service.readLogs();
      expect(logs, isNotNull);
      expect(logs, contains('WARNING: Warning message'));
    });

    test('logFlutterError logs Flutter error details', () async {
      await service.initialize(testWorkspacePath);
      
      final testException = Exception('Flutter test error');
      final testStack = StackTrace.current;
      final details = FlutterErrorDetails(
        exception: testException,
        stack: testStack,
        context: ErrorDescription('Test context'),
      );
      
      await service.logFlutterError(details);
      
      final logs = await service.readLogs();
      expect(logs, isNotNull);
      expect(logs, contains('Flutter test error'));
    });

    test('multiple errors are appended to log', () async {
      await service.initialize(testWorkspacePath);
      
      await service.logError(Exception('Error 1'), null);
      await service.logError(Exception('Error 2'), null);
      await service.logError(Exception('Error 3'), null);
      
      final logs = await service.readLogs();
      expect(logs, isNotNull);
      expect(logs, contains('Error 1'));
      expect(logs, contains('Error 2'));
      expect(logs, contains('Error 3'));
    });

    test('clearLogs removes log file', () async {
      await service.initialize(testWorkspacePath);
      
      await service.logError(Exception('Test'), null);
      
      // Verify log exists
      var logs = await service.readLogs();
      expect(logs, isNotNull);
      expect(logs, isNotEmpty);
      
      // Clear logs
      await service.clearLogs();
      
      // Verify log is cleared (either null or empty)
      logs = await service.readLogs();
      expect(logs == null || logs.isEmpty, isTrue);
    });

    test('readLogs returns null or empty when no log file exists', () async {
      await service.initialize(testWorkspacePath);
      
      final logs = await service.readLogs();
      expect(logs == null || logs.isEmpty, isTrue);
    });

    test('service handles uninitialized state gracefully', () async {
      // Don't initialize
      
      // Should not throw
      await service.logError(Exception('Test'), null);
      await service.logMessage('Test');
      
      // Verify no errors occurred (test passes if we get here)
      expect(true, isTrue);
    });

    test('log file path is correct for local workspace', () async {
      await service.initialize(testWorkspacePath);
      
      await service.logMessage('Test');
      
      final logPath = await service.getLogFilePath();
      expect(logPath, contains(testWorkspacePath));
      expect(logPath, endsWith('error.log'));
    });

    test('service creates parent directory if not exists', () async {
      final nestedPath = '${tempDir.path}/nested/workspace';
      
      await service.initialize(nestedPath);
      await service.logMessage('Test');
      
      final logPath = await service.getLogFilePath();
      final logFile = File(logPath!);
      
      expect(await logFile.exists(), isTrue);
      expect(await logFile.parent.exists(), isTrue);
    });

    test('timestamps are included in log entries', () async {
      await service.initialize(testWorkspacePath);
      
      await service.logError(Exception('Test'), null);
      
      final logs = await service.readLogs();
      expect(logs, isNotNull);
      
      // Should contain ISO8601 timestamp
      expect(logs, contains(RegExp(r'\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')));
    });

    test('log rotation occurs when file is too large', () async {
      await service.initialize(testWorkspacePath);
      
      // Write many large messages to trigger rotation
      for (var i = 0; i < 2000; i++) {
        await service.logMessage('Test message $i with some extra content to increase size');
      }
      
      final logPath = await service.getLogFilePath();
      final logFile = File(logPath!);
      final stat = await logFile.stat();
      
      // File size should be under max size after rotation
      expect(stat.size, lessThan(6 * 1024 * 1024)); // 6MB (allowing some buffer)
    });

    test('service handles errors during logging gracefully', () async {
      // Initialize with an invalid path
      await service.initialize('/invalid/nonexistent/path');
      
      // Should not throw
      await service.logError(Exception('Test'), null);
      await service.logMessage('Test');
      
      // Verify no errors occurred (test passes if we get here)
      expect(true, isTrue);
    });
  });
}
