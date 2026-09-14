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

    final body = {
      'system_instruction': {
        'parts': [
          {'text': request.system},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': request.maxTokens,
        if (request.jsonOutput) 'responseMimeType': 'application/json',
      },
    };

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

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
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
    final parts =
        (candidate['content'] as Map<String, dynamic>?)?['parts']
            as List<dynamic>? ??
        [];
    final text = parts
        .whereType<Map<String, dynamic>>()
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
}
