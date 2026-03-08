import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docume/main.dart';

void main() {
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

  testWidgets('first run shows workspace setup', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DocumeApp());
    await pumpUntilVisible(tester, find.text('Set Workspace'));

    expect(find.text('Set Workspace'), findsOneWidget);
    expect(find.text('Choose workspace storage'), findsOneWidget);
  });

  testWidgets('configured workspace opens empty page list', (WidgetTester tester) async {
    const provider = 'icloud';
    const directory = 'icloud:/DocumeWorkspace';
    final namespace = '$provider|$directory';
    final storageKey = 'docume_pages_${base64Url.encode(utf8.encode(namespace))}';

    SharedPreferences.setMockInitialValues({
      'workspace_provider': provider,
      'workspace_directory': directory,
      storageKey: jsonEncode([]),
    });

    await tester.pumpWidget(const DocumeApp());
    await pumpUntilVisible(tester, find.text('Docume'));
    await pumpUntilVisible(tester, find.text('No pages yet. Tap + to create your first HTML page.'));

    expect(find.text('Docume'), findsOneWidget);
    expect(find.text('No pages yet. Tap + to create your first HTML page.'), findsOneWidget);
  });
}
