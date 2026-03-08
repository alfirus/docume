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

  testWidgets('mobile layout shows FAB and opens detail screen', (WidgetTester tester) async {
    final createdAt = DateTime(2026, 3, 1).toIso8601String();
    final updatedAt = DateTime(2026, 3, 2).toIso8601String();

    SharedPreferences.setMockInitialValues({
      'workspace_provider': provider,
      'workspace_directory': directory,
      storageKey: jsonEncode([
        {
          'id': 'mobile-1',
          'title': 'Mobile Note',
          'htmlContent': '<p>Mobile detail body</p>',
          'createdAt': createdAt,
          'updatedAt': updatedAt,
        },
      ]),
    });

    await pumpWithSize(tester, size: const Size(390, 844));
    await pumpUntilVisible(tester, find.text('Mobile Note'));

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Mobile Note'), findsOneWidget);

    await tester.tap(find.text('Mobile Note'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.textContaining('Created 2026-03-01'), findsOneWidget);
  });

  testWidgets('desktop layout shows two-pane preview and selection updates', (
    WidgetTester tester,
  ) async {
    final createdAt = DateTime(2026, 3, 1).toIso8601String();
    final updatedAt = DateTime(2026, 3, 2).toIso8601String();

    SharedPreferences.setMockInitialValues({
      'workspace_provider': provider,
      'workspace_directory': directory,
      storageKey: jsonEncode([
        {
          'id': 'desktop-1',
          'title': 'Desktop Note',
          'htmlContent': '<p>Desktop content only</p>',
          'createdAt': createdAt,
          'updatedAt': updatedAt,
        },
        {
          'id': 'desktop-2',
          'title': 'Second Note',
          'htmlContent': '<p>Second detail body</p>',
          'createdAt': createdAt,
          'updatedAt': updatedAt,
        },
      ]),
    });

    await pumpWithSize(tester, size: const Size(1280, 800));
    await pumpUntilVisible(tester, find.text('Desktop Note'));

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Desktop Note'), findsNWidgets(2));
    expect(find.textContaining('Created 2026-03-01'), findsOneWidget);

    expect(find.text('Second Note'), findsOneWidget);
    await tester.tap(find.text('Second Note').first);
    await tester.pumpAndSettle();

    expect(find.text('Second Note'), findsNWidgets(2));
  });
}
