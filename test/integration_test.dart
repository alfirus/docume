import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import 'package:docume/main.dart';

void main() {
  const provider = 'icloud';
  const directory = 'icloud:/DocumeWorkspace';
  final namespace = '$provider|$directory';
  final storageKey = 'docume_pages_${base64Url.encode(utf8.encode(namespace))}';

  Future<void> pumpUntilVisible(
    WidgetTester tester,
    Finder finder,
  ) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
  }

  Future<void> pumpWithSize(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DocumeApp());
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Mobile Integration Tests', () {
    testWidgets('create and delete page flow on mobile', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'workspace_provider': provider,
        'workspace_directory': directory,
        storageKey: jsonEncode([]),
      });

      await pumpWithSize(tester, size: const Size(390, 844));
      await pumpUntilVisible(tester, find.text('Docume'));

      const emptyMessage = 'No pages yet. Tap + to create your first HTML page.';
      await pumpUntilVisible(tester, find.text(emptyMessage));
      expect(find.text(emptyMessage), findsOneWidget);

      // Create a new page
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.text('New Page'), findsOneWidget);

      // Toggle to HTML mode for easier testing - use tooltip to find
      final toggleButton = find.byTooltip('HTML Mode');
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Fill in title and content
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'Integration Test Page');
      await tester.pumpAndSettle();

      final contentField = find.byType(TextField).last;
      await tester.enterText(contentField, '<p>Test content</p>');
      await tester.pumpAndSettle();

      // Save
      final saveButton = find.widgetWithText(shad.PrimaryButton, 'Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify page appears in list
      await pumpUntilVisible(tester, find.text('Integration Test Page'));
      expect(find.text('Integration Test Page'), findsOneWidget);

      // Delete the page
      final deleteButton = find.byIcon(Icons.delete_outline);
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Wait for empty state to return
      await pumpUntilVisible(tester, find.text(emptyMessage));
      expect(find.text(emptyMessage), findsOneWidget);
    });

    testWidgets('invalid backup import does not replace existing page on mobile', (
      WidgetTester tester,
    ) async {
      final createdAt = DateTime(2026, 3, 1).toIso8601String();
      final updatedAt = DateTime(2026, 3, 2).toIso8601String();

      SharedPreferences.setMockInitialValues({
        'workspace_provider': provider,
        'workspace_directory': directory,
        storageKey: jsonEncode([
          {
            'id': 'initial-1',
            'title': 'Initial Page',
            'htmlContent': '<p>Existing page</p>',
            'createdAt': createdAt,
            'updatedAt': updatedAt,
          },
        ]),
      });

      await pumpWithSize(tester, size: const Size(390, 844));
      await pumpUntilVisible(tester, find.text('Initial Page'));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import JSON'));
      await tester.pumpAndSettle();

      // The import flow only accepts a JSON array of page objects.
      await tester.enterText(find.byType(TextField).last, '{"id":"bad-shape"}');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Import'));
      await tester.pumpAndSettle();

      expect(find.text('Import failed: invalid backup JSON.'), findsOneWidget);
      expect(find.text('Initial Page'), findsOneWidget);
    });
  });

  group('Desktop Integration Tests', () {
    testWidgets('create and edit page flow on desktop', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'workspace_provider': provider,
        'workspace_directory': directory,
        storageKey: jsonEncode([]),
      });

      await pumpWithSize(tester, size: const Size(1280, 800));
      await pumpUntilVisible(tester, find.text('Docume'));

      const emptyMessage = 'No pages yet. Tap + to create your first HTML page.';
      await pumpUntilVisible(tester, find.text(emptyMessage));
      expect(find.text(emptyMessage), findsOneWidget);

      // Create a new page using IconButton in app bar
      final addButton = find.widgetWithIcon(IconButton, Icons.add);
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('New Page'), findsOneWidget);

      // Toggle to HTML mode using tooltip - find the HTML Mode button in editor
      final toggleButton = find.byTooltip('HTML Mode');
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Fill in content
      await tester.enterText(find.byType(TextField).first, 'Desktop Page');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '<h1>Desktop Test</h1>');
      await tester.pumpAndSettle();

      // Save
      final saveButton = find.widgetWithText(shad.PrimaryButton, 'Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify page appears and is selected in desktop view
      await pumpUntilVisible(tester, find.text('Desktop Page'));
      // Desktop page list shows the title
      expect(find.text('Desktop Page'), findsWidgets);
    });
  });
}
