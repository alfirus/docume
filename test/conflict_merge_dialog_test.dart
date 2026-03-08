import 'package:docume/models/doc_page.dart';
import 'package:docume/widgets/conflict_merge_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConflictMergeDialog Tests', () {
    testWidgets('displays conflict resolution title',
        (WidgetTester tester) async {
      final myPage = DocPage(
        id: 'p1',
        title: 'My Title',
        htmlContent: '<p>My content</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 10),
      );

      final remotePage = DocPage(
        id: 'p1',
        title: 'Remote Title',
        htmlContent: '<p>Remote content</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 11),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictMergeDialog(
              myPage: myPage,
              remotePage: remotePage,
              onResolve: (resolved) {},
            ),
          ),
        ),
      );

      expect(find.text('Resolve Edit Conflict'), findsOneWidget);
      expect(find.text('Page Title'), findsOneWidget);
      expect(find.text('Content'), findsWidgets);
    });

    testWidgets('provides merge options', (WidgetTester tester) async {
      final myPage = DocPage(
        id: 'p1',
        title: 'My Title',
        htmlContent: '<p>My content</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 10),
      );

      final remotePage = DocPage(
        id: 'p1',
        title: 'Remote Title',
        htmlContent: '<p>Remote content</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 11),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictMergeDialog(
              myPage: myPage,
              remotePage: remotePage,
              onResolve: (resolved) {},
            ),
          ),
        ),
      );

      expect(find.text('Keep Mine'), findsWidgets);
      expect(find.text('Keep Remote'), findsWidgets);
      expect(find.text('Merge'), findsWidgets);
    });

    testWidgets('displays timestamps', (WidgetTester tester) async {
      final myPage = DocPage(
        id: 'p1',
        title: 'My Title',
        htmlContent: '<p>My content</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 10),
      );

      final remotePage = DocPage(
        id: 'p1',
        title: 'Remote Title',
        htmlContent: '<p>Remote content</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 11),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictMergeDialog(
              myPage: myPage,
              remotePage: remotePage,
              onResolve: (resolved) {},
            ),
          ),
        ),
      );

      expect(find.text('Timestamps'), findsOneWidget);
    });

    testWidgets('dialog has close button', (WidgetTester tester) async {
      final myPage = DocPage(
        id: 'p1',
        title: 'My Title',
        htmlContent: '<p>My content</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 10),
      );

      final remotePage = DocPage(
        id: 'p1',
        title: 'Remote Title',
        htmlContent: '<p>Remote content</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 11),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictMergeDialog(
              myPage: myPage,
              remotePage: remotePage,
              onResolve: (resolved) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('dialog has action buttons', (WidgetTester tester) async {
      final myPage = DocPage(
        id: 'p1',
        title: 'My Title',
        htmlContent: '<p>My content</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 10),
      );

      final remotePage = DocPage(
        id: 'p1',
        title: 'Remote Title',
        htmlContent: '<p>Remote content</p>',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1, 11),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConflictMergeDialog(
              myPage: myPage,
              remotePage: remotePage,
              onResolve: (resolved) {},
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Resolve'), findsOneWidget);
    });
  });
}

