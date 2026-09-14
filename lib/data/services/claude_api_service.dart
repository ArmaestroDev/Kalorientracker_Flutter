import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'generative_service.dart';

/// Anthropic Messages API over plain HTTP (there is no official Dart SDK)
class ClaudeApiService implements GenerativeService {
  final String _apiKey;
  @override
  final String model;
  final http.Client _client;

  static const _url = 'https://api.anthropic.com/v1/messages';

  ClaudeApiService(this._apiKey, this.model, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get providerName => 'Claude';

  bool get _supportsServerFallbacks =>
      model == 'claude-opus-5' || model.startsWith('claude-fable-5');

  bool get _supportsEffort =>
      model.startsWith('claude-opus-') ||
      model.startsWith('claude-fable-') ||
      model == 'claude-sonnet-5' ||
      model == 'claude-sonnet-4-6';

  @override
  Future<String> generate(AiRequest request) async {
    final messages = <Map<String, dynamic>>[];
    for (var i = 0; i < request.messages.length; i++) {
      final message = request.messages[i];
      final isLast = i == request.messages.length - 1;
      if (isLast && message.isUser && request.imageBytes != null) {
        messages.add({
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': base64Encode(request.imageBytes!),
              },
            },
            {'type': 'text', 'text': message.text},
          ],
        });
      } else {
        messages.add({
          'role': message.isUser ? 'user' : 'assistant',
          'content': message.text,
        });
      }
    }

    final system = request.jsonOutput
        ? '${request.system}\n\nAntworte ausschließlich mit einem gültigen JSON-Objekt, ohne Markdown und ohne weiteren Text.'
        : request.system;

    final body = {
      'model': model,
      'max_tokens': request.maxTokens,
      'system': system,
      'messages': messages,
      if (_supportsEffort)
        'output_config': {'effort': request.jsonOutput ? 'low' : 'medium'},
      if (_supportsServerFallbacks) 'fallbacks': 'default',
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_url),
            headers: {
              'content-type': 'application/json',
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
              if (_supportsServerFallbacks)
                'anthropic-beta': 'server-side-fallback-2026-07-01',
            },
            body: jsonEncode(body),
          )
          .timeout(
            request.imageBytes != null
                ? GenerativeService.imageTimeout
                : GenerativeService.textTimeout,
          );
    } on TimeoutException catch (e) {
      throw GenerativeService.networkError(providerName, e);
    } on http.ClientException catch (e) {
      throw GenerativeService.networkError(providerName, e);
    }

    final responseBody = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw GenerativeService.httpError(
        providerName,
        model,
        response.statusCode,
        responseBody,
      );
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    if (json['stop_reason'] == 'refusal') {
      throw const AiException(
        'Claude hat diese Anfrage abgelehnt. Formuliere sie bitte anders.',
      );
    }
    final text = (json['content'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String? ?? '')
        .join();
    if (text.trim().isEmpty) {
      throw const AiException('Claude hat keine Antwort geliefert.');
    }
    return text;
  }
}
