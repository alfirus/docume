enum AiProvider { opencode, openclaw, claude }

extension AiProviderX on AiProvider {
  String get value {
    switch (this) {
      case AiProvider.opencode:
        return 'opencode';
      case AiProvider.openclaw:
        return 'openclaw';
      case AiProvider.claude:
        return 'claude';
    }
  }

  String get label {
    switch (this) {
      case AiProvider.opencode:
        return 'OpenCode';
      case AiProvider.openclaw:
        return 'OpenClaw';
      case AiProvider.claude:
        return 'Claude';
    }
  }

  static AiProvider? fromValue(String value) {
    for (final provider in AiProvider.values) {
      if (provider.value == value) {
        return provider;
      }
    }
    return null;
  }
}

enum AiActionType {
  createPage,
  updatePage,
  deletePage,
  createTemplate,
  exportAll,
}

extension AiActionTypeX on AiActionType {
  String get value {
    switch (this) {
      case AiActionType.createPage:
        return 'create_page';
      case AiActionType.updatePage:
        return 'update_page';
      case AiActionType.deletePage:
        return 'delete_page';
      case AiActionType.createTemplate:
        return 'create_template';
      case AiActionType.exportAll:
        return 'export_all';
    }
  }

  static AiActionType? fromValue(String value) {
    for (final type in AiActionType.values) {
      if (type.value == value) {
        return type;
      }
    }
    return null;
  }
}

enum AiExportFormat { pdf, docx, epub }

extension AiExportFormatX on AiExportFormat {
  String get value {
    switch (this) {
      case AiExportFormat.pdf:
        return 'pdf';
      case AiExportFormat.docx:
        return 'docx';
      case AiExportFormat.epub:
        return 'epub';
    }
  }

  static AiExportFormat? fromValue(String value) {
    for (final format in AiExportFormat.values) {
      if (format.value == value) {
        return format;
      }
    }
    return null;
  }
}

class AiAction {
  const AiAction({
    required this.type,
    this.pageId,
    this.title,
    this.htmlContent,
    this.parentId,
    this.tags,
    this.templateName,
    this.exportFormat,
  });

  final AiActionType type;
  final String? pageId;
  final String? title;
  final String? htmlContent;
  final String? parentId;
  final List<String>? tags;
  final String? templateName;
  final AiExportFormat? exportFormat;

  factory AiAction.fromMap(Map<String, dynamic> map) {
    final typeRaw = map['type'] as String?;
    final type = typeRaw == null ? null : AiActionTypeX.fromValue(typeRaw);
    if (type == null) {
      throw FormatException('Unknown AI action type: $typeRaw');
    }

    final tagsRaw = map['tags'];
    return AiAction(
      type: type,
      pageId: map['pageId'] as String?,
      title: map['title'] as String?,
      htmlContent: map['htmlContent'] as String?,
      parentId: map['parentId'] as String?,
      tags: tagsRaw is List
          ? tagsRaw.map((entry) => entry.toString()).toList()
          : null,
      templateName: map['templateName'] as String?,
      exportFormat: map['format'] is String
          ? AiExportFormatX.fromValue(map['format'] as String)
          : null,
    );
  }

  String toHumanLabel() {
    switch (type) {
      case AiActionType.createPage:
        return 'Create page: ${title ?? '(untitled)'}';
      case AiActionType.updatePage:
        return 'Update page: ${pageId ?? '(missing id)'}';
      case AiActionType.deletePage:
        return 'Delete page: ${pageId ?? '(missing id)'}';
      case AiActionType.createTemplate:
        return 'Create template: ${templateName ?? '(unnamed)'}';
      case AiActionType.exportAll:
        return 'Export all pages: ${exportFormat?.value ?? '(missing format)'}';
    }
  }
}

class AiCommandPlan {
  const AiCommandPlan({
    required this.summary,
    required this.actions,
    required this.rawText,
  });

  final String summary;
  final List<AiAction> actions;
  final String rawText;
}

class AiProviderSettings {
  const AiProviderSettings({
    required this.provider,
    required this.endpoint,
    required this.model,
    required this.apiKey,
  });

  final AiProvider provider;
  final String endpoint;
  final String model;
  final String apiKey;

    bool get requiresModel => provider != AiProvider.openclaw;

  bool get isConfigured =>
      endpoint.trim().isNotEmpty &&
      (!requiresModel || model.trim().isNotEmpty) &&
      apiKey.trim().isNotEmpty;
}
