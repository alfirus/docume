import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_command.dart';
import 'ai_secret_store.dart';

class AiSettingsService {
  AiSettingsService({
    AiSecretStore? secretStore,
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _secretStore = secretStore ?? SecureAiSecretStore(),
       _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  static const _selectedProviderKey = 'ai_selected_provider';

  final AiSecretStore _secretStore;
  final Future<SharedPreferences> Function() _prefsProvider;

  static String _endpointKey(AiProvider provider) =>
      'ai_${provider.value}_endpoint';
  static String _modelKey(AiProvider provider) => 'ai_${provider.value}_model';
  static String _legacyApiKeyKey(AiProvider provider) =>
      'ai_${provider.value}_api_key';
  static String _secureApiKeyKey(AiProvider provider) =>
      'docume_ai_secret_${provider.value}_api_key';

  Future<AiProvider> getSelectedProvider() async {
    final prefs = await _prefsProvider();
    final value = prefs.getString(_selectedProviderKey);
    return value == null
        ? AiProvider.claude
        : (AiProviderX.fromValue(value) ?? AiProvider.claude);
  }

  Future<void> saveSelectedProvider(AiProvider provider) async {
    final prefs = await _prefsProvider();
    await prefs.setString(_selectedProviderKey, provider.value);
  }

  Future<AiProviderSettings> getProviderSettings(AiProvider provider) async {
    final prefs = await _prefsProvider();
    final endpoint = prefs.getString(_endpointKey(provider)) ??
        _defaultEndpointFor(provider);
    final model = prefs.getString(_modelKey(provider)) ??
        _defaultModelFor(provider);
    final apiKey = await _readApiKey(provider, prefs);

    return AiProviderSettings(
      provider: provider,
      endpoint: endpoint,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<void> saveProviderSettings(AiProviderSettings settings) async {
    final prefs = await _prefsProvider();
    await prefs.setString(
      _endpointKey(settings.provider),
      settings.endpoint.trim(),
    );
    await prefs.setString(_modelKey(settings.provider), settings.model.trim());
    await _writeApiKey(settings.provider, settings.apiKey.trim(), prefs);
  }

  Future<String> _readApiKey(
    AiProvider provider,
    SharedPreferences prefs,
  ) async {
    try {
      final secureValue = await _secretStore.read(_secureApiKeyKey(provider));
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    } catch (_) {
      // Fall back to legacy shared preferences storage for compatibility.
    }

    final legacy = prefs.getString(_legacyApiKeyKey(provider)) ?? '';
    if (legacy.isNotEmpty) {
      try {
        await _secretStore.write(_secureApiKeyKey(provider), legacy);
        await prefs.remove(_legacyApiKeyKey(provider));
      } catch (_) {
        // Keep legacy key if secure migration fails.
      }
    }
    return legacy;
  }

  Future<void> _writeApiKey(
    AiProvider provider,
    String apiKey,
    SharedPreferences prefs,
  ) async {
    try {
      if (apiKey.isEmpty) {
        await _secretStore.delete(_secureApiKeyKey(provider));
      } else {
        await _secretStore.write(_secureApiKeyKey(provider), apiKey);
      }
      await prefs.remove(_legacyApiKeyKey(provider));
    } catch (_) {
      await prefs.setString(_legacyApiKeyKey(provider), apiKey);
    }
  }

  String _defaultEndpointFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.claude:
        return 'https://api.anthropic.com/v1/messages';
      case AiProvider.opencode:
        return 'https://api.openai.com/v1/chat/completions';
      case AiProvider.openclaw:
        return 'ws://127.0.0.1:18789';
    }
  }

  String _defaultModelFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.claude:
        return 'claude-3-5-sonnet-latest';
      case AiProvider.opencode:
        return 'gpt-4o-mini';
      case AiProvider.openclaw:
        return '';
    }
  }
}
