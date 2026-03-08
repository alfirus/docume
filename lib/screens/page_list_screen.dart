import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../models/doc_page.dart';
import '../models/workspace_config.dart';
import '../services/conflict_resolution_service.dart';
import '../services/page_repository.dart';
import '../widgets/conflict_merge_dialog.dart';
import 'page_editor_screen.dart';
import 'page_view_screen.dart';

enum PageSort { newest, oldest, titleAsc }

enum PageBackupAction { exportJson, importJson }

class PageListScreen extends StatefulWidget {
  const PageListScreen({
    super.key,
    required this.workspaceConfig,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final WorkspaceConfig workspaceConfig;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<PageListScreen> createState() => _PageListScreenState();
}

class _PageListScreenState extends State<PageListScreen> {
  static const _desktopBreakpoint = 900.0;

  late final PageRepository _repository;
  final ConflictResolutionService _conflictResolutionService =
      ConflictResolutionService();
  final TextEditingController _searchController = TextEditingController();
  List<DocPage> _pages = [];
  bool _isLoading = true;
  String _searchQuery = '';
  PageSort _sort = PageSort.newest;
  String? _selectedPageId;

  @override
  void initState() {
    super.initState();
    _repository = PageRepository(workspaceConfig: widget.workspaceConfig);
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
    final updated = _pages.where((page) => page.id != id).toList();
    await _repository.savePages(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _pages = updated;
      if (_selectedPageId == id) {
        _selectedPageId = updated.isEmpty ? null : updated.first.id;
      }
    });
  }

  Future<void> _openEditor({DocPage? page}) async {
    final result = await Navigator.of(context).push<DocPage>(
      MaterialPageRoute(builder: (_) => PageEditorScreen(initialPage: page)),
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
      ],
      icon: const Icon(Icons.more_vert),
      tooltip: 'Backup options',
    );
  }

  ThemeMode get _nextThemeMode {
    return widget.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  Widget _buildThemeToggleButton() {
    final isDark = widget.themeMode == ThemeMode.dark;
    return IconButton(
      onPressed: () {
        widget.onThemeModeChanged(_nextThemeMode);
      },
      icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
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
    final filtered = query.isEmpty
        ? [..._pages]
        : _pages
              .where(
                (page) =>
                    page.title.toLowerCase().contains(query) ||
                    page.htmlContent.toLowerCase().contains(query),
              )
              .toList();
    _sortPages(filtered);
    return filtered;
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: pages.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final page = pages[index];
        return ListTile(
          selected: isDesktop && _selectedPageId == page.id,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: Text(page.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            'Updated ${_dateLabel(page.updatedAt)} • ${page.wordCount} words',
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
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deletePage(page.id),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(List<DocPage> pages) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Docume'),
        actions: [
          _buildThemeToggleButton(),
          _buildSortMenu(),
          _buildBackupMenu(),
        ],
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
                Expanded(child: _buildPageList(pages, isDesktop: false)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
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
          _buildThemeToggleButton(),
          _buildSortMenu(),
          _buildBackupMenu(),
          IconButton(
            onPressed: () => _openEditor(),
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
                      Expanded(child: _buildPageList(pages, isDesktop: true)),
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
