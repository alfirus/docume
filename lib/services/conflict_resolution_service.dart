import '../models/doc_page.dart';

enum ConflictResolutionChoice { keepMine, keepRemote, mergeBoth }

class ConflictResolutionService {
  bool hasConflict({required DocPage basePage, required DocPage remotePage}) {
    return remotePage.updatedAt.isAfter(basePage.updatedAt);
  }

  DocPage resolve({
    required DocPage mine,
    required DocPage remote,
    required ConflictResolutionChoice choice,
  }) {
    switch (choice) {
      case ConflictResolutionChoice.keepMine:
        return mine;
      case ConflictResolutionChoice.keepRemote:
        return remote;
      case ConflictResolutionChoice.mergeBoth:
        return _merge(mine: mine, remote: remote);
    }
  }

  DocPage _merge({required DocPage mine, required DocPage remote}) {
    final mergedTitle = mine.title == remote.title
        ? mine.title
        : '${mine.title} / ${remote.title}';

    final mergedHtml = [
      '<!-- Merged conflict content -->',
      '<h2>Local Version</h2>',
      mine.htmlContent,
      '<hr/>',
      '<h2>Remote Version</h2>',
      remote.htmlContent,
    ].join('\n');

    return mine.copyWith(
      title: mergedTitle,
      htmlContent: mergedHtml,
      createdAt: remote.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String mergeHtmlContent({required String mine, required String remote}) {
    return [
      '<!-- Merged conflict content -->',
      '<h2>Local Version</h2>',
      mine,
      '<hr/>',
      '<h2>Remote Version</h2>',
      remote,
    ].join('\n');
  }
}
