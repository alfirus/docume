import 'package:docume/screens/page_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Page Editor Toolbar Tests', () {
    testWidgets('Editor mode toggle button exists', (WidgetTester tester) async {
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

      // WYSIWYG mode is default, so code icon with tooltip should be visible
      expect(find.byTooltip('HTML Mode'), findsOneWidget);
    });

    testWidgets('Can toggle between WYSIWYG and HTML modes', (WidgetTester tester) async {
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

      // Initially in WYSIWYG mode - HTML Mode tooltip visible
      expect(find.byTooltip('HTML Mode'), findsOneWidget);
      expect(find.byTooltip('WYSIWYG Mode'), findsNothing);

      // Toggle to HTML mode
      await tester.tap(find.byTooltip('HTML Mode'));
      await tester.pumpAndSettle();

      // Now in HTML mode - WYSIWYG Mode tooltip visible
      expect(find.byTooltip('WYSIWYG Mode'), findsOneWidget);
      expect(find.byTooltip('HTML Mode'), findsNothing);

      // Toggle back to WYSIWYG
      await tester.tap(find.byTooltip('WYSIWYG Mode'));
      await tester.pumpAndSettle();

      // Back in WYSIWYG mode
      expect(find.byTooltip('HTML Mode'), findsOneWidget);
      expect(find.byTooltip('WYSIWYG Mode'), findsNothing);
    });

    testWidgets('Save button is visible', (WidgetTester tester) async {
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

      expect(find.widgetWithText(shad.PrimaryButton, 'Save'), findsOneWidget);
    });
  });
}
