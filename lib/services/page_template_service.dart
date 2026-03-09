import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/page_template.dart';

class PageTemplateService {
  PageTemplateService({required String namespace}) : _namespace = namespace;

  final String _namespace;

  String get _storageKey {
    final encoded = base64Url.encode(utf8.encode(_namespace));
    return 'docume_templates_$encoded';
  }

  Future<List<PageTemplate>> getTemplates() async {
    final custom = await _readCustomTemplates();
    return [..._builtInTemplates, ...custom];
  }

  Future<void> saveTemplate(PageTemplate template) async {
    if (template.isBuiltIn) {
      return;
    }

    final custom = await _readCustomTemplates();
    final index = custom.indexWhere((entry) => entry.id == template.id);

    if (index == -1) {
      custom.add(template.copyWith(isBuiltIn: false));
    } else {
      custom[index] = template.copyWith(isBuiltIn: false);
    }

    await _writeCustomTemplates(custom);
  }

  Future<void> saveTemplateFromData({
    required String name,
    required String htmlContent,
  }) async {
    await saveTemplate(
      PageTemplate(
        id: const Uuid().v4(),
        name: name.trim(),
        htmlContent: htmlContent,
        isBuiltIn: false,
      ),
    );
  }

  Future<void> deleteTemplate(String templateId) async {
    final custom = await _readCustomTemplates();
    custom.removeWhere((entry) => entry.id == templateId);
    await _writeCustomTemplates(custom);
  }

  Future<List<PageTemplate>> _readCustomTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => PageTemplate.fromMap(entry as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCustomTemplates(List<PageTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = templates.map((entry) => entry.toMap()).toList();
    await prefs.setString(_storageKey, jsonEncode(payload));
  }
}

const List<PageTemplate> _builtInTemplates = [
  PageTemplate(
    id: 'builtin-meeting-notes',
    name: 'Meeting Notes',
    htmlContent:
        '<h1>Meeting Notes</h1>\n'
        '<p>Date: </p>\n'
        '<h2>Agenda</h2>\n'
        '<ul><li></li></ul>\n'
        '<h2>Discussion</h2>\n'
        '<p></p>\n'
        '<h2>Action Items</h2>\n'
        '<ul><li></li></ul>',
    isBuiltIn: true,
  ),
  PageTemplate(
    id: 'builtin-product-spec',
    name: 'Product Spec',
    htmlContent:
        '<h1>Product Spec</h1>\n'
        '<h2>Problem</h2>\n'
        '<p></p>\n'
        '<h2>Goals</h2>\n'
        '<ul><li></li></ul>\n'
        '<h2>Scope</h2>\n'
        '<p></p>\n'
        '<h2>Acceptance Criteria</h2>\n'
        '<ul><li></li></ul>',
    isBuiltIn: true,
  ),
  PageTemplate(
    id: 'builtin-journal',
    name: 'Journal Entry',
    htmlContent:
        '<h1>Journal Entry</h1>\n'
        '<p>Date: </p>\n'
        '<h2>Highlights</h2>\n'
        '<ul><li></li></ul>\n'
        '<h2>Reflections</h2>\n'
        '<p></p>\n'
        '<h2>Next Steps</h2>\n'
        '<ul><li></li></ul>',
    isBuiltIn: true,
  ),
];
