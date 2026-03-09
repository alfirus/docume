import 'package:docume/models/ai_command.dart';
import 'package:docume/services/ai_secret_store.dart';
import 'package:docume/services/ai_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecretStore implements AiSecretStore {
  final Map<String, String> _secrets = {};

  @override
  Future<void> delete(String key) async {
    _secrets.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return _secrets[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _secrets[key] = value;
  }
}

void main() {
  group('AiSettingsService', () {
    test('defaults to claude provider', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AiSettingsService(secretStore: _MemorySecretStore());

      final provider = await service.getSelectedProvider();
      expect(provider, AiProvider.claude);
    });

    test('persists selected provider', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AiSettingsService(secretStore: _MemorySecretStore());

      await service.saveSelectedProvider(AiProvider.opencode);
      final provider = await service.getSelectedProvider();

      expect(provider, AiProvider.opencode);
    });

    test('stores API key in secret store and reads it back', () async {
      SharedPreferences.setMockInitialValues({});
      final secretStore = _MemorySecretStore();
      final service = AiSettingsService(secretStore: secretStore);

      await service.saveProviderSettings(
        const AiProviderSettings(
          provider: AiProvider.claude,
          endpoint: 'https://api.anthropic.com/v1/messages',
          model: 'claude-3-5-sonnet-latest',
          apiKey: 'super-secret-key',
        ),
      );

      final settings = await service.getProviderSettings(AiProvider.claude);
      expect(settings.apiKey, 'super-secret-key');
      expect(settings.isConfigured, isTrue);
    });

    test('OpenClaw is configured without model value', () async {
      SharedPreferences.setMockInitialValues({});
      final secretStore = _MemorySecretStore();
      final service = AiSettingsService(secretStore: secretStore);

      await service.saveProviderSettings(
        const AiProviderSettings(
          provider: AiProvider.openclaw,
          endpoint: 'ws://localhost:3000/ws',
          model: '',
          apiKey: 'openclaw-key',
        ),
      );

      final settings = await service.getProviderSettings(AiProvider.openclaw);
      expect(settings.model, '');
      expect(settings.requiresModel, isFalse);
      expect(settings.isConfigured, isTrue);
    });

    test('migrates legacy shared preferences API key', () async {
      SharedPreferences.setMockInitialValues({
        'ai_claude_api_key': 'legacy-key',
      });
      final secretStore = _MemorySecretStore();
      final service = AiSettingsService(secretStore: secretStore);

      final settings = await service.getProviderSettings(AiProvider.claude);
      expect(settings.apiKey, 'legacy-key');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_claude_api_key'), isNull);
    });
  });
}
