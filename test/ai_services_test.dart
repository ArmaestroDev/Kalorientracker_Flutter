import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kalorientracker_flutter/data/models/chat_message.dart';
import 'package:kalorientracker_flutter/data/repositories/api_service_repository.dart';
import 'package:kalorientracker_flutter/data/services/claude_api_service.dart';
import 'package:kalorientracker_flutter/data/services/gemini_api_service.dart';
import 'package:kalorientracker_flutter/data/services/generative_service.dart';
import 'package:kalorientracker_flutter/data/services/openai_compatible_service.dart';

void main() {
  final chat = AiRequest(
    system: 'SYSTEM',
    messages: [
      ChatMessage(role: ChatRole.user, text: 'Hallo'),
      ChatMessage(role: ChatRole.assistant, text: 'Hi!'),
      ChatMessage(role: ChatRole.user, text: 'Was essen?'),
    ],
  );

  group('Claude', () {
    test(
      'sends system, history and headers; returns only text blocks',
      () async {
        late http.Request sent;
        final service = ClaudeApiService(
          'sk-test',
          'claude-opus-5',
          client: MockClient((request) async {
            sent = request;
            return http.Response(
              jsonEncode({
                'stop_reason': 'end_turn',
                'content': [
                  {'type': 'thinking', 'thinking': ''},
                  {'type': 'text', 'text': 'Iss Skyr.'},
                ],
              }),
              200,
            );
          }),
        );

        expect(await service.generate(chat), 'Iss Skyr.');
        final body = jsonDecode(sent.body) as Map<String, dynamic>;
        expect(sent.headers['x-api-key'], 'sk-test');
        expect(sent.headers['anthropic-version'], '2023-06-01');
        expect(body['model'], 'claude-opus-5');
        expect(body['system'], 'SYSTEM');
        expect((body['messages'] as List).map((m) => m['role']), [
          'user',
          'assistant',
          'user',
        ]);
        expect(body['fallbacks'], 'default');
        expect(body.containsKey('temperature'), isFalse);
      },
    );

    test('image is attached to the last user message', () async {
      late Map<String, dynamic> body;
      final service = ClaudeApiService(
        'k',
        'claude-sonnet-5',
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': '{}'},
              ],
            }),
            200,
          );
        }),
      );
      await service.generate(
        AiRequest.single(
          system: 's',
          prompt: 'Foto',
          imageBytes: Uint8List.fromList([1, 2, 3]),
          jsonOutput: true,
        ),
      );
      final content = (body['messages'] as List).last['content'] as List;
      expect(content.first['type'], 'image');
      expect(body.containsKey('fallbacks'), isFalse);
    });

    test('401 becomes an actionable German message', () async {
      final service = ClaudeApiService(
        'bad',
        'claude-opus-5',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'type': 'error',
              'error': {
                'type': 'authentication_error',
                'message': 'invalid x-api-key',
              },
            }),
            401,
          ),
        ),
      );
      expect(
        () => service.generate(chat),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('API-Schlüssel ungültig'),
          ),
        ),
      );
    });
  });

  group('Gemini', () {
    test('uses REST with system_instruction and model role', () async {
      late http.Request sent;
      final service = GeminiApiService(
        'g-key',
        'gemini-3.8-flash',
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'geheim', 'thought': true},
                      {'text': 'Antwort'},
                    ],
                  },
                  'finishReason': 'STOP',
                },
              ],
            }),
            200,
          );
        }),
      );

      expect(await service.generate(chat), 'Antwort');
      expect(sent.url.path, '/v1beta/models/gemini-3.8-flash:generateContent');
      expect(sent.headers['x-goog-api-key'], 'g-key');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect((body['contents'] as List).map((c) => c['role']), [
        'user',
        'model',
        'user',
      ]);
    });

    test('404 names the model', () async {
      final service = GeminiApiService(
        'k',
        'gemini-alt',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'models/gemini-alt is not found'},
            }),
            404,
          ),
        ),
      );
      expect(
        () => service.generate(chat),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('Modell "gemini-alt" nicht gefunden'),
          ),
        ),
      );
    });
  });

  group('OpenAI and Grok', () {
    test(
      'OpenAI uses max_completion_tokens and JSON mode, no temperature',
      () async {
        late Map<String, dynamic> body;
        final service = OpenAiCompatibleService.openAi(
          'o-key',
          'gpt-5.4-mini',
          client: MockClient((request) async {
            body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(request.headers['authorization'], 'Bearer o-key');
            return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': '{"a":1}'},
                  },
                ],
              }),
              200,
            );
          }),
        );
        await service.generate(
          AiRequest.single(system: 's', prompt: 'p', jsonOutput: true),
        );
        expect(body['max_completion_tokens'], isNotNull);
        expect(body['response_format'], {'type': 'json_object'});
        expect(body.containsKey('temperature'), isFalse);
        expect((body['messages'] as List).first['role'], 'system');
      },
    );

    test('Grok talks to api.x.ai', () async {
      late Uri url;
      final service = OpenAiCompatibleService.grok(
        'x-key',
        'grok-4.6',
        client: MockClient((request) async {
          url = request.url;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'ok'},
                },
              ],
            }),
            200,
          );
        }),
      );
      expect(await service.generate(chat), 'ok');
      expect(url.host, 'api.x.ai');
    });
  });

  group('ApiServiceRepository', () {
    test('extracts JSON surrounded by fences and text', () {
      expect(
        ApiServiceRepository.extractJsonObject(
          'Hier:\n```json\n{"name": "Skyr", "calories": 160}\n```\nFertig',
        ),
        {'name': 'Skyr', 'calories': 160},
      );
      expect(ApiServiceRepository.extractJsonObject('keine Daten'), isNull);
    });

    test(
      'classification keeps amount, unit, category and per-100g values',
      () async {
        final repository = ApiServiceRepository(
          _FakeService(
            jsonEncode({
              'type': 'food',
              'name': 'Skyr natur',
              'amount': 250,
              'unit': 'Gramm',
              'calories': 158,
              'protein': 27.5,
              'carbs': 10,
              'fat': 0.5,
              'category': 'Milchprodukte',
              'calories_100g': 63,
              'protein_100g': 11,
              'carbs_100g': 4,
              'fat_100g': 0.2,
            }),
          ),
        );
        final result = await repository.classifyAndProcess('250g Skyr', '', 82);
        final info = result.foodInfo!;
        expect(result.isFood, isTrue);
        expect(info.name, 'Skyr natur');
        expect(info.amount, 250);
        expect(info.unit, 'g');
        expect(info.category, 'Milchprodukte');
        expect(info.caloriesPer100g, 63);
      },
    );

    test('non-food input throws a readable error', () async {
      final repository = ApiServiceRepository(
        _FakeService('{"type": "unknown"}'),
      );
      expect(
        () => repository.classifyAndProcess('asdf', '', null),
        throwsA(isA<AiException>()),
      );
    });

    test('missing provider throws instead of returning null', () {
      expect(
        () => ApiServiceRepository().fetchFoodNutrition('Apfel', ''),
        throwsA(isA<AiException>()),
      );
    });
  });
}

class _FakeService implements GenerativeService {
  final String response;
  _FakeService(this.response);

  @override
  String get model => 'fake';

  @override
  String get providerName => 'Fake';

  @override
  Future<String> generate(AiRequest request) async => response;
}
