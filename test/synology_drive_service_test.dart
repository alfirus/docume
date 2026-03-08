import 'dart:io';

import 'package:docume/models/doc_page.dart';
import 'package:docume/services/synology_drive_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SynologyDriveService', () {
    test('resolves synology scheme into default SynologyDrive path', () {
      final service = SynologyDriveService(
        homeDirectory: '/Users/tester',
        isTestEnvironment: false,
      );

      final resolved = service.resolveWorkspacePath(
        'synology:/DocumeWorkspace',
      );

      expect(resolved, '/Users/tester/SynologyDrive/DocumeWorkspace');
    });

    test('keeps direct absolute path untouched', () {
      final service = SynologyDriveService(
        homeDirectory: '/Users/tester',
        isTestEnvironment: false,
      );

      final resolved = service.resolveWorkspacePath('/tmp/docume-synology');

      expect(resolved, '/tmp/docume-synology');
    });

    test('returns null for scheme path in test environment', () {
      final service = SynologyDriveService(
        homeDirectory: '/Users/tester',
        isTestEnvironment: true,
      );

      final resolved = service.resolveWorkspacePath(
        'synology:/DocumeWorkspace',
      );

      expect(resolved, isNull);
    });

    test('writes and reads pages from resolved workspace', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'docume_synology_test_',
      );
      addTearDown(() async {
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final service = SynologyDriveService(
        homeDirectory: tempRoot.path,
        isTestEnvironment: false,
      );

      final pages = [
        DocPage(
          id: 's-1',
          title: 'Synology Page',
          htmlContent: '<p>Synology content</p>',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 2),
        ),
      ];

      await service.writePages('synology:/DocumeWorkspace', pages);

      final restored = await service.readPages('synology:/DocumeWorkspace');
      expect(restored.length, 1);
      expect(restored.first.id, 's-1');
      expect(restored.first.title, 'Synology Page');
    });
  });
}
