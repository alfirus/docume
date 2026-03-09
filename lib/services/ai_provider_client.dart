import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ai_command.dart';

class AiProviderClient {
  const AiProviderClient();

  Future<void> testConnection({required AiProviderSettings settings}) async {
    switch (settings.provider) {
      case AiProvider.claude:
      case AiProvider.opencode:
        if (settings.apiKey.trim().isEmpty) {
          throw const FormatException('API key is required.');
        }
        await _testTcpEndpoint(settings.endpoint);
        return;
      case AiProvider.openclaw:
        if (settings.apiKey.trim().isEmpty) {
          throw const FormatException('Gateway key is required.');
        }
        await _testOpenClawWebSocketEndpoint(
          settings.endpoint,
          settings.apiKey,
        );
        return;
    }
  }

  Future<String> generateRawPlan({
    required AiProviderSettings settings,
    required String prompt,
    required String contextJson,
  }) async {
    switch (settings.provider) {
      case AiProvider.claude:
        return _callClaude(settings: settings, prompt: prompt, contextJson: contextJson);
      case AiProvider.opencode:
        return _callOpenAiCompatible(
          settings: settings,
          prompt: prompt,
          contextJson: contextJson,
        );
      case AiProvider.openclaw:
        return _callOpenClawWebSocket(
          settings: settings,
          prompt: prompt,
          contextJson: contextJson,
        );
    }
  }

  Future<String> _callOpenClawWebSocket({
    required AiProviderSettings settings,
    required String prompt,
    required String contextJson,
  }) async {
    final uri = _toWebSocketUri(settings.endpoint);
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: _openClawHeaders(settings.apiKey),
    ).timeout(
      const Duration(seconds: 15),
    );

    try {
      socket.add(
        jsonEncode({
          'type': 'plan_request',
          'action': 'plan_request',
          'provider': 'openclaw',
          'gatewayKey': settings.apiKey,
          'apiKey': settings.apiKey,
          'key': settings.apiKey,
          'prompt': _buildPrompt(prompt: prompt, contextJson: contextJson),
        }),
      );

      final completer = Completer<String>();
      final sub = socket.listen(
        (event) {
          final extracted = _extractWsText(event);
          if (extracted != null && extracted.trim().isNotEmpty) {
            if (!completer.isCompleted) {
              completer.complete(extracted);
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError('OpenClaw WebSocket error: $error'),
            );
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError(
              const FormatException(
                'OpenClaw WebSocket closed before returning response text.',
              ),
            );
          }
        },
      );

      try {
        return await completer.future.timeout(const Duration(seconds: 30));
      } finally {
        await sub.cancel();
      }
    } finally {
      await socket.close();
    }
  }

  Uri _toWebSocketUri(String endpoint) {
    final parsed = Uri.parse(endpoint);
    if (parsed.scheme == 'ws' || parsed.scheme == 'wss') {
      return parsed;
    }
    if (parsed.scheme == 'http') {
      return parsed.replace(scheme: 'ws');
    }
    if (parsed.scheme == 'https') {
      return parsed.replace(scheme: 'wss');
    }

    throw FormatException(
      'OpenClaw endpoint must use ws:// or wss:// (or http(s) convertible).',
    );
  }

  Future<void> _testOpenClawWebSocketEndpoint(String endpoint, String key) async {
    final uri = _toWebSocketUri(endpoint);
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: _openClawHeaders(key),
    ).timeout(
      const Duration(seconds: 10),
    );
    await socket.close();
  }

  Map<String, dynamic> _openClawHeaders(String key) {
    return {
      'Authorization': 'Bearer $key',
      'x-gateway-key': key,
      'x-api-key': key,
    };
  }

  Future<void> _testTcpEndpoint(String endpoint) async {
    final uri = Uri.parse(endpoint);
    if (uri.host.trim().isEmpty) {
      throw const FormatException('Endpoint must include a valid host.');
    }

    final port = uri.hasPort
        ? uri.port
        : (uri.scheme == 'https' || uri.scheme == 'wss' ? 443 : 80);
    final socket = await Socket.connect(uri.host, port).timeout(
      const Duration(seconds: 6),
    );
    await socket.close();
  }

  String? _extractWsText(dynamic event) {
    final raw = event?.toString();
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final content = decoded['content'];
        if (content is String && content.trim().isNotEmpty) {
          return content;
        }

        final text = decoded['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text;
        }

        final message = decoded['message'];
        if (message is Map<String, dynamic>) {
          final messageContent = message['content'];
          if (messageContent is String && messageContent.trim().isNotEmpty) {
            return messageContent;
          }
        }

        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          final dataContent = data['content'];
          if (dataContent is String && dataContent.trim().isNotEmpty) {
            return dataContent;
          }
          final dataText = data['text'];
          if (dataText is String && dataText.trim().isNotEmpty) {
            return dataText;
          }
        }
      }
    } catch (_) {
      // Non-JSON frame; treat as plain text.
    }

    return raw;
  }

  Future<String> _callClaude({
    required AiProviderSettings settings,
    required String prompt,
    required String contextJson,
  }) async {
    final response = await http.post(
      Uri.parse(settings.endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': settings.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': settings.model,
        'max_tokens': 1800,
        'temperature': 0.2,
        'messages': [
          {
            'role': 'user',
            'content': _buildPrompt(prompt: prompt, contextJson: contextJson),
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Claude request failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['content'];
    if (content is! List || content.isEmpty) {
      throw const FormatException('Claude returned an empty content response.');
    }

    final first = content.first;
    if (first is Map<String, dynamic> && first['text'] is String) {
      return first['text'] as String;
    }

    throw const FormatException('Unexpected Claude response payload.');
  }

  Future<String> _callOpenAiCompatible({
    required AiProviderSettings settings,
    required String prompt,
    required String contextJson,
  }) async {
    final response = await http.post(
      Uri.parse(settings.endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${settings.apiKey}',
      },
      body: jsonEncode({
        'model': settings.model,
        'temperature': 0.2,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an assistant that outputs only valid JSON for page-management actions.',
          },
          {
            'role': 'user',
            'content': _buildPrompt(prompt: prompt, contextJson: contextJson),
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Provider request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('Provider returned no choices.');
    }

    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('Unexpected provider choice payload.');
    }

    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw const FormatException('Unexpected provider message payload.');
    }

    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content;
    }

    throw const FormatException('Provider response content was empty.');
  }

  String _buildPrompt({required String prompt, required String contextJson}) {
    return '''
You manage pages for an app called Docume.

Return ONLY valid JSON with this schema:
{
  "summary": "short summary",
  "actions": [
    {
      "type": "create_page|update_page|delete_page|create_template|export_all",
      "pageId": "required for update_page/delete_page",
      "title": "required for create_page and optional for update_page",
      "htmlContent": "required for create_page and optional for update_page/create_template",
      "parentId": "optional for create/update",
      "tags": ["optional","tags"],
      "templateName": "required for create_template",
      "format": "required for export_all; one of pdf|docx|epub"
    }
  ]
}

Rules:
- Keep actions minimal and precise.
- Use only existing page IDs from context for updates/deletes.
- htmlContent must contain HTML tags when provided.
- No markdown. No explanation outside JSON.

User request:
$prompt

Current pages/context JSON:
$contextJson
''';
  }
}
