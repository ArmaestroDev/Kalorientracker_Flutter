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

    test('2.5 Flash turns thinking off for JSON requests', () async {
      late Map<String, dynamic> body;
      final service = GeminiApiService(
        'k',
        'gemini-2.5-flash',
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{}'},
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
      expect(
        await service.generate(
          AiRequest.single(system: 's', prompt: 'p', jsonOutput: true),
        ),
        '{}',
      );
      final config =
          (body['generationConfig'] as Map<String, dynamic>)['thinkingConfig']
              as Map<String, dynamic>;
      expect(config['thinkingBudget'], 0);
      expect(config.containsKey('thinkingLevel'), isFalse);
    });

    test('2.5 Flash turns thinking off for a small token budget', () async {
      late Map<String, dynamic> body;
      final service = GeminiApiService(
        'k',
        'gemini-2.5-flash',
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'OK'},
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
      expect(
        await service.generate(
          AiRequest.single(system: 's', prompt: 'p', maxTokens: 256),
        ),
        'OK',
      );
      final config =
          (body['generationConfig'] as Map<String, dynamic>)['thinkingConfig']
              as Map<String, dynamic>;
      expect(config['thinkingBudget'], 0);
    });

    test('2.0 Flash sends no thinkingConfig', () async {
      late Map<String, dynamic> body;
      final service = GeminiApiService(
        'k',
        'gemini-2.0-flash',
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{}'},
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
      await service.generate(
        AiRequest.single(system: 's', prompt: 'p', jsonOutput: true),
      );
      final config = body['generationConfig'] as Map<String, dynamic>;
      expect(config.containsKey('thinkingConfig'), isFalse);
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

    test('cut-off JSON answer is reported as truncated', () async {
      final service = GeminiApiService(
        'k',
        'gemini-3.8-flash',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"items": ['},
                    ],
                  },
                  'finishReason': 'MAX_TOKENS',
                },
              ],
            }),
            200,
          ),
        ),
      );
      expect(
        () => service.generate(
          AiRequest.single(
            system: 's',
            prompt: 'p',
            jsonOutput: true,
            maxTokens: 8192,
          ),
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('abgeschnitten'),
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

    test('extracts a top-level JSON array as item list', () {
      expect(
        ApiServiceRepository.extractJsonObject(
          '```json\n[{"type": "food", "calories": 80}]\n```',
        ),
        {
          'items': [
            {'type': 'food', 'calories': 80},
          ],
        },
      );
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
        final result = await repository.classifyAndProcessAll(
          '250g Skyr',
          '',
          82,
        );
        expect(result, hasLength(1));
        final entry = result.first;
        final info = entry.foodInfo!;
        expect(entry.isFood, isTrue);
        expect(info.name, 'Skyr natur');
        expect(info.amount, 250);
        expect(info.unit, 'g');
        expect(info.category, 'Milchprodukte');
        expect(info.caloriesPer100g, 63);
      },
    );

    test('several foods and one activity become separate entries', () async {
      final repository = ApiServiceRepository(
        _FakeService(
          jsonEncode({
            'items': [
              {
                'type': 'food',
                'name': 'Reis',
                'amount': 200,
                'unit': 'g',
                'calories': 260,
                'protein': 5,
                'carbs': 56,
                'fat': 1,
                'category': 'Beilagen',
                'calories_100g': 130,
              },
              {
                'type': 'food',
                'name': 'Apfel',
                'amount': 1,
                'unit': 'Stk',
                'calories': 80,
                'protein': 0.5,
                'carbs': 18,
                'fat': 0.3,
                'category': 'Obst',
                'calories_100g': 52,
              },
              {
                'type': 'activity',
                'name': '30 Min Joggen',
                'calories_burned': 250,
              },
            ],
          }),
        ),
      );
      final result = await repository.classifyAndProcessAll(
        '200 g Reis, ein Apfel, danach 30 min Joggen',
        '',
        null,
      );
      expect(result, hasLength(3));
      expect(result[0].isFood, isTrue);
      expect(result[0].foodInfo!.name, 'Reis');
      expect(result[0].foodInfo!.amount, 200);
      expect(result[1].isFood, isTrue);
      expect(result[1].foodInfo!.name, 'Apfel');
      expect(result[2].isFood, isFalse);
      expect(result[2].activityInfo!.caloriesBurned, 250);
    });

    test('items without calories are dropped', () async {
      final repository = ApiServiceRepository(
        _FakeService(
          jsonEncode({
            'items': [
              {
                'type': 'food',
                'name': 'Unbekannt',
                'calories': 0,
                'protein': 0,
                'carbs': 0,
                'fat': 0,
              },
              {
                'type': 'food',
                'name': 'Apfel',
                'amount': 1,
                'unit': 'Stk',
                'calories': 80,
                'protein': 0.5,
                'carbs': 18,
                'fat': 0.3,
              },
            ],
          }),
        ),
      );
      final result = await repository.classifyAndProcessAll(
        'ein Apfel',
        '',
        null,
      );
      expect(result, hasLength(1));
      expect(result.first.foodInfo!.name, 'Apfel');
    });

    test('unknown type and empty item list throw', () async {
      expect(
        () => ApiServiceRepository(
          _FakeService('{"type": "unknown"}'),
        ).classifyAndProcessAll('asdf', '', null),
        throwsA(isA<AiException>()),
      );
      expect(
        () => ApiServiceRepository(
          _FakeService('{"items": []}'),
        ).classifyAndProcessAll('asdf', '', null),
        throwsA(isA<AiException>()),
      );
    });

    test('a top-level JSON array is used as the item list', () async {
      final repository = ApiServiceRepository(
        _FakeService(
          jsonEncode([
            {
              'type': 'food',
              'name': 'Apfel',
              'amount': 1,
              'unit': 'Stk',
              'calories': 80,
              'protein': 0.5,
              'carbs': 18,
              'fat': 0.3,
            },
          ]),
        ),
      );
      final result = await repository.classifyAndProcessAll(
        'ein Apfel',
        '',
        null,
      );
      expect(result, hasLength(1));
      expect(result.first.foodInfo!.name, 'Apfel');
    });

    test('unreadable first answer is retried once', () async {
      final repository = ApiServiceRepository(
        _FakeService.responses([
          'abc {',
          jsonEncode({
            'items': [
              {
                'type': 'food',
                'name': 'Apfel',
                'amount': 1,
                'unit': 'Stk',
                'calories': 80,
                'protein': 0.5,
                'carbs': 18,
                'fat': 0.3,
              },
            ],
          }),
        ]),
      );
      final result = await repository.classifyAndProcessAll(
        'ein Apfel',
        '',
        null,
      );
      expect(result, hasLength(1));
      expect(result.first.foodInfo!.name, 'Apfel');
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
  final List<String> responses;
  int _calls = 0;

  _FakeService(String response) : responses = [response];

  _FakeService.responses(this.responses);

  @override
  String get model => 'fake';

  @override
  String get providerName => 'Fake';

  @override
  Future<String> generate(AiRequest request) async {
    final index = _calls < responses.length ? _calls : responses.length - 1;
    _calls++;
    return responses[index];
  }

  @override
  void close() {}
}
