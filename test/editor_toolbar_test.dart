import 'package:docume/screens/page_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Page Editor Toolbar Tests', () {
    testWidgets('H2 toolbar button exists', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      expect(find.text('H2'), findsOneWidget);
    });

    testWidgets('H3 toolbar button exists', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      expect(find.text('H3'), findsOneWidget);
    });

    testWidgets('H4 toolbar button exists', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      expect(find.text('H4'), findsOneWidget);
    });

    testWidgets('H5 toolbar button exists', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      expect(find.text('H5'), findsOneWidget);
    });

    testWidgets('H6 toolbar button exists', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      expect(find.text('H6'), findsOneWidget);
    });

    testWidgets('Section toolbar button exists', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Section'), findsOneWidget);
    });

    testWidgets('Link toolbar button exists', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      expect(find.text('Link'), findsOneWidget);
    });

    testWidgets('All toolbar buttons are visible in editor', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: PageEditorScreen(),
        ),
      );

      expect(find.text('Bold'), findsOneWidget);
      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);
      expect(find.text('H3'), findsOneWidget);
      expect(find.text('H4'), findsOneWidget);
      expect(find.text('H5'), findsOneWidget);
      expect(find.text('H6'), findsOneWidget);
      expect(find.text('Section'), findsOneWidget);
      expect(find.text('Link'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
    });
  });
}
