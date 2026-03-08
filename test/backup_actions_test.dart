import 'dart:convert';

import 'package:docume/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const provider = 'icloud';
  const directory = 'icloud:/DocumeWorkspace';
  final namespace = '$provider|$directory';
  final storageKey = 'docume_pages_${base64Url.encode(utf8.encode(namespace))}';

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

  testWidgets('export JSON action is accessible and non-breaking', (WidgetTester tester) async {
    final createdAt = DateTime(2026, 3, 1).toIso8601String();
    final updatedAt = DateTime(2026, 3, 2).toIso8601String();

    SharedPreferences.setMockInitialValues({
      'workspace_provider': provider,
      'workspace_directory': directory,
      storageKey: jsonEncode([
        {
          'id': 'page-1',
          'title': 'Backup Page',
          'htmlContent': '<p>Export me</p>',
          'createdAt': createdAt,
          'updatedAt': updatedAt,
        },
      ]),
    });

    await pumpWithSize(tester, size: const Size(390, 844));
    await pumpUntilVisible(tester, find.text('Backup Page'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export JSON'));
    await tester.pumpAndSettle();

    expect(find.text('Backup Page'), findsOneWidget);
    expect(find.text('Export JSON'), findsNothing);
  });

  testWidgets('import JSON replaces pages and refreshes list', (WidgetTester tester) async {
    final createdAt = DateTime(2026, 3, 1).toIso8601String();
    final updatedAt = DateTime(2026, 3, 2).toIso8601String();

    SharedPreferences.setMockInitialValues({
      'workspace_provider': provider,
      'workspace_directory': directory,
      storageKey: jsonEncode([
        {
          'id': 'old-1',
          'title': 'Old Page',
          'htmlContent': '<p>Old content</p>',
          'createdAt': createdAt,
          'updatedAt': updatedAt,
        },
      ]),
    });

    const importJson = '[{"id":"new-1","title":"Imported Page","htmlContent":"<p>Imported content</p>","createdAt":"2026-03-03T00:00:00.000","updatedAt":"2026-03-04T00:00:00.000"}]';

    await pumpWithSize(tester, size: const Size(390, 844));
    await pumpUntilVisible(tester, find.text('Old Page'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import JSON'));
    await tester.pumpAndSettle();

    expect(find.text('Import Backup JSON'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, importJson);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Import'));
    await tester.pumpAndSettle();

    expect(find.text('Imported 1 page(s).'), findsOneWidget);
    expect(find.text('Imported Page'), findsOneWidget);
    expect(find.text('Old Page'), findsNothing);
  });
}
