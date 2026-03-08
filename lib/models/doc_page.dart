import 'dart:convert';

class DocPage {
  const DocPage({
    required this.id,
    required this.title,
    required this.htmlContent,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String htmlContent;
  final DateTime createdAt;
  final DateTime updatedAt;

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
  }) {
    return DocPage(
      id: id ?? this.id,
      title: title ?? this.title,
      htmlContent: htmlContent ?? this.htmlContent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'htmlContent': htmlContent,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DocPage.fromMap(Map<String, dynamic> map) {
    final updatedAt = DateTime.parse(map['updatedAt'] as String);
    final createdAtRaw = map['createdAt'] as String?;

    return DocPage(
      id: map['id'] as String,
      title: map['title'] as String,
      htmlContent: map['htmlContent'] as String,
      createdAt: createdAtRaw == null ? updatedAt : DateTime.parse(createdAtRaw),
      updatedAt: updatedAt,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DocPage.fromJson(String source) =>
      DocPage.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
