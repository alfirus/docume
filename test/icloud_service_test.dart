import 'dart:io';

import 'package:docume/models/doc_page.dart';
import 'package:docume/services/icloud_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ICloudService', () {
    test('resolves icloud scheme into macOS iCloud Drive path', () {
      final service = ICloudService(
        isMacOS: true,
        homeDirectory: '/Users/tester',
        isTestEnvironment: false,
      );

      final resolved = service.resolveWorkspacePath('icloud:/DocumeWorkspace');

      expect(
        resolved,
        '/Users/tester/Library/Mobile Documents/com~apple~CloudDocs/DocumeWorkspace',
      );
    });

    test('keeps direct absolute path untouched', () {
      final service = ICloudService(
        isMacOS: true,
        homeDirectory: '/Users/tester',
        isTestEnvironment: false,
      );

      final resolved = service.resolveWorkspacePath('/tmp/docume-icloud');

      expect(resolved, '/tmp/docume-icloud');
    });

    test('returns null for icloud scheme outside macOS', () {
      final service = ICloudService(
        isMacOS: false,
        homeDirectory: '/Users/tester',
        isTestEnvironment: false,
      );

      final resolved = service.resolveWorkspacePath('icloud:/DocumeWorkspace');

      expect(resolved, isNull);
    });

    test('writes and reads pages from resolved workspace', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'docume_icloud_test_',
      );
      addTearDown(() async {
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final service = ICloudService(
        isMacOS: true,
        homeDirectory: tempRoot.path,
        isTestEnvironment: false,
      );

      final pages = [
        DocPage(
          id: 'p-1',
          title: 'iCloud Page',
          htmlContent: '<p>Cloud content</p>',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 2),
        ),
      ];

      await service.writePages('icloud:/DocumeWorkspace', pages);

      final restored = await service.readPages('icloud:/DocumeWorkspace');
      expect(restored.length, 1);
      expect(restored.first.id, 'p-1');
      expect(restored.first.title, 'iCloud Page');
    });
  });
}
