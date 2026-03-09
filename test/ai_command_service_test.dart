import 'package:docume/models/ai_command.dart';
import 'package:docume/models/doc_page.dart';
import 'package:docume/services/ai_command_service.dart';
import 'package:docume/services/ai_provider_client.dart';
import 'package:docume/services/page_template_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProviderClient extends AiProviderClient {
  const _FakeProviderClient(this.payload);

  final String payload;

  @override
  Future<String> generateRawPlan({
    required AiProviderSettings settings,
    required String prompt,
    required String contextJson,
  }) async {
    return payload;
  }
}

void main() {
  group('AiCommandService', () {
    test('buildPlan parses JSON payload into actions', () async {
      final service = AiCommandService(
        providerClient: const _FakeProviderClient(
          '{"summary":"Create a page","actions":[{"type":"create_page","title":"Roadmap","htmlContent":"<h1>Roadmap</h1>"}]}',
        ),
      );

      final plan = await service.buildPlan(
        settings: const AiProviderSettings(
          provider: AiProvider.opencode,
          endpoint: 'https://example.com',
          model: 'test-model',
          apiKey: 'k',
        ),
        prompt: 'create roadmap page',
        pages: const [],
      );

      expect(plan.actions, hasLength(1));
      expect(plan.actions.first.type, AiActionType.createPage);
      expect(plan.actions.first.title, 'Roadmap');
    });

    test('applyPlan creates, updates, and deletes pages', () async {
      final service = AiCommandService(
        providerClient: const _FakeProviderClient(
          '{"summary":"noop","actions":[]}',
        ),
      );

      final existing = DocPage(
        id: 'p1',
        title: 'First',
        htmlContent: '<p>hello</p>',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final plan = AiCommandPlan(
        summary: 'Mutate pages',
        rawText: '{}',
        actions: const [
          AiAction(
            type: AiActionType.createPage,
            title: 'Second',
            htmlContent: '<h1>Second</h1>',
          ),
          AiAction(
            type: AiActionType.updatePage,
            pageId: 'p1',
            title: 'First Updated',
            htmlContent: '<p>updated</p>',
          ),
          AiAction(type: AiActionType.deletePage, pageId: 'p1'),
        ],
      );

      final updated = await service.applyPlan(
        plan: plan,
        pages: [existing],
        templateService: PageTemplateService(namespace: 'test'),
        onExportAll: (_) async {},
      );

      expect(updated, hasLength(1));
      expect(updated.first.title, 'Second');
    });

    test('applyPlan rejects invalid HTML for create_page', () async {
      final service = AiCommandService(
        providerClient: const _FakeProviderClient(
          '{"summary":"noop","actions":[]}',
        ),
      );

      final plan = AiCommandPlan(
        summary: 'Invalid html',
        rawText: '{}',
        actions: const [
          AiAction(
            type: AiActionType.createPage,
            title: 'Bad',
            htmlContent: 'plain text without tags',
          ),
        ],
      );

      expect(
        () => service.applyPlan(
          plan: plan,
          pages: const [],
          templateService: PageTemplateService(namespace: 'test'),
          onExportAll: (_) async {},
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
