import 'package:docume/utils/html_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateHtmlContent', () {
    test('returns error for empty content', () {
      expect(validateHtmlContent('  '), 'HTML content is required.');
    });

    test('returns error when there are no tags', () {
      expect(validateHtmlContent('plain text only'), 'Content must include HTML tags.');
    });

    test('returns error for script tag', () {
      expect(
        validateHtmlContent('<script>alert(1)</script>'),
        'Script tags are not allowed in this MVP.',
      );
    });

    test('returns null for valid html', () {
      expect(validateHtmlContent('<h1>Hello</h1><p>World</p>'), isNull);
    });
  });
}
