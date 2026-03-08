import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../models/doc_page.dart';
import '../models/page_template.dart';
import '../services/error_logging_service.dart';
import '../services/export_service.dart';
import '../services/page_template_service.dart';
import '../utils/html_validator.dart';
import '../utils/quill_html_converter.dart';

enum EditorMode { wysiwyg, html }

enum PageExportAction { exportPdf, exportDocx, exportEpub }

class PageEditorScreen extends StatefulWidget {
  const PageEditorScreen({
    super.key,
    this.initialPage,
    this.availableParentPages = const [],
    this.initialParentId,
    this.initialHtmlContent,
    this.templateNamespace,
  });

  final DocPage? initialPage;
  final List<DocPage> availableParentPages;
  final String? initialParentId;
  final String? initialHtmlContent;
  final String? templateNamespace;

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  static const _uuid = Uuid();

  late final TextEditingController _htmlController;
  late final quill.QuillController _quillController;
  final TextEditingController _tagController = TextEditingController();
  late final PageTemplateService? _templateService;

  EditorMode _editorMode = EditorMode.wysiwyg;
  List<String> _tags = [];
  String? _selectedParentId;

  @override
  void initState() {
    super.initState();
    final htmlContent = _buildInitialHtmlContent();
    _htmlController = TextEditingController(text: htmlContent);
    _tags = List.from(widget.initialPage?.tags ?? []);
    _selectedParentId = widget.initialPage?.parentId ?? widget.initialParentId;
    _templateService = widget.templateNamespace == null
        ? null
        : PageTemplateService(namespace: widget.templateNamespace!);

    // Initialize Quill controller with HTML content converted to Delta
    final document = QuillHtmlConverterUtil.htmlToDocument(htmlContent);
    _quillController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _htmlController.dispose();
    _tagController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  String _buildInitialHtmlContent() {
    final initialPage = widget.initialPage;
    if (initialPage == null) {
      final initialTemplateHtml = widget.initialHtmlContent?.trim();
      if (initialTemplateHtml != null && initialTemplateHtml.isNotEmpty) {
        return initialTemplateHtml;
      }
      return '<h1></h1>\n<p></p>';
    }

    final existingHtml = initialPage.htmlContent.trim();
    if (existingHtml.isEmpty) {
      return '<h1>${_escapeHtml(initialPage.title)}</h1>\n<p></p>';
    }

    final document = QuillHtmlConverterUtil.htmlToDocument(existingHtml);
    final firstLine = _extractFirstNonEmptyLine(document);

    if (firstLine == initialPage.title.trim()) {
      return existingHtml;
    }

    return '<h1>${_escapeHtml(initialPage.title)}</h1>\n$existingHtml';
  }

  String _currentHtmlContent() {
    if (_editorMode == EditorMode.wysiwyg) {
      return QuillHtmlConverterUtil.documentToHtml(
        _quillController.document,
      ).trim();
    }

    return _htmlController.text.trim();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _extractFirstNonEmptyLine(quill.Document document) {
    final lines = document
        .toPlainText()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    return lines.isEmpty ? '' : lines.first;
  }

  void _toggleEditorMode() {
    setState(() {
      if (_editorMode == EditorMode.wysiwyg) {
        // Convert Quill document to HTML before switching
        final html = QuillHtmlConverterUtil.documentToHtml(
          _quillController.document,
        );
        _htmlController.text = html;
        _editorMode = EditorMode.html;
      } else {
        // Convert HTML to Quill document before switching
        final document = QuillHtmlConverterUtil.htmlToDocument(
          _htmlController.text,
        );
        _quillController.document = document;
        _editorMode = EditorMode.wysiwyg;
      }
    });
  }

  void _save() {
    final html = _currentHtmlContent();

    final title = _extractFirstNonEmptyLine(
      QuillHtmlConverterUtil.htmlToDocument(html),
    );

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required.')));
      return;
    }

    final htmlError = validateHtmlContent(html);
    if (htmlError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(htmlError)));
      return;
    }

    final page = DocPage(
      id: widget.initialPage?.id ?? _uuid.v4(),
      title: title,
      htmlContent: html,
      createdAt: widget.initialPage?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      parentId: _selectedParentId,
      tags: _tags,
    );

    Navigator.of(context).pop(page);
  }

  Future<void> _saveAsTemplate() async {
    final templateService = _templateService;
    if (templateService == null) {
      return;
    }

    final html = _currentHtmlContent();
    final htmlError = validateHtmlContent(html);
    if (htmlError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Template not saved: $htmlError')));
      return;
    }

    final suggestedName = _extractFirstNonEmptyLine(
      QuillHtmlConverterUtil.htmlToDocument(html),
    );

    final nameController = TextEditingController(text: suggestedName);
    final templateName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save as Template'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Template name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = nameController.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Save Template'),
            ),
          ],
        );
      },
    );

    nameController.dispose();

    if (templateName == null || templateName.isEmpty) {
      return;
    }

    final template = PageTemplate(
      id: _uuid.v4(),
      name: templateName,
      htmlContent: html,
    );

    await templateService.saveTemplate(template);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Template "$templateName" saved.')));
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _wrapSelection({
    required String prefix,
    required String suffix,
    String placeholder = 'text',
  }) {
    final text = _htmlController.text;
    final selection = _htmlController.selection;

    if (!selection.isValid) {
      _htmlController.text = '$text$prefix$placeholder$suffix';
      _htmlController.selection = TextSelection.collapsed(
        offset: _htmlController.text.length,
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final selectedText = start == end
        ? placeholder
        : text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';
    final updatedText = text.replaceRange(start, end, replacement);
    _htmlController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _insertLink() {
    showDialog<String>(
      context: context,
      builder: (context) {
        final urlController = TextEditingController();
        return AlertDialog(
          title: const Text('Insert Link'),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  final text = _htmlController.text;
                  final selection = _htmlController.selection;

                  if (!selection.isValid) {
                    _wrapSelection(
                      prefix: '<a href="$url">',
                      suffix: '</a>',
                      placeholder: 'link text',
                    );
                  } else {
                    final start = selection.start;
                    final end = selection.end;
                    final selectedText = text.substring(start, end);
                    final replacement = '<a href="$url">$selectedText</a>';
                    final updatedText = text.replaceRange(
                      start,
                      end,
                      replacement,
                    );
                    _htmlController.value = TextEditingValue(
                      text: updatedText,
                      selection: TextSelection.collapsed(
                        offset: start + replacement.length,
                      ),
                    );
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Insert'),
            ),
          ],
        );
      },
    );
  }

  Widget _toolbarButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return shad.OutlineButton(
      onPressed: onPressed,
      density: shad.ButtonDensity.compact,
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialPage == null ? 'New Page' : 'Edit Page'),
        actions: [
          if (widget.initialPage != null)
            PopupMenuButton<PageExportAction>(
              onSelected: (action) {
                switch (action) {
                  case PageExportAction.exportPdf:
                    _exportPageToPdf();
                    break;
                  case PageExportAction.exportDocx:
                    _exportPageToDocx();
                    break;
                  case PageExportAction.exportEpub:
                    _exportPageToEpub();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: PageExportAction.exportPdf,
                  child: Text('Export to PDF'),
                ),
                PopupMenuItem(
                  value: PageExportAction.exportDocx,
                  child: Text('Export to DOCX'),
                ),
                PopupMenuItem(
                  value: PageExportAction.exportEpub,
                  child: Text('Export to EPUB'),
                ),
              ],
              icon: const Icon(Icons.download),
              tooltip: 'Export page',
            ),
          if (_templateService != null)
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: 'Save as template',
              onPressed: _saveAsTemplate,
            ),
          IconButton(
            icon: Icon(
              _editorMode == EditorMode.wysiwyg ? Icons.code : Icons.edit,
            ),
            onPressed: _toggleEditorMode,
            tooltip: _editorMode == EditorMode.wysiwyg
                ? 'HTML Mode'
                : 'WYSIWYG Mode',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: shad.PrimaryButton(
              onPressed: _save,
              density: shad.ButtonDensity.compact,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedParentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Parent Page (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No parent (top-level page)'),
                  ),
                  ...widget.availableParentPages.map(
                    (page) => DropdownMenuItem<String>(
                      value: page.id,
                      child: Text(
                        page.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedParentId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addTag(),
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'Add tags (press Enter)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  shad.OutlineButton(
                    onPressed: _addTag,
                    density: shad.ButtonDensity.compact,
                    child: const Text('Add'),
                  ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          onDeleted: () => _removeTag(tag),
                          deleteIcon: const Icon(Icons.close, size: 18),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              if (_editorMode == EditorMode.html) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _toolbarButton(
                        label: 'Bold',
                        onPressed: () => _wrapSelection(
                          prefix: '<strong>',
                          suffix: '</strong>',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _toolbarButton(
                        label: 'H1',
                        onPressed: () => _wrapSelection(
                          prefix: '<h1>',
                          suffix: '</h1>',
                          placeholder: 'Heading',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _toolbarButton(
                        label: 'H2',
                        onPressed: () => _wrapSelection(
                          prefix: '<h2>',
                          suffix: '</h2>',
                          placeholder: 'Heading',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _toolbarButton(
                        label: 'H3',
                        onPressed: () => _wrapSelection(
                          prefix: '<h3>',
                          suffix: '</h3>',
                          placeholder: 'Heading',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _toolbarButton(
                        label: 'H4',
                        onPressed: () => _wrapSelection(
                          prefix: '<h4>',
                          suffix: '</h4>',
                          placeholder: 'Heading',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _toolbarButton(
                        label: 'H5',
                        onPressed: () => _wrapSelection(
                          prefix: '<h5>',
                          suffix: '</h5>',
                          placeholder: 'Heading',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _toolbarButton(
                        label: 'H6',
                        onPressed: () => _wrapSelection(
                          prefix: '<h6>',
                          suffix: '</h6>',
                          placeholder: 'Heading',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _toolbarButton(
                        label: 'Section',
                        onPressed: () => _wrapSelection(
                          prefix: '<section>\n  ',
                          suffix: '\n</section>',
                          placeholder: 'Content',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _toolbarButton(label: 'Link', onPressed: _insertLink),
                      const SizedBox(width: 8),
                      _toolbarButton(
                        label: 'List',
                        onPressed: () => _wrapSelection(
                          prefix: '<ul>\n  <li>',
                          suffix: '</li>\n</ul>',
                          placeholder: 'Item',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _htmlController,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'HTML Content',
                      hintText:
                          '<h1>Hello</h1>\n<p>Write your content here</p>',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ] else ...[
                quill.QuillSimpleToolbar(
                  controller: _quillController,
                  config: const quill.QuillSimpleToolbarConfig(
                    showBoldButton: true,
                    showItalicButton: true,
                    showUnderLineButton: true,
                    showStrikeThrough: true,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showClearFormat: true,
                    showLeftAlignment: true,
                    showCenterAlignment: true,
                    showRightAlignment: true,
                    showHeaderStyle: true,
                    showListBullets: true,
                    showListNumbers: true,
                    showListCheck: true,
                    showCodeBlock: true,
                    showQuote: true,
                    showIndent: true,
                    showLink: true,
                    showUndo: true,
                    showRedo: true,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: quill.QuillEditor.basic(
                      controller: _quillController,
                      config: const quill.QuillEditorConfig(
                        placeholder: 'Write your content here...',
                        padding: EdgeInsets.all(16),
                        checkBoxReadOnly: false,
                        autoFocus: false,
                        expands: false,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPageToPdf() async {
    if (widget.initialPage == null) return;

    try {
      final exportService = ExportService();
      final page = widget.initialPage!;
      final filename = exportService.getSuggestedFilename(page, 'pdf');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$filename';
      
      // Generate PDF
      await exportService.exportPageToPdf(page, tempPath);
      
      // Save file using file picker
      final savePath = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'PDF',
            extensions: ['pdf'],
          ),
        ],
      );
      
      if (savePath != null) {
        final bytes = await File(tempPath).readAsBytes();
        await File(savePath.path).writeAsBytes(bytes);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page exported to PDF.')),
        );
      }
      
      // Clean up temp file
      await File(tempPath).delete();
    } catch (e, stackTrace) {
      await ErrorLoggingService().logError(
        e,
        stackTrace,
        context: 'Single page export to PDF failed',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _exportPageToDocx() async {
    if (widget.initialPage == null) return;

    try {
      final exportService = ExportService();
      final page = widget.initialPage!;
      final filename = exportService.getSuggestedFilename(page, 'docx');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$filename';
      
      // Generate DOCX
      await exportService.exportPageToDocx(page, tempPath);
      
      // Save file using file picker
      final savePath = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Word Document',
            extensions: ['docx'],
          ),
        ],
      );
      
      if (savePath != null) {
        final bytes = await File(tempPath).readAsBytes();
        await File(savePath.path).writeAsBytes(bytes);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page exported to DOCX.')),
        );
      }
      
      // Clean up temp file
      await File(tempPath).delete();
    } catch (e, stackTrace) {
      await ErrorLoggingService().logError(
        e,
        stackTrace,
        context: 'Single page export to DOCX failed',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _exportPageToEpub() async {
    if (widget.initialPage == null) return;

    try {
      final exportService = ExportService();
      final page = widget.initialPage!;
      final filename = exportService.getSuggestedFilename(page, 'epub');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$filename';
      
      // Generate EPUB
      await exportService.exportPageToEpub(page, tempPath);
      
      // Save file using file picker
      final savePath = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'EPUB',
            extensions: ['epub'],
          ),
        ],
      );
      
      if (savePath != null) {
        final bytes = await File(tempPath).readAsBytes();
        await File(savePath.path).writeAsBytes(bytes);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page exported to EPUB.')),
        );
      }
      
      // Clean up temp file
      await File(tempPath).delete();
    } catch (e, stackTrace) {
      await ErrorLoggingService().logError(
        e,
        stackTrace,
        context: 'Single page export to EPUB failed',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}
