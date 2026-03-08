import 'package:docume/models/doc_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocPage tagging', () {
    test('DocPage can be created with tags', () {
      final page = DocPage(
        id: 'test-id',
        title: 'Test Page',
        htmlContent: '<p>Content</p>',
        createdAt: DateTime(2026, 3, 8),
        updatedAt: DateTime(2026, 3, 8),
        tags: ['tag1', 'tag2'],
      );

      expect(page.tags, ['tag1', 'tag2']);
    });

    test('DocPage defaults to empty tags list', () {
      final page = DocPage(
        id: 'test-id',
        title: 'Test Page',
        htmlContent: '<p>Content</p>',
        createdAt: DateTime(2026, 3, 8),
        updatedAt: DateTime(2026, 3, 8),
      );

      expect(page.tags, isEmpty);
    });

    test('DocPage serialization includes tags', () {
      final page = DocPage(
        id: 'test-id',
        title: 'Test Page',
        htmlContent: '<p>Content</p>',
        createdAt: DateTime(2026, 3, 8),
        updatedAt: DateTime(2026, 3, 8),
        tags: ['flutter', 'mobile'],
      );

      final map = page.toMap();
      expect(map['tags'], ['flutter', 'mobile']);
    });

    test('DocPage deserialization handles tags', () {
      final map = {
        'id': 'test-id',
        'title': 'Test Page',
        'htmlContent': '<p>Content</p>',
        'createdAt': DateTime(2026, 3, 8).toIso8601String(),
        'updatedAt': DateTime(2026, 3, 8).toIso8601String(),
        'tags': ['flutter', 'mobile'],
      };

      final page = DocPage.fromMap(map);
      expect(page.tags, ['flutter', 'mobile']);
    });

    test('DocPage deserialization handles missing tags', () {
      final map = {
        'id': 'test-id',
        'title': 'Test Page',
        'htmlContent': '<p>Content</p>',
        'createdAt': DateTime(2026, 3, 8).toIso8601String(),
        'updatedAt': DateTime(2026, 3, 8).toIso8601String(),
      };

      final page = DocPage.fromMap(map);
      expect(page.tags, isEmpty);
    });

    test('DocPage copyWith updates tags', () {
      final page = DocPage(
        id: 'test-id',
        title: 'Test Page',
        htmlContent: '<p>Content</p>',
        createdAt: DateTime(2026, 3, 8),
        updatedAt: DateTime(2026, 3, 8),
        tags: ['old-tag'],
      );

      final updated = page.copyWith(tags: ['new-tag', 'another-tag']);
      expect(updated.tags, ['new-tag', 'another-tag']);
    });

    test('DocPage JSON serialization roundtrip preserves tags', () {
      final original = DocPage(
        id: 'test-id',
        title: 'Test Page',
        htmlContent: '<p>Content</p>',
        createdAt: DateTime(2026, 3, 8),
        updatedAt: DateTime(2026, 3, 8),
        tags: ['flutter', 'dart', 'mobile'],
      );

      final json = original.toJson();
      final decoded = DocPage.fromJson(json);

      expect(decoded.id, original.id);
      expect(decoded.title, original.title);
      expect(decoded.htmlContent, original.htmlContent);
      expect(decoded.tags, ['flutter', 'dart', 'mobile']);
    });
  });
}
