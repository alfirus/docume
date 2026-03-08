import 'dart:convert';

import 'package:docume/models/page_template.dart';
import 'package:docume/services/page_template_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PageTemplateService', () {
    final namespace = 'local|/tmp/docume';
    final encodedNamespace = base64Url.encode(utf8.encode(namespace));
    final storageKey = 'docume_templates_$encodedNamespace';

    test('returns built-in templates by default', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PageTemplateService(namespace: namespace);

      final templates = await service.getTemplates();

      expect(templates.length, greaterThanOrEqualTo(3));
      expect(templates.any((entry) => entry.name == 'Meeting Notes'), isTrue);
      expect(templates.any((entry) => entry.isBuiltIn), isTrue);
    });

    test('saves and reads custom templates', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PageTemplateService(namespace: namespace);

      await service.saveTemplate(
        const PageTemplate(
          id: 'custom-1',
          name: 'My Template',
          htmlContent: '<h1>My Template</h1><p>Body</p>',
        ),
      );

      final templates = await service.getTemplates();

      expect(templates.any((entry) => entry.id == 'custom-1'), isTrue);
      expect(
        templates.where((entry) => entry.id == 'custom-1').first.isBuiltIn,
        isFalse,
      );
    });

    test('deletes custom templates but keeps built-ins', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode([
          {
            'id': 'custom-1',
            'name': 'Custom',
            'htmlContent': '<h1>Custom</h1>',
          },
        ]),
      });
      final service = PageTemplateService(namespace: namespace);

      await service.deleteTemplate('custom-1');
      await service.deleteTemplate('builtin-meeting-notes');

      final templates = await service.getTemplates();

      expect(templates.any((entry) => entry.id == 'custom-1'), isFalse);
      expect(
        templates.any((entry) => entry.id == 'builtin-meeting-notes'),
        isTrue,
      );
    });
  });
}
