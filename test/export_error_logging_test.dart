import 'dart:io';

import 'package:docume/services/error_logging_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Export Error Logging', () {
    late ErrorLoggingService service;
    late Directory tempDir;

    setUp(() async {
      service = ErrorLoggingService();
      tempDir = Directory.systemTemp.createTempSync('export_error_log_test_');
      await service.initialize(tempDir.path);
      await service.clearLogs();
    });

    tearDown(() async {
      await service.clearLogs();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('caught PDF export failure is written to error.log', () async {
      try {
        throw Exception('Simulated PDF export failure');
      } catch (error, stackTrace) {
        await service.logError(
          error,
          stackTrace,
          context: 'Single page export to PDF failed',
        );
      }

      final logPath = await service.getLogFilePath();
      expect(logPath, isNotNull);

      final logFile = File(logPath!);
      expect(await logFile.exists(), isTrue);

      final content = await logFile.readAsString();
      expect(content, contains('ERROR'));
      expect(content, contains('Single page export to PDF failed'));
      expect(content, contains('Simulated PDF export failure'));
      expect(content, contains('Stack trace:'));
    });

    test('caught bulk PDF export failure is appended to error.log', () async {
      await service.logError(
        Exception('first error'),
        StackTrace.current,
        context: 'Bulk export to PDF failed',
      );

      await service.logError(
        Exception('second error'),
        StackTrace.current,
        context: 'Bulk export to PDF failed',
      );

      final content = await service.readLogs();
      expect(content, isNotNull);
      expect(content, contains('first error'));
      expect(content, contains('second error'));
    });
  });
}
