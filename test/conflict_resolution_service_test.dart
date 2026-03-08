import 'package:docume/models/doc_page.dart';
import 'package:docume/services/conflict_resolution_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConflictResolutionService', () {
    final service = ConflictResolutionService();

    test('detects conflict when remote is newer than base', () {
      final base = DocPage(
        id: 'p1',
        title: 'Page',
        htmlContent: '<p>base</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 10),
      );
      final remote = base.copyWith(updatedAt: DateTime(2026, 3, 1, 11));

      expect(service.hasConflict(basePage: base, remotePage: remote), isTrue);
    });

    test('no conflict when timestamps are equal', () {
      final time = DateTime(2026, 3, 1, 10);
      final base = DocPage(
        id: 'p1',
        title: 'Page',
        htmlContent: '<p>base</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: time,
      );
      final remote = base.copyWith();

      expect(service.hasConflict(basePage: base, remotePage: remote), isFalse);
    });

    test('merge keeps both local and remote html content', () {
      final mine = DocPage(
        id: 'p1',
        title: 'Local Title',
        htmlContent: '<p>local</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 10),
      );
      final remote = DocPage(
        id: 'p1',
        title: 'Remote Title',
        htmlContent: '<p>remote</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 11),
      );

      final merged = service.resolve(
        mine: mine,
        remote: remote,
        choice: ConflictResolutionChoice.mergeBoth,
      );

      expect(merged.title, 'Local Title / Remote Title');
      expect(merged.htmlContent.contains('<p>local</p>'), isTrue);
      expect(merged.htmlContent.contains('<p>remote</p>'), isTrue);
      expect(merged.updatedAt.isAfter(mine.updatedAt), isTrue);
    });

    test('mergeHtmlContent combines both versions with markers', () {
      final merged = service.mergeHtmlContent(
        mine: '<p>local content</p>',
        remote: '<p>remote content</p>',
      );

      expect(merged.contains('<!-- Merged conflict content -->'), isTrue);
      expect(merged.contains('<h2>Local Version</h2>'), isTrue);
      expect(merged.contains('<p>local content</p>'), isTrue);
      expect(merged.contains('<hr/>'), isTrue);
      expect(merged.contains('<h2>Remote Version</h2>'), isTrue);
      expect(merged.contains('<p>remote content</p>'), isTrue);
    });
  });
}

