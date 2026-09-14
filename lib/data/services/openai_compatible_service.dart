import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'generative_service.dart';

/// Chat Completions API, shared by OpenAI and xAI (Grok)
class OpenAiCompatibleService implements GenerativeService {
  final String _apiKey;
  @override
  final String model;
  @override
  final String providerName;
  final String _url;
  final bool _supportsJsonMode;
  final String _maxTokensField;
  final http.Client _client;

  OpenAiCompatibleService._(
    this._apiKey,
    this.model, {
    required this.providerName,
    required String url,
    required bool supportsJsonMode,
    required String maxTokensField,
    http.Client? client,
  }) : _url = url,
       _supportsJsonMode = supportsJsonMode,
       _maxTokensField = maxTokensField,
       _client = client ?? http.Client();

  factory OpenAiCompatibleService.openAi(
    String apiKey,
    String model, {
    http.Client? client,
  }) => OpenAiCompatibleService._(
    apiKey,
    model,
    providerName: 'OpenAI',
    url: 'https://api.openai.com/v1/chat/completions',
    supportsJsonMode: true,
    maxTokensField: 'max_completion_tokens',
    client: client,
  );

  factory OpenAiCompatibleService.grok(
    String apiKey,
    String model, {
    http.Client? client,
  }) => OpenAiCompatibleService._(
    apiKey,
    model,
    providerName: 'Grok',
    url: 'https://api.x.ai/v1/chat/completions',
    supportsJsonMode: true,
    maxTokensField: 'max_tokens',
    client: client,
  );

  @override
  Future<String> generate(AiRequest request) async {
    final system = request.jsonOutput
        ? '${request.system}\n\nAntworte ausschließlich mit einem gültigen JSON-Objekt.'
        : request.system;

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
    ];
    for (var i = 0; i < request.messages.length; i++) {
      final message = request.messages[i];
      final isLast = i == request.messages.length - 1;
      if (isLast && message.isUser && request.imageBytes != null) {
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': message.text},
            {
              'type': 'image_url',
              'image_url': {
                'url':
                    'data:image/jpeg;base64,${base64Encode(request.imageBytes!)}',
              },
            },
          ],
        });
      } else {
        messages.add({
          'role': message.isUser ? 'user' : 'assistant',
          'content': message.text,
        });
      }
    }

    for (var round = 0; round <= GenerativeService.maxToolRounds; round++) {
      final json = await _post({
        'model': model,
        'messages': messages,
        _maxTokensField: request.maxTokens,
        if (request.jsonOutput && _supportsJsonMode)
          'response_format': {'type': 'json_object'},
        if (request.usesTools)
          'tools': [
            for (final tool in request.tools)
              {
                'type': 'function',
                'function': {
                  'name': tool.name,
                  'description': tool.description,
                  'parameters': tool.parameters,
                },
              },
          ],
      }, request);

      final choices = json['choices'] as List<dynamic>? ?? [];
      if (choices.isEmpty) {
        throw AiException('$providerName hat keine Antwort geliefert.');
      }
      final message =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>? ??
          {};
      final toolCalls = (message['tool_calls'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (request.usesTools && toolCalls.isNotEmpty) {
        messages.add({...message, 'role': 'assistant'});
        for (final call in toolCalls) {
          final function = call['function'] as Map<String, dynamic>? ?? {};
          final rawArgs = function['arguments'];
          Map<String, dynamic> args = {};
          if (rawArgs is String && rawArgs.trim().isNotEmpty) {
            try {
              args = (jsonDecode(rawArgs) as Map).cast<String, dynamic>();
            } catch (_) {}
          } else if (rawArgs is Map) {
            args = rawArgs.cast<String, dynamic>();
          }
          messages.add({
            'role': 'tool',
            'tool_call_id': call['id'],
            'content': jsonEncode(
              await GenerativeService.runTool(
                request,
                function['name'] as String? ?? '',
                args,
              ),
            ),
          });
        }
        continue;
      }

      final refusal = message['refusal'] as String?;
      if (refusal != null && refusal.isNotEmpty) {
        throw AiException('$providerName hat abgelehnt: $refusal');
      }
      final content = message['content'];
      final text = content is String
          ? content
          : content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map((part) => part['text'] as String? ?? '')
                .join()
          : '';
      if (text.trim().isEmpty) {
        throw AiException('$providerName hat keine Antwort geliefert.');
      }
      return text;
    }
    throw GenerativeService.tooManyToolRounds(providerName);
  }

  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> body,
    AiRequest request,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_url),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $_apiKey',
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
    return jsonDecode(responseBody) as Map<String, dynamic>;
  }
}
