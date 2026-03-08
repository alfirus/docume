import 'package:docume/utils/quill_html_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuillHtmlConverterUtil', () {
    test('preserves br line breaks when parsing html', () {
      const html =
          '<p><br/>This is 2nd page<br/>this page is for testing only</p>';

      final doc = QuillHtmlConverterUtil.htmlToDocument(html);
      final plain = doc.toPlainText();

      expect(plain.contains('This is 2nd page\nthis page is for testing only'), isTrue);
      expect(plain.contains('This is 2nd pagethis page is for testing only'), isFalse);
    });

    test('does not collapse neighboring lines during roundtrip', () {
      const html =
          '<p><br/>This is 2nd page<br/>this page is for testing only</p>';

      final doc = QuillHtmlConverterUtil.htmlToDocument(html);
      final roundtripHtml = QuillHtmlConverterUtil.documentToHtml(doc);

      expect(roundtripHtml.contains('This is 2nd pagethis page is for testing only'), isFalse);
      expect(roundtripHtml.contains('This is 2nd page'), isTrue);
      expect(roundtripHtml.contains('this page is for testing only'), isTrue);
    });
  });
}
