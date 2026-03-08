import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../models/doc_page.dart';

class PageViewScreen extends StatelessWidget {
  const PageViewScreen({
    super.key,
    required this.page,
    required this.onEdit,
  });

  final DocPage page;
  final VoidCallback onEdit;

  String _dateLabel(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(page.title),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Created ${_dateLabel(page.createdAt)} • Updated ${_dateLabel(page.updatedAt)} • ${page.wordCount} words',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              HtmlWidget(page.htmlContent),
            ],
          ),
        ),
      ),
    );
  }
}
