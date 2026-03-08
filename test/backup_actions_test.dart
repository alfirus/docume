import 'dart:convert';

import 'package:docume/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('export JSON includes all pages and metadata fields', (WidgetTester tester) async {
    String? capturedClipboardText;
    final messenger = TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final payload = call.arguments as Map<dynamic, dynamic>;
        capturedClipboardText = payload['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    SharedPreferences.setMockInitialValues({
      'workspace_provider': provider,
      'workspace_directory': directory,
      storageKey: jsonEncode([
        {
          'id': 'page-a',
          'title': 'Export Alpha',
          'htmlContent': '<p>Alpha body</p>',
          'createdAt': '2026-03-01T00:00:00.000',
          'updatedAt': '2026-03-03T00:00:00.000',
        },
        {
          'id': 'page-b',
          'title': 'Export Beta',
          'htmlContent': '<h1>Beta</h1><p>Body</p>',
          'createdAt': '2026-03-02T00:00:00.000',
          'updatedAt': '2026-03-04T00:00:00.000',
        },
      ]),
    });

    await pumpWithSize(tester, size: const Size(390, 844));
    await pumpUntilVisible(tester, find.text('Export Alpha'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export JSON'));
    await tester.pumpAndSettle();

    expect(find.text('Backup JSON copied to clipboard.'), findsOneWidget);
    expect(capturedClipboardText, isNotNull);

    final raw = capturedClipboardText!;

    final decoded = jsonDecode(raw) as List<dynamic>;
    expect(decoded.length, 2);

    final byId = {
      for (final item in decoded)
        (item as Map<String, dynamic>)['id'] as String: item,
    };

    expect(byId['page-a'], isNotNull);
    expect(byId['page-b'], isNotNull);

    final pageA = byId['page-a']!;
    final pageB = byId['page-b']!;

    expect(pageA['title'], 'Export Alpha');
    expect(pageA['createdAt'], '2026-03-01T00:00:00.000');
    expect(pageA['updatedAt'], '2026-03-03T00:00:00.000');

    expect(pageB['title'], 'Export Beta');
    expect(pageB['createdAt'], '2026-03-02T00:00:00.000');
    expect(pageB['updatedAt'], '2026-03-04T00:00:00.000');
  });

  testWidgets('import invalid JSON shows error and keeps existing pages', (WidgetTester tester) async {
    final createdAt = DateTime(2026, 3, 1).toIso8601String();
    final updatedAt = DateTime(2026, 3, 2).toIso8601String();

    SharedPreferences.setMockInitialValues({
      'workspace_provider': provider,
      'workspace_directory': directory,
      storageKey: jsonEncode([
        {
          'id': 'stable-1',
          'title': 'Stable Page',
          'htmlContent': '<p>Stable content</p>',
          'createdAt': createdAt,
          'updatedAt': updatedAt,
        },
      ]),
    });

    await pumpWithSize(tester, size: const Size(390, 844));
    await pumpUntilVisible(tester, find.text('Stable Page'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import JSON'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '{not-valid-json');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Import'));
    await tester.pumpAndSettle();

    expect(find.text('Import failed: invalid backup JSON.'), findsOneWidget);
    expect(find.text('Stable Page'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    final persistedRaw = preferences.getString(storageKey);
    expect(persistedRaw, isNotNull);

    final persisted = jsonDecode(persistedRaw!) as List<dynamic>;
    expect(persisted.length, 1);
    expect((persisted.first as Map<String, dynamic>)['title'], 'Stable Page');
  });
}
