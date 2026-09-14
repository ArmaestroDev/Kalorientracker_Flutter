import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'generative_service.dart';

/// Gemini generateContent REST API
class GeminiApiService implements GenerativeService {
  final String _apiKey;
  @override
  final String model;
  final http.Client _client;

  GeminiApiService(this._apiKey, this.model, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get providerName => 'Gemini';

  @override
  Future<String> generate(AiRequest request) async {
    final contents = <Map<String, dynamic>>[];
    for (var i = 0; i < request.messages.length; i++) {
      final message = request.messages[i];
      final isLast = i == request.messages.length - 1;
      final parts = <Map<String, dynamic>>[
        {'text': message.text},
      ];
      if (isLast && message.isUser && request.imageBytes != null) {
        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Encode(request.imageBytes!),
          },
        });
      }
      contents.add({'role': message.isUser ? 'user' : 'model', 'parts': parts});
    }

    for (var round = 0; round <= GenerativeService.maxToolRounds; round++) {
      final json = await _post({
        'system_instruction': {
          'parts': [
            {'text': request.system},
          ],
        },
        'contents': contents,
        if (request.usesTools)
          'tools': [
            {
              'functionDeclarations': [
                for (final tool in request.tools)
                  {
                    'name': tool.name,
                    'description': tool.description,
                    'parameters': tool.parameters,
                  },
              ],
            },
          ],
        'generationConfig': {
          'maxOutputTokens': request.maxTokens,
          if (request.jsonOutput) 'responseMimeType': 'application/json',
        },
      }, request);

      final blockReason = (json['promptFeedback'] as Map?)?['blockReason'];
      if (blockReason != null) {
        throw AiException(
          'Gemini hat die Anfrage blockiert ($blockReason). Formuliere sie bitte anders.',
        );
      }
      final candidates = json['candidates'] as List<dynamic>? ?? [];
      if (candidates.isEmpty) {
        throw const AiException('Gemini hat keine Antwort geliefert.');
      }
      final candidate = candidates.first as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = (content?['parts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final calls = parts
          .where((part) => part['functionCall'] is Map)
          .map((part) => part['functionCall'] as Map<String, dynamic>)
          .toList();

      if (request.usesTools && calls.isNotEmpty) {
        contents.add({...content!, 'role': 'model'});
        contents.add({
          'role': 'user',
          'parts': [
            for (final call in calls)
              {
                'functionResponse': {
                  if (call['id'] != null) 'id': call['id'],
                  'name': call['name'],
                  'response': await GenerativeService.runTool(
                    request,
                    call['name'] as String? ?? '',
                    (call['args'] as Map?)?.cast<String, dynamic>() ?? {},
                  ),
                },
              },
          ],
        });
        continue;
      }

      final text = parts
          .where((part) => part['thought'] != true)
          .map((part) => part['text'] as String? ?? '')
          .join();
      if (text.trim().isEmpty) {
        final reason = candidate['finishReason'];
        throw AiException(
          reason == 'MAX_TOKENS'
              ? 'Gemini-Antwort wurde abgeschnitten. Bitte erneut versuchen.'
              : 'Gemini hat keine Antwort geliefert ($reason).',
        );
      }
      return text;
    }
    throw GenerativeService.tooManyToolRounds(providerName);
  }

  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> body,
    AiRequest request,
  ) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': _apiKey,
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
