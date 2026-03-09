import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/ai_command.dart';
import '../models/doc_page.dart';
import '../services/page_template_service.dart';
import '../utils/html_validator.dart';
import 'ai_provider_client.dart';

class AiCommandService {
  AiCommandService({AiProviderClient? providerClient})
      : _providerClient = providerClient ?? const AiProviderClient();

  final AiProviderClient _providerClient;
  final Uuid _uuid = const Uuid();

  Future<AiCommandPlan> buildPlan({
    required AiProviderSettings settings,
    required String prompt,
    required List<DocPage> pages,
  }) async {
    final contextJson = _buildContextJson(pages);
    final raw = await _providerClient.generateRawPlan(
      settings: settings,
      prompt: prompt,
      contextJson: contextJson,
    );

    final rootMap = _extractRootJson(raw);
    final summary = (rootMap['summary'] as String?)?.trim();
    final actionsRaw = rootMap['actions'];
    if (actionsRaw is! List) {
      throw const FormatException('AI response missing actions array.');
    }

    final actions = actionsRaw
        .map((entry) => AiAction.fromMap(entry as Map<String, dynamic>))
        .toList();

    if (actions.isEmpty) {
      throw const FormatException('AI returned no actions.');
    }

    return AiCommandPlan(
      summary: (summary == null || summary.isEmpty)
          ? 'AI generated ${actions.length} action(s).'
          : summary,
      actions: actions,
      rawText: raw,
    );
  }

  Future<List<DocPage>> applyPlan({
    required AiCommandPlan plan,
    required List<DocPage> pages,
    required PageTemplateService templateService,
    required Future<void> Function(AiExportFormat format) onExportAll,
  }) async {
    var updated = [...pages];

    for (final action in plan.actions) {
      switch (action.type) {
        case AiActionType.createPage:
          updated = _applyCreatePage(updated, action);
          break;
        case AiActionType.updatePage:
          updated = _applyUpdatePage(updated, action);
          break;
        case AiActionType.deletePage:
          updated = _applyDeletePage(updated, action);
          break;
        case AiActionType.createTemplate:
          await _applyCreateTemplate(templateService, action);
          break;
        case AiActionType.exportAll:
          final format = action.exportFormat;
          if (format == null) {
            throw const FormatException('export_all action missing format');
          }
          await onExportAll(format);
          break;
      }
    }

    return updated;
  }

  List<DocPage> _applyCreatePage(List<DocPage> pages, AiAction action) {
    final title = (action.title ?? '').trim();
    final html = (action.htmlContent ?? '').trim();
    if (title.isEmpty || html.isEmpty) {
      throw const FormatException('create_page requires title and htmlContent');
    }
    _assertValidHtml(html);

    final now = DateTime.now();
    final page = DocPage(
      id: _uuid.v4(),
      title: title,
      htmlContent: html,
      createdAt: now,
      updatedAt: now,
      parentId: _normalizeParentId(action.parentId),
      tags: _normalizeTags(action.tags),
    );

    if (page.parentId != null && !pages.any((entry) => entry.id == page.parentId)) {
      throw FormatException('create_page parentId does not exist: ${page.parentId}');
    }

    return [...pages, page];
  }

  List<DocPage> _applyUpdatePage(List<DocPage> pages, AiAction action) {
    final pageId = (action.pageId ?? '').trim();
    if (pageId.isEmpty) {
      throw const FormatException('update_page requires pageId');
    }

    final index = pages.indexWhere((page) => page.id == pageId);
    if (index == -1) {
      throw FormatException('update_page pageId not found: $pageId');
    }

    final current = pages[index];
    final html = action.htmlContent?.trim();
    if (html != null && html.isNotEmpty) {
      _assertValidHtml(html);
    }

    final parentId = _normalizeParentId(action.parentId);
    if (parentId != null) {
      if (!pages.any((entry) => entry.id == parentId)) {
        throw FormatException('update_page parentId does not exist: $parentId');
      }
      if (parentId == current.id) {
        throw const FormatException('update_page parentId cannot equal pageId');
      }
    }

    final updatedPage = current.copyWith(
      title: action.title?.trim().isNotEmpty == true
          ? action.title!.trim()
          : current.title,
      htmlContent: html?.isNotEmpty == true ? html : current.htmlContent,
      updatedAt: DateTime.now(),
      parentId: action.parentId == null ? current.parentId : parentId,
      tags: action.tags == null ? current.tags : _normalizeTags(action.tags),
    );

    final updated = [...pages];
    updated[index] = updatedPage;
    return updated;
  }

  List<DocPage> _applyDeletePage(List<DocPage> pages, AiAction action) {
    final pageId = (action.pageId ?? '').trim();
    if (pageId.isEmpty) {
      throw const FormatException('delete_page requires pageId');
    }

    if (!pages.any((page) => page.id == pageId)) {
      throw FormatException('delete_page pageId not found: $pageId');
    }

    final idsToDelete = _descendantIds(pages, pageId)..add(pageId);
    return pages.where((page) => !idsToDelete.contains(page.id)).toList();
  }

  Future<void> _applyCreateTemplate(
    PageTemplateService templateService,
    AiAction action,
  ) async {
    final name = (action.templateName ?? '').trim();
    final html = (action.htmlContent ?? '').trim();

    if (name.isEmpty || html.isEmpty) {
      throw const FormatException(
        'create_template requires templateName and htmlContent',
      );
    }

    _assertValidHtml(html);
    await templateService.saveTemplateFromData(name: name, htmlContent: html);
  }

  Set<String> _descendantIds(List<DocPage> pages, String pageId) {
    final descendants = <String>{};
    final queue = <String>[pageId];

    while (queue.isNotEmpty) {
      final currentId = queue.removeLast();
      for (final page in pages) {
        if (page.parentId == currentId && !descendants.contains(page.id)) {
          descendants.add(page.id);
          queue.add(page.id);
        }
      }
    }

    return descendants;
  }

  List<String> _normalizeTags(List<String>? tags) {
    if (tags == null) {
      return const [];
    }
    return tags
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet()
        .toList();
  }

  String? _normalizeParentId(String? parentId) {
    final trimmed = parentId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  void _assertValidHtml(String html) {
    final error = validateHtmlContent(html);
    if (error != null) {
      throw FormatException('Invalid HTML content: $error');
    }
  }

  String _buildContextJson(List<DocPage> pages) {
    final mapped = pages
        .map(
          (page) => {
            'id': page.id,
            'title': page.title,
            'parentId': page.parentId,
            'tags': page.tags,
            'updatedAt': page.updatedAt.toIso8601String(),
            // Send lightweight preview rather than full content in MVP.
            'htmlPreview': page.htmlContent.substring(
              0,
              page.htmlContent.length > 240 ? 240 : page.htmlContent.length,
            ),
          },
        )
        .toList();
    return jsonEncode({'pages': mapped});
  }

  Map<String, dynamic> _extractRootJson(String raw) {
    final trimmed = raw.trim();
    final fenceStart = trimmed.indexOf('```');
    if (fenceStart != -1) {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start != -1 && end > start) {
        final slice = trimmed.substring(start, end + 1);
        return jsonDecode(slice) as Map<String, dynamic>;
      }
    }

    return jsonDecode(trimmed) as Map<String, dynamic>;
  }
}
