import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../models/doc_page.dart';
import '../utils/html_validator.dart';
import '../utils/quill_html_converter.dart';

enum EditorMode { wysiwyg, html }

class PageEditorScreen extends StatefulWidget {
  const PageEditorScreen({super.key, this.initialPage});

  final DocPage? initialPage;

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  static const _uuid = Uuid();

  late final TextEditingController _titleController;
  late final TextEditingController _htmlController;
  late final quill.QuillController _quillController;
  
  EditorMode _editorMode = EditorMode.wysiwyg;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialPage?.title ?? '');
    final htmlContent = widget.initialPage?.htmlContent ?? '<p></p>';
    _htmlController = TextEditingController(text: htmlContent);
    
    // Initialize Quill controller with HTML content converted to Delta
    final document = QuillHtmlConverterUtil.htmlToDocument(htmlContent);
    _quillController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _htmlController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  void _toggleEditorMode() {
    setState(() {
      if (_editorMode == EditorMode.wysiwyg) {
        // Convert Quill document to HTML before switching
        final html = QuillHtmlConverterUtil.documentToHtml(_quillController.document);
        _htmlController.text = html;
        _editorMode = EditorMode.html;
      } else {
        // Convert HTML to Quill document before switching
        final document = QuillHtmlConverterUtil.htmlToDocument(_htmlController.text);
        _quillController.document = document;
        _editorMode = EditorMode.wysiwyg;
      }
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    
    // Get HTML content based on current editor mode
    final html = _editorMode == EditorMode.wysiwyg
        ? QuillHtmlConverterUtil.documentToHtml(_quillController.document).trim()
        : _htmlController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }

    final htmlError = validateHtmlContent(html);
    if (htmlError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(htmlError)),
      );
      return;
    }

    final page = DocPage(
      id: widget.initialPage?.id ?? _uuid.v4(),
      title: title,
      htmlContent: html,
      createdAt: widget.initialPage?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(page);
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
    final selectedText = start == end ? placeholder : text.substring(start, end);
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
                    final updatedText = text.replaceRange(start, end, replacement);
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
          IconButton(
            icon: Icon(_editorMode == EditorMode.wysiwyg ? Icons.code : Icons.edit),
            onPressed: _toggleEditorMode,
            tooltip: _editorMode == EditorMode.wysiwyg ? 'HTML Mode' : 'WYSIWYG Mode',
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
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
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
                      _toolbarButton(
                        label: 'Link',
                        onPressed: _insertLink,
                      ),
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
                      hintText: '<h1>Hello</h1>\n<p>Write your content here</p>',
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
}
