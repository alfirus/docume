import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docume/screens/page_editor_screen.dart';
import 'package:docume/models/doc_page.dart';

void main() {
  group('WYSIWYG Editor Tests', () {
    testWidgets('Toggle button exists in editor', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      // Verify toggle button exists
      expect(find.byType(IconButton), findsAtLeast(1));
    });

    testWidgets('Editor mode toggles between WYSIWYG and HTML',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const  MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      // Find the toggle button (should be the first icon button in app bar)
      final toggleButton = find.byIcon(Icons.code).first;
      expect(toggleButton, findsOneWidget);

      // Tap to switch to HTML mode
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // After toggle, should show edit icon instead
      expect(find.byIcon(Icons.edit).first, findsOneWidget);
    });

    testWidgets('Can create page in WYSIWYG mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      // Enter title
      await tester.enterText(find.byType(TextField).first, 'Test Page');
      await tester.pumpAndSettle();

      // Note: Cannot easily test QuillEditor content entry in unit tests
      // as it requires more complex setup. This would be covered in integration tests.

      // Tap save - should pop with a page
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should have navigated back (no more scaffold)
      expect(find.byType(Scaffold), findsNothing);
    });

    testWidgets('Can edit existing page', (WidgetTester tester) async {
      final existingPage = DocPage(
        id: 'test-id',
        title: 'Existing Page',
        htmlContent: '<p>Test content</p>',
        createdAt: DateTime(2024,  1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PageEditorScreen(initialPage: existingPage),
        ),
      );

      // Verify title is populated
      expect(find.text('Existing Page'), findsOneWidget);

      // Verify app bar shows "Edit Page"
      expect(find.text('Edit Page'), findsOneWidget);
    });
  });
}
