import 'package:flutter/material.dart';

import '../models/doc_page.dart';
import '../services/conflict_resolution_service.dart';

enum FieldMergeChoice { mine, remote, merged }

class ConflictMergeDialog extends StatefulWidget {
  const ConflictMergeDialog({
    super.key,
    required this.myPage,
    required this.remotePage,
    required this.onResolve,
  });

  final DocPage myPage;
  final DocPage remotePage;
  final Function(DocPage resolvedPage) onResolve;

  @override
  State<ConflictMergeDialog> createState() => _ConflictMergeDialogState();
}

class _ConflictMergeDialogState extends State<ConflictMergeDialog> {
  late FieldMergeChoice _titleChoice;
  late FieldMergeChoice _contentChoice;

  @override
  void initState() {
    super.initState();
    _titleChoice = FieldMergeChoice.mine;
    _contentChoice = FieldMergeChoice.mine;
  }

  DocPage _buildResolvedPage() {
    final ConflictResolutionService service = ConflictResolutionService();

    final resolvedTitle = switch (_titleChoice) {
      FieldMergeChoice.mine => widget.myPage.title,
      FieldMergeChoice.remote => widget.remotePage.title,
      FieldMergeChoice.merged =>
        '${widget.myPage.title} / ${widget.remotePage.title}',
    };

    final resolvedContent = switch (_contentChoice) {
      FieldMergeChoice.mine => widget.myPage.htmlContent,
      FieldMergeChoice.remote => widget.remotePage.htmlContent,
      FieldMergeChoice.merged => service.mergeHtmlContent(
        mine: widget.myPage.htmlContent,
        remote: widget.remotePage.htmlContent,
      ),
    };

    return widget.myPage.copyWith(
      title: resolvedTitle,
      htmlContent: resolvedContent,
      createdAt: widget.remotePage.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? 400 : 800,
          maxHeight: isMobile ? 800 : 600,
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Resolve Edit Conflict'),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This page was updated elsewhere while you were editing.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildFieldSelector(
                    label: 'Page Title',
                    myValue: widget.myPage.title,
                    remoteValue: widget.remotePage.title,
                    currentChoice: _titleChoice,
                    onChanged: (choice) {
                      setState(() => _titleChoice = choice);
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildFieldSelector(
                    label: 'Content',
                    myValue: _truncateHtml(widget.myPage.htmlContent),
                    remoteValue: _truncateHtml(widget.remotePage.htmlContent),
                    currentChoice: _contentChoice,
                    onChanged: (choice) {
                      setState(() => _contentChoice = choice);
                    },
                    isContent: true,
                  ),
                  const SizedBox(height: 24),
                  // Updated/Created timestamps
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hoverColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timestamps',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your version updated: ${widget.myPage.updatedAt}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Remote version updated: ${widget.remotePage.updatedAt}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final resolved = _buildResolvedPage();
                    Navigator.pop(context, resolved);
                  },
                  child: const Text('Resolve'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldSelector({
    required String label,
    required String myValue,
    required String remoteValue,
    required FieldMergeChoice currentChoice,
    required ValueChanged<FieldMergeChoice> onChanged,
    bool isContent = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        // Radio options
        Row(
          children: [
            Expanded(
              child: _buildChoiceOption(
                choice: FieldMergeChoice.mine,
                label: 'Keep Mine',
                currentChoice: currentChoice,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildChoiceOption(
                choice: FieldMergeChoice.remote,
                label: 'Keep Remote',
                currentChoice: currentChoice,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildChoiceOption(
                choice: FieldMergeChoice.merged,
                label: 'Merge',
                currentChoice: currentChoice,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Side-by-side comparison
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildComparisonBox(
                title: 'Your Version',
                content: myValue,
                isSelected: currentChoice == FieldMergeChoice.mine,
                isContent: isContent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildComparisonBox(
                title: 'Remote Version',
                content: remoteValue,
                isSelected: currentChoice == FieldMergeChoice.remote,
                isContent: isContent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceOption({
    required FieldMergeChoice choice,
    required String label,
    required FieldMergeChoice currentChoice,
    required ValueChanged<FieldMergeChoice> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(choice),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            // ignore: deprecated_member_use
            Radio<FieldMergeChoice>(
              value: choice,
              // ignore: deprecated_member_use
              groupValue: currentChoice,
              // ignore: deprecated_member_use
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonBox({
    required String title,
    required String content,
    required bool isSelected,
    required bool isContent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(
              maxHeight: isContent ? 150 : 100,
            ),
            child: SingleChildScrollView(
              child: Text(
                content,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: isContent ? null : 3,
                overflow: isContent ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncateHtml(String html) {
    const maxLength = 200;
    if (html.length > maxLength) {
      return '${html.substring(0, maxLength)}...';
    }
    return html;
  }
}
