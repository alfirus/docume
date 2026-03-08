import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:path_provider/path_provider.dart';

import '../models/doc_page.dart';
import '../models/page_template.dart';
import '../models/workspace_config.dart';
import '../services/conflict_resolution_service.dart';
import '../services/export_service.dart';
import '../services/page_repository.dart';
import '../services/page_template_service.dart';
import '../widgets/conflict_merge_dialog.dart';
import 'page_editor_screen.dart';
import 'page_view_screen.dart';

enum PageSort { newest, oldest, titleAsc }

enum PageBackupAction { exportJson, importJson, exportPdf, exportDocx, exportEpub }

enum PageCreationAction { blankPage, fromTemplate }

class _StructuredPageItem {
  const _StructuredPageItem({required this.page, required this.depth});

  final DocPage page;
  final int depth;
}

class _PageTreeNode {
  const _PageTreeNode({required this.page, required this.children});

  final DocPage page;
  final List<_PageTreeNode> children;
}

class PageListScreen extends StatefulWidget {
  const PageListScreen({
    super.key,
    required this.workspaceConfig,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onResetRequested,
  });

  final WorkspaceConfig workspaceConfig;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<void> Function() onResetRequested;

  @override
  State<PageListScreen> createState() => _PageListScreenState();
}

class _PageListScreenState extends State<PageListScreen> {
  static const _desktopBreakpoint = 900.0;

  late final PageRepository _repository;
  late final PageTemplateService _templateService;
  final ConflictResolutionService _conflictResolutionService =
      ConflictResolutionService();
  final TextEditingController _searchController = TextEditingController();
  List<DocPage> _pages = [];
  bool _isLoading = true;
  String _searchQuery = '';
  PageSort _sort = PageSort.newest;
  String? _selectedPageId;
  String? _selectedTag;
  final Set<String> _expandedPageIds = {};

  @override
  void initState() {
    super.initState();
    _repository = PageRepository(workspaceConfig: widget.workspaceConfig);
    _templateService = PageTemplateService(
      namespace: widget.workspaceConfig.namespace,
    );
    _loadPages();
  }

  Future<void> _loadPages() async {
    final pages = await _repository.getAllPages();
    if (!mounted) {
      return;
    }
    setState(() {
      _pages = pages;
      if (pages.isEmpty) {
        _selectedPageId = null;
      } else {
        _selectedPageId = pages.any((page) => page.id == _selectedPageId)
            ? _selectedPageId
            : pages.first.id;
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deletePage(String id) async {
    final idsToDelete = _descendantIds(id)..add(id);
    final updated = _pages
        .where((page) => !idsToDelete.contains(page.id))
        .toList();
    await _repository.savePages(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _pages = updated;
      if (_selectedPageId != null && idsToDelete.contains(_selectedPageId)) {
        _selectedPageId = updated.isEmpty ? null : updated.first.id;
      }
    });
  }

  Set<String> _descendantIds(String pageId) {
    final descendants = <String>{};
    final queue = <String>[pageId];

    while (queue.isNotEmpty) {
      final currentId = queue.removeLast();
      for (final page in _pages) {
        if (page.parentId == currentId && !descendants.contains(page.id)) {
          descendants.add(page.id);
          queue.add(page.id);
        }
      }
    }

    return descendants;
  }

  List<DocPage> _availableParentCandidates({DocPage? editingPage}) {
    var candidates = [..._pages];

    if (editingPage != null) {
      final disallowed = _descendantIds(editingPage.id)..add(editingPage.id);
      candidates = candidates
          .where((candidate) => !disallowed.contains(candidate.id))
          .toList();
    }

    candidates.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );

    return candidates;
  }

  Future<void> _openEditor({
    DocPage? page,
    String? suggestedParentId,
    String? initialHtmlContent,
  }) async {
    final result = await Navigator.of(context).push<DocPage>(
      MaterialPageRoute(
        builder: (_) => PageEditorScreen(
          initialPage: page,
          availableParentPages: _availableParentCandidates(editingPage: page),
          initialParentId: suggestedParentId,
          initialHtmlContent: initialHtmlContent,
          templateNamespace: widget.workspaceConfig.namespace,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    final latestPages = await _repository.getAllPages();
    var resolvedResult = result;

    if (page != null) {
      final remoteIndex = latestPages.indexWhere(
        (entry) => entry.id == page.id,
      );
      if (remoteIndex != -1) {
        final remotePage = latestPages[remoteIndex];
        final hasConflict = _conflictResolutionService.hasConflict(
          basePage: page,
          remotePage: remotePage,
        );

        if (hasConflict) {
          if (!mounted) {
            return;
          }
          final resolvedPage = await _showConflictDialog(
            myPage: result,
            remotePage: remotePage,
          );
          if (resolvedPage == null) {
            return;
          }
          resolvedResult = resolvedPage;
        }
      }
    }

    final validParentExists = latestPages.any(
      (entry) => entry.id == resolvedResult.parentId,
    );
    if (resolvedResult.parentId == resolvedResult.id ||
        (resolvedResult.parentId != null && !validParentExists)) {
      resolvedResult = resolvedResult.copyWith(parentId: null);
    }

    final existingIndex = latestPages.indexWhere(
      (entry) => entry.id == resolvedResult.id,
    );
    List<DocPage> updated;
    if (existingIndex == -1) {
      updated = [...latestPages, resolvedResult];
    } else {
      updated = [...latestPages];
      updated[existingIndex] = resolvedResult;
    }

    _sortPages(updated);
    await _repository.savePages(updated);

    if (!mounted) {
      return;
    }
    setState(() {
      _pages = updated;
      _selectedPageId = resolvedResult.id;
    });

    if (resolvedResult.htmlContent.contains('Merged conflict content')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conflict resolved and saved.')),
      );
    }
  }

  Future<DocPage?> _showConflictDialog({
    required DocPage myPage,
    required DocPage remotePage,
  }) {
    return showDialog<DocPage>(
      context: context,
      builder: (context) {
        return ConflictMergeDialog(
          myPage: myPage,
          remotePage: remotePage,
          onResolve: (resolvedPage) {
            Navigator.pop(context, resolvedPage);
          },
        );
      },
    );
  }

  Future<void> _openViewer(DocPage page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PageViewScreen(
          page: page,
          onEdit: () => _openEditor(page: page),
        ),
      ),
    );
    await _loadPages();
  }

  Future<void> _startCreatePageFlow() async {
    final action = await showDialog<PageCreationAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Page'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('Blank page'),
                subtitle: const Text('Start from an empty editor.'),
                onTap: () {
                  Navigator.of(context).pop(PageCreationAction.blankPage);
                },
              ),
              ListTile(
                leading: const Icon(Icons.book_outlined),
                title: const Text('From template'),
                subtitle: const Text('Start with a prebuilt structure.'),
                onTap: () {
                  Navigator.of(context).pop(PageCreationAction.fromTemplate);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (action == null) {
      return;
    }

    if (action == PageCreationAction.blankPage) {
      await _openEditor();
      return;
    }

    await _openEditorFromTemplate();
  }

  Future<void> _openEditorFromTemplate() async {
    final templates = await _templateService.getTemplates();
    if (!mounted) {
      return;
    }

    if (templates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No templates available.')));
      return;
    }

    final selectedTemplate = await showDialog<PageTemplate>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Template'),
          content: SizedBox(
            width: 520,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: templates.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final template = templates[index];
                return ListTile(
                  title: Text(template.name),
                  subtitle: Text(
                    template.isBuiltIn ? 'Built-in' : 'Custom',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.of(context).pop(template);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedTemplate == null) {
      return;
    }

    await _openEditor(initialHtmlContent: selectedTemplate.htmlContent);
  }

  String _encodePages(List<DocPage> pages) {
    final raw = pages.map((page) => page.toMap()).toList();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(raw);
  }

  List<DocPage> _decodePages(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Backup content must be a JSON array.');
    }

    final pages = decoded
        .map((entry) => DocPage.fromMap(entry as Map<String, dynamic>))
        .toList();

    pages.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return pages;
  }

  Future<void> _exportBackup() async {
    try {
      final json = _encodePages(_pages);
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup JSON copied to clipboard.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export failed: clipboard is unavailable.'),
        ),
      );
    }
  }

  Future<void> _importBackup() async {
    var importText = '';
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import Backup JSON'),
          content: SizedBox(
            width: 560,
            child: TextField(
              onChanged: (value) {
                importText = value;
              },
              maxLines: 12,
              decoration: const InputDecoration(
                hintText: '[{...}]',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    if (shouldImport != true) {
      return;
    }

    final input = importText.trim();

    if (input.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed: input is empty.')),
      );
      return;
    }

    try {
      final importedPages = _decodePages(input);
      await _repository.savePages(importedPages);
      if (!mounted) {
        return;
      }
      setState(() {
        _pages = importedPages;
        _selectedPageId = importedPages.isEmpty ? null : importedPages.first.id;
        _searchQuery = '';
        _searchController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${importedPages.length} page(s).')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed: invalid backup JSON.')),
      );
    }
  }

  Future<void> _exportAllPagesToPdf() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages to export.')),
      );
      return;
    }

    try {
      final exportService = ExportService();
      final filename = exportService.getSuggestedBulkFilename('pdf');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$filename';
      
      // Generate PDF
      await exportService.exportPagesToPdf(_pages, tempPath);
      
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
          SnackBar(content: Text('Exported ${_pages.length} page(s) to PDF.')),
        );
      }
      
      // Clean up temp file
      await File(tempPath).delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _exportAllPagesToDocx() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages to export.')),
      );
      return;
    }

    try {
      final exportService = ExportService();
      final filename = exportService.getSuggestedBulkFilename('docx');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$filename';
      
      // Generate DOCX
      await exportService.exportPagesToDocx(_pages, tempPath);
      
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
          SnackBar(content: Text('Exported ${_pages.length} page(s) to DOCX.')),
        );
      }
      
      // Clean up temp file
      await File(tempPath).delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _exportAllPagesToEpub() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages to export.')),
      );
      return;
    }

    try {
      final exportService = ExportService();
      final filename = exportService.getSuggestedBulkFilename('epub');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$filename';
      
      // Generate EPUB
      await exportService.exportPagesToEpub(
        _pages,
        tempPath,
        title: 'Docume Pages Export',
      );
      
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
          SnackBar(content: Text('Exported ${_pages.length} page(s) to EPUB.')),
        );
      }
      
      // Clean up temp file
      await File(tempPath).delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Widget _buildBackupMenu() {
    return PopupMenuButton<PageBackupAction>(
      onSelected: (action) {
        switch (action) {
          case PageBackupAction.exportJson:
            _exportBackup();
            break;
          case PageBackupAction.importJson:
            _importBackup();
            break;
          case PageBackupAction.exportPdf:
            _exportAllPagesToPdf();
            break;
          case PageBackupAction.exportDocx:
            _exportAllPagesToDocx();
            break;
          case PageBackupAction.exportEpub:
            _exportAllPagesToEpub();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: PageBackupAction.exportJson,
          child: Text('Export JSON'),
        ),
        PopupMenuItem(
          value: PageBackupAction.importJson,
          child: Text('Import JSON'),
        ),
        PopupMenuItem(
          value: PageBackupAction.exportPdf,
          child: Text('Export All to PDF'),
        ),
        PopupMenuItem(
          value: PageBackupAction.exportDocx,
          child: Text('Export All to DOCX'),
        ),
        PopupMenuItem(
          value: PageBackupAction.exportEpub,
          child: Text('Export All to EPUB'),
        ),
      ],
      icon: const Icon(Icons.more_vert),
      tooltip: 'Export options',
    );
  }

  ThemeMode get _nextThemeMode {
    return widget.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  Future<void> _confirmAndResetWorkspace() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset App?'),
          content: const Text(
            'This will delete all current pages and clear your workspace settings. '
            'You will need to choose a workspace again like first-time setup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) {
      return;
    }

    try {
      await _repository.savePages(const []);
      await widget.onResetRequested();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset failed. Please try again.')),
      );
    }
  }

  Future<void> _openSettingsDialog() async {
    final isDark = widget.themeMode == ThemeMode.dark;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Provider: ${widget.workspaceConfig.provider.label}'),
              const SizedBox(height: 4),
              Text(
                'Workspace: ${widget.workspaceConfig.directory}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDark ? 'Dark mode enabled' : 'Light mode enabled',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onThemeModeChanged(_nextThemeMode);
                      Navigator.of(context).pop();
                    },
                    child: Text(isDark ? 'Use Light' : 'Use Dark'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Danger Zone',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reset will remove all current pages and force workspace setup again.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmAndResetWorkspace();
              },
              child: const Text('Reset App'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsButton() {
    return IconButton(
      onPressed: _openSettingsDialog,
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
    );
  }

  String _dateLabel(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  DocPage? _selectedPage(List<DocPage> pages) {
    if (_selectedPageId == null) {
      return null;
    }
    for (final page in pages) {
      if (page.id == _selectedPageId) {
        return page;
      }
    }
    return null;
  }

  List<DocPage> _visiblePages() {
    final query = _searchQuery.trim().toLowerCase();
    var filtered = query.isEmpty
        ? [..._pages]
        : _pages
              .where(
                (page) =>
                    page.title.toLowerCase().contains(query) ||
                    page.htmlContent.toLowerCase().contains(query),
              )
              .toList();

    // Filter by selected tag if any
    if (_selectedTag != null) {
      filtered = filtered
          .where((page) => page.tags.contains(_selectedTag))
          .toList();
    }

    _sortPages(filtered);
    return filtered;
  }

  List<String> _allTags() {
    final tagSet = <String>{};
    for (final page in _pages) {
      tagSet.addAll(page.tags);
    }
    final tagList = tagSet.toList();
    tagList.sort();
    return tagList;
  }

  void _sortPages(List<DocPage> pages) {
    switch (_sort) {
      case PageSort.newest:
        pages.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case PageSort.oldest:
        pages.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case PageSort.titleAsc:
        pages.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
    }
  }

  String _sortLabel(PageSort sort) {
    switch (sort) {
      case PageSort.newest:
        return 'Newest';
      case PageSort.oldest:
        return 'Oldest';
      case PageSort.titleAsc:
        return 'Title A-Z';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _visiblePages();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
        return isDesktop
            ? _buildDesktopLayout(pages)
            : _buildMobileLayout(pages);
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Search pages',
        border: const OutlineInputBorder(),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              ),
      ),
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<PageSort>(
      initialValue: _sort,
      onSelected: (value) {
        setState(() {
          _sort = value;
        });
      },
      itemBuilder: (context) => [
        for (final option in PageSort.values)
          PopupMenuItem(value: option, child: Text(_sortLabel(option))),
      ],
      icon: const Icon(Icons.sort),
    );
  }

  Widget _buildTagFilter() {
    final tags = _allTags();
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('All'),
              selected: _selectedTag == null,
              onSelected: (selected) {
                setState(() {
                  _selectedTag = null;
                });
              },
            ),
            const SizedBox(width: 8),
            ...tags.map(
              (tag) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(tag),
                  selected: _selectedTag == tag,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTag = selected ? tag : null;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasChildren(String pageId) {
    return _pages.any((page) => page.parentId == pageId);
  }

  void _toggleExpanded(String pageId) {
    setState(() {
      if (_expandedPageIds.contains(pageId)) {
        _expandedPageIds.remove(pageId);
      } else {
        _expandedPageIds.add(pageId);
      }
    });
  }

  List<_StructuredPageItem> _structuredPages(List<DocPage> pages) {
    if (pages.isEmpty) {
      return const [];
    }

    final pageIds = pages.map((page) => page.id).toSet();
    final byParent = <String?, List<DocPage>>{};

    for (final page in pages) {
      final parentKey = page.parentId != null && pageIds.contains(page.parentId)
          ? page.parentId
          : null;
      byParent.putIfAbsent(parentKey, () => <DocPage>[]).add(page);
    }

    for (final entries in byParent.values) {
      _sortPages(entries);
    }

    final result = <_StructuredPageItem>[];
    final visited = <String>{};

    void appendBranch(String? parentId, int depth) {
      for (final child in byParent[parentId] ?? const <DocPage>[]) {
        if (visited.contains(child.id)) {
          continue;
        }
        visited.add(child.id);
        result.add(_StructuredPageItem(page: child, depth: depth));

        // Only show children if this node is expanded
        if (_expandedPageIds.contains(child.id)) {
          appendBranch(child.id, depth + 1);
        }
      }
    }

    appendBranch(null, 0);

    // Guard against unexpected cycles by appending any not-yet-visited pages.
    if (visited.length != pages.length) {
      for (final page in pages) {
        if (visited.add(page.id)) {
          result.add(_StructuredPageItem(page: page, depth: 0));
        }
      }
    }

    return result;
  }

  String? _parentTitle(String? parentId) {
    if (parentId == null) {
      return null;
    }
    for (final page in _pages) {
      if (page.id == parentId) {
        return page.title;
      }
    }
    return null;
  }

  List<_PageTreeNode> _buildTreeNodes(List<DocPage> pages) {
    final pageIds = pages.map((page) => page.id).toSet();
    final byParent = <String?, List<DocPage>>{};

    for (final page in pages) {
      final parentKey = page.parentId != null && pageIds.contains(page.parentId)
          ? page.parentId
          : null;
      byParent.putIfAbsent(parentKey, () => <DocPage>[]).add(page);
    }

    for (final entries in byParent.values) {
      _sortPages(entries);
    }

    final visited = <String>{};

    List<_PageTreeNode> buildBranch(String? parentId) {
      final result = <_PageTreeNode>[];
      for (final page in byParent[parentId] ?? const <DocPage>[]) {
        if (!visited.add(page.id)) {
          continue;
        }
        result.add(_PageTreeNode(page: page, children: buildBranch(page.id)));
      }
      return result;
    }

    final roots = buildBranch(null);

    // Guard against cycles or malformed relationships.
    if (visited.length != pages.length) {
      for (final page in pages) {
        if (visited.add(page.id)) {
          roots.add(_PageTreeNode(page: page, children: const []));
        }
      }
    }

    return roots;
  }

  bool _treeContainsPage(_PageTreeNode node, String pageId) {
    if (node.page.id == pageId) {
      return true;
    }
    for (final child in node.children) {
      if (_treeContainsPage(child, pageId)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildTreeDepthGuides(int depth) {
    if (depth <= 0) {
      return const SizedBox.shrink();
    }

    final guideColor = Theme.of(
      context,
    ).colorScheme.outline.withValues(alpha: 0.28);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        depth,
        (_) => SizedBox(
          width: 12,
          child: Center(
            child: Container(width: 1, height: 18, color: guideColor),
          ),
        ),
      ),
    );
  }

  Widget _buildTreeNodeActions(DocPage page) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_link_outlined),
          tooltip: 'New sub-page',
          onPressed: () => _openEditor(suggestedParentId: page.id),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete page',
          onPressed: () => _deletePage(page.id),
        ),
      ],
    );
  }

  Widget _buildTreeTitle({
    required DocPage page,
    required int depth,
    required bool isSelected,
  }) {
    return Row(
      children: [
        _buildTreeDepthGuides(depth),
        if (depth > 0) const SizedBox(width: 6),
        Expanded(
          child: Text(
            page.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isSelected
                ? Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _wrapTreeTile({required bool isSelected, required Widget child}) {
    final color = Theme.of(context).colorScheme.primaryContainer;
    final bgColor = isSelected
        ? color.withValues(alpha: 0.34)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildDesktopTreeItem(_PageTreeNode node, {required int depth}) {
    final page = node.page;
    final isSelected = _selectedPageId == page.id;
    final hasChildren = node.children.isNotEmpty;

    if (!hasChildren) {
      return _wrapTreeTile(
        isSelected: isSelected,
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          selected: isSelected,
          contentPadding: const EdgeInsets.only(left: 10, right: 6),
          title: _buildTreeTitle(
            page: page,
            depth: depth,
            isSelected: isSelected,
          ),
          subtitle: Text(
            'Updated ${_dateLabel(page.updatedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            setState(() {
              _selectedPageId = page.id;
            });
          },
          trailing: _buildTreeNodeActions(page),
        ),
      );
    }

    final shouldAutoExpand =
        _selectedPageId != null &&
        node.children.any(
          (child) => _treeContainsPage(child, _selectedPageId!),
        );
    final isExpanded = _expandedPageIds.contains(page.id) || shouldAutoExpand;

    return _wrapTreeTile(
      isSelected: isSelected,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('tree-${page.id}'),
          initiallyExpanded: isExpanded,
          maintainState: true,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          tilePadding: const EdgeInsets.only(left: 4, right: 6),
          childrenPadding: EdgeInsets.zero,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedPageIds.add(page.id);
              } else {
                _expandedPageIds.remove(page.id);
              }
            });
          },
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _selectedPageId = page.id;
              });
            },
            child: _buildTreeTitle(
              page: page,
              depth: depth,
              isSelected: isSelected,
            ),
          ),
          subtitle: Text(
            'Updated ${_dateLabel(page.updatedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _buildTreeNodeActions(page),
          children: [
            for (final child in node.children)
              _buildDesktopTreeItem(child, depth: depth + 1),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTreeList(List<DocPage> pages) {
    if (pages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _pages.isEmpty
                ? 'No pages yet. Tap + to create your first HTML page.'
                : 'No pages match your search.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final roots = _buildTreeNodes(pages);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final root in roots) _buildDesktopTreeItem(root, depth: 0),
      ],
    );
  }

  Widget _buildPageList(List<DocPage> pages, {required bool isDesktop}) {
    if (pages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _pages.isEmpty
                ? 'No pages yet. Tap + to create your first HTML page.'
                : 'No pages match your search.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final structuredPages = _structuredPages(pages);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: structuredPages.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = structuredPages[index];
        final page = item.page;
        final depth = item.depth;
        final parentTitle = _parentTitle(page.parentId);
        final hasChildren = _hasChildren(page.id);
        final isExpanded = _expandedPageIds.contains(page.id);

        return ListTile(
          selected: isDesktop && _selectedPageId == page.id,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: Row(
            children: [
              // Expand/collapse icon for pages with children
              if (hasChildren)
                SizedBox(
                  width: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 18,
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                    ),
                    onPressed: () => _toggleExpanded(page.id),
                  ),
                )
              else
                const SizedBox(width: 24),
              if (depth > 0) SizedBox(width: depth * 16),
              Expanded(
                child: Text(
                  page.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (parentTitle != null)
                Text(
                  'Sub-page of $parentTitle',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Text(
                'Updated ${_dateLabel(page.updatedAt)} • ${page.wordCount} words',
              ),
              if (page.tags.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: page.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          onTap: () {
            if (isDesktop) {
              setState(() {
                _selectedPageId = page.id;
              });
            } else {
              _openViewer(page);
            }
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_link_outlined),
                tooltip: 'New sub-page',
                onPressed: () => _openEditor(suggestedParentId: page.id),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deletePage(page.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(List<DocPage> pages) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Docume'),
        actions: [_buildSettingsButton(), _buildSortMenu(), _buildBackupMenu()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${widget.workspaceConfig.provider.label} • ${widget.workspaceConfig.directory}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _buildSearchField(),
                ),
                _buildTagFilter(),
                Expanded(child: _buildPageList(pages, isDesktop: false)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startCreatePageFlow,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDesktopLayout(List<DocPage> pages) {
    final selected = _selectedPage(pages);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Docume'),
        actions: [
          _buildSettingsButton(),
          _buildSortMenu(),
          _buildBackupMenu(),
          IconButton(
            onPressed: _startCreatePageFlow,
            icon: const Icon(Icons.add),
            tooltip: 'New Page',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Container(
                  width: 360,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${widget.workspaceConfig.provider.label} • ${widget.workspaceConfig.directory}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: _buildSearchField(),
                      ),
                      _buildTagFilter(),
                      Expanded(child: _buildDesktopTreeList(pages)),
                    ],
                  ),
                ),
                Expanded(
                  child: selected == null
                      ? const Center(
                          child: Text(
                            'Select a page to view its HTML content.',
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      selected.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _openEditor(page: selected),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_parentTitle(selected.parentId) != null)
                                Text(
                                  'Parent ${_parentTitle(selected.parentId)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              Text(
                                'Created ${_dateLabel(selected.createdAt)} • Updated ${_dateLabel(selected.updatedAt)} • ${selected.wordCount} words',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 16),
                              HtmlWidget(selected.htmlContent),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
