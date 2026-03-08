import 'package:flutter_quill/flutter_quill.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

/// Utility class for converting between HTML and Quill Delta format
class QuillHtmlConverterUtil {
  QuillHtmlConverterUtil._();

  /// Convert HTML string to Quill Document
  /// 
  /// Note: This is a basic conversion that extracts text content.
  /// For full HTML parsing, a more sophisticated library would be needed.
  static Document htmlToDocument(String html) {
    try {
      // Parse HTML to extract text content
      final document = html_parser.parse(html);
      final textContent = _extractTextWithFormatting(document.body);
      
      if (textContent.isEmpty) {
        return Document()..insert(0, '\n');
      }
      
      final doc = Document();
      doc.insert(0, textContent);
      return doc;
    } catch (e) {
      // If conversion fails, return a document with the HTML as plain text
      return Document()..insert(0, html);
    }
  }

  /// Extract text content from HTML while attempting to preserve basic formatting
  static String _extractTextWithFormatting(dom.Element? element) {
    if (element == null) return '';
    
    final buffer = StringBuffer();
    
    for (var node in element.nodes) {
      if (node is dom.Text) {
        buffer.write(node.text);
      } else if (node is dom.Element) {
        // Add newlines for block elements
        if (_isBlockElement(node.localName)) {
          buffer.write('\n');
        }
        buffer.write(_extractTextWithFormatting(node));
        if (_isBlockElement(node.localName)) {
          buffer.write('\n');
        }
      }
    }
    
    return buffer.toString();
  }

  /// Check if an HTML element is a block element
  static bool _isBlockElement(String? tagName) {
    const blockElements = {
      'div', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'ul', 'ol', 'li', 'section', 'article', 'header', 'footer',
      'blockquote', 'pre',
    };
    return blockElements.contains(tagName?.toLowerCase());
  }

  /// Convert Quill Document to HTML string
  static String documentToHtml(Document document) {
    try {
      final delta = document.toDelta();
      final json = delta.toJson();
      final converter = QuillDeltaToHtmlConverter(
        List.castFrom(json),
        ConverterOptions(
          multiLineParagraph: true,
          multiLineHeader: true,
          multiLineCodeblock: true,
          multiLineBlockquote: true,
        ),
      );
      return converter.convert();
    } catch (e) {
      // If conversion fails, return the plain text wrapped in a paragraph
      final plainText = document.toPlainText();
      return '<p>${_escapeHtml(plainText)}</p>';
    }
  }

  /// Escape HTML special characters
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Create an empty Quill Document with a paragraph
  static Document createEmptyDocument() {
    return Document()..insert(0, '\n');
  }
}
