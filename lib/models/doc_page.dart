import 'dart:convert';

class DocPage {
  const DocPage({
    required this.id,
    required this.title,
    required this.htmlContent,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String htmlContent;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentId;
  final List<String> tags;

  int get wordCount {
    final textOnly = htmlContent
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (textOnly.isEmpty) {
      return 0;
    }
    return textOnly.split(' ').length;
  }

  DocPage copyWith({
    String? id,
    String? title,
    String? htmlContent,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? parentId = _noParentId,
    List<String>? tags,
  }) {
    return DocPage(
      id: id ?? this.id,
      title: title ?? this.title,
      htmlContent: htmlContent ?? this.htmlContent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentId: identical(parentId, _noParentId)
          ? this.parentId
          : parentId as String?,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'htmlContent': htmlContent,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'parentId': parentId,
      'tags': tags,
    };
  }

  factory DocPage.fromMap(Map<String, dynamic> map) {
    final updatedAt = DateTime.parse(map['updatedAt'] as String);
    final createdAtRaw = map['createdAt'] as String?;
    final tagsRaw = map['tags'] as List<dynamic>?;

    return DocPage(
      id: map['id'] as String,
      title: map['title'] as String,
      htmlContent: map['htmlContent'] as String,
      createdAt: createdAtRaw == null
          ? updatedAt
          : DateTime.parse(createdAtRaw),
      updatedAt: updatedAt,
      parentId: map['parentId'] as String?,
      tags: tagsRaw?.map((tag) => tag as String).toList() ?? [],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DocPage.fromJson(String source) =>
      DocPage.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

const _noParentId = Object();
