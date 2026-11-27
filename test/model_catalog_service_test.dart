import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kalorientracker_flutter/data/models/ai_model_option.dart';
import 'package:kalorientracker_flutter/data/models/enums.dart';
import 'package:kalorientracker_flutter/data/services/generative_service.dart';
import 'package:kalorientracker_flutter/data/services/model_catalog_service.dart';

http.Response jsonResponse(Object json, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(json)), status);

Map<String, dynamic> geminiModel(
  String name, [
  List<String> methods = const ['generateContent'],
]) => {
  'name': 'models/$name',
  'displayName': name,
  'supportedGenerationMethods': methods,
};

void main() {
  group('ModelCatalogService', () {
    test('empty key returns gemini fallback without network call', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return jsonResponse({'models': []});
      });
      final service = ModelCatalogService(client: client);

      final models = await service.fetch(AiProvider.gemini, '   ');

      expect(called, isFalse);
      expect(models.map((m) => m.id), [
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite',
      ]);
      expect(models.every((m) => m.free), isTrue);
      service.close();
    });

    test('gemini filters flash models and sorts them', () async {
      final client = MockClient(
        (request) async => jsonResponse({
          'models': [
            geminiModel('gemini-2.5-flash'),
            geminiModel('gemini-2.5-flash-lite'),
            geminiModel('gemini-3.0-flash-preview'),
            geminiModel('gemini-2.5-pro'),
            geminiModel('gemini-2.5-flash-image'),
            geminiModel('text-embedding-004', ['embedContent']),
            geminiModel('gemini-2.0-flash'),
          ],
        }),
      );
      final service = ModelCatalogService(client: client);

      final models = await service.fetch(AiProvider.gemini, 'test-key');

      expect(models.map((m) => m.id), [
        'gemini-3.0-flash-preview',
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite',
        'gemini-2.0-flash',
      ]);
      expect(models.every((m) => m.free), isTrue);
      service.close();
    });

    test('openai keeps chat models only, newest first', () async {
      final client = MockClient(
        (request) async => jsonResponse({
          'data': [
            {'id': 'gpt-5', 'created': 3},
            {'id': 'gpt-5-mini', 'created': 2},
            {'id': 'gpt-4o-audio-preview', 'created': 5},
            {'id': 'gpt-5-2025-08-07', 'created': 4},
            {'id': 'whisper-1', 'created': 6},
            {'id': 'o3', 'created': 1},
          ],
        }),
      );
      final service = ModelCatalogService(client: client);

      final models = await service.fetch(AiProvider.openai, 'test-key');

      expect(models.map((m) => m.id), ['gpt-5', 'gpt-5-mini', 'o3']);
      expect(models.every((m) => !m.free), isTrue);
      service.close();
    });

    test('HTTP 401 throws AiException', () async {
      final client = MockClient(
        (request) async => http.Response('{"error":"invalid key"}', 401),
      );
      final service = ModelCatalogService(client: client);

      await expectLater(
        service.fetch(AiProvider.openai, 'test-key'),
        throwsA(isA<AiException>()),
      );
      service.close();
    });

    test('AiModelOption json round trip', () {
      const option = AiModelOption(
        id: 'gemini-2.5-flash',
        label: 'Gemini 2.5 Flash',
        free: true,
      );

      final restored = AiModelOption.fromJson(
        jsonDecode(jsonEncode(option.toJson())) as Map<String, dynamic>,
      );

      expect(restored, option);
      expect(restored.label, 'Gemini 2.5 Flash');
      expect(restored.free, isTrue);
    });
  });
}
