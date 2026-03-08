import 'package:html/parser.dart' as html_parser;

String? validateHtmlContent(String html) {
  final trimmed = html.trim();

  if (trimmed.isEmpty) {
    return 'HTML content is required.';
  }

  if (!trimmed.contains('<') || !trimmed.contains('>')) {
    return 'Content must include HTML tags.';
  }

  final lower = trimmed.toLowerCase();
  if (lower.contains('<script') || lower.contains('</script>')) {
    return 'Script tags are not allowed in this MVP.';
  }

  final fragment = html_parser.parseFragment(trimmed);
  if (fragment.nodes.isEmpty) {
    return 'HTML content is invalid.';
  }

  return null;
}
