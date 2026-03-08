import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/doc_page.dart';
import '../utils/html_validator.dart';

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialPage?.title ?? '');
    _htmlController = TextEditingController(
      text: widget.initialPage?.htmlContent ?? '<p></p>',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _htmlController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final html = _htmlController.text.trim();

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

  Widget _toolbarButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialPage == null ? 'New Page' : 'Edit Page'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
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
            ],
          ),
        ),
      ),
    );
  }
}
