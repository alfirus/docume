import 'dart:convert';

class PageTemplate {
  const PageTemplate({
    required this.id,
    required this.name,
    required this.htmlContent,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final String htmlContent;
  final bool isBuiltIn;

  PageTemplate copyWith({
    String? id,
    String? name,
    String? htmlContent,
    bool? isBuiltIn,
  }) {
    return PageTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      htmlContent: htmlContent ?? this.htmlContent,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'htmlContent': htmlContent};
  }

  factory PageTemplate.fromMap(Map<String, dynamic> map) {
    return PageTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      htmlContent: map['htmlContent'] as String,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PageTemplate.fromJson(String source) {
    return PageTemplate.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}
