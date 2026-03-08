import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docume/screens/page_editor_screen.dart';
import 'package:docume/models/doc_page.dart';

void main() {
  group('WYSIWYG Editor Tests', () {
    testWidgets('Toggle button exists in editor', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        shad.ShadcnApp(
          title: 'Test',
          localizationsDelegates: const [
            ...FlutterQuillLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: FlutterQuillLocalizations.supportedLocales,
          home: PageEditorScreen(),
        ),
      );

      // Verify toggle button exists with tooltip
      expect(find.byTooltip('HTML Mode'), findsOneWidget);
    });

    testWidgets('Editor mode toggles between WYSIWYG and HTML',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        shad.ShadcnApp(
          title: 'Test',
          localizationsDelegates: const [
            ...FlutterQuillLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: FlutterQuillLocalizations.supportedLocales,
          home: PageEditorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find the toggle button by tooltip - initially shows "HTML Mode"
      expect(find.byTooltip('HTML Mode'), findsOneWidget);

      // Tap to switch to HTML mode
      await tester.tap(find.byTooltip('HTML Mode'));
      await tester.pumpAndSettle();

      // After toggle, should show WYSIWYG Mode tooltip
      expect(find.byTooltip('WYSIWYG Mode'), findsOneWidget);
      expect(find.byTooltip('HTML Mode'), findsNothing);
    });

    testWidgets('Can create page in WYSIWYG mode', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        shad.ShadcnApp(
          title: 'Test',
          localizationsDelegates: const [
            ...FlutterQuillLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: FlutterQuillLocalizations.supportedLocales,
          home: PageEditorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter title
      await tester.enterText(find.byType(TextField).first, 'Test Page');
      await tester.pumpAndSettle();

      // Note: Cannot easily test QuillEditor content entry in unit tests
      // as it requires more complex setup. This would be covered in integration tests.

      // Tap save - should pop with a page (via Navigator)
      final saveButton = find.widgetWithText(shad.PrimaryButton, 'Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Should have navigated back (we're not in a PageListScreen, so scaffold will be gone)
      expect(find.byType(PageEditorScreen), findsNothing);
    });

    testWidgets('Can edit existing page', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      final existingPage = DocPage(
        id: 'test-id',
        title: 'Existing Page',
        htmlContent: '<p>Test content</p>',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      await tester.pumpWidget(
        shad.ShadcnApp(
          title: 'Test',
          localizationsDelegates: const [
            ...FlutterQuillLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: FlutterQuillLocalizations.supportedLocales,
          home: PageEditorScreen(initialPage: existingPage),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title is populated
      expect(find.text('Existing Page'), findsOneWidget);

      // Verify app bar shows "Edit Page"
      expect(find.text('Edit Page'), findsOneWidget);
    });
  });
}
