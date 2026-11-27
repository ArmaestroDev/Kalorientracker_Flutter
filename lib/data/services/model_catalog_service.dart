import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_model_option.dart';
import '../models/enums.dart';
import 'generative_service.dart';

class ModelCatalogService {
  final http.Client _client;
  final bool _ownsClient;

  ModelCatalogService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  void close() {
    if (_ownsClient) _client.close();
  }

  static const Duration timeout = Duration(seconds: 15);

  static const Map<AiProvider, List<AiModelOption>> fallback = {
    AiProvider.gemini: [
      AiModelOption(
        id: 'gemini-2.5-flash',
        label: 'Gemini 2.5 Flash',
        free: true,
      ),
      AiModelOption(
        id: 'gemini-2.5-flash-lite',
        label: 'Gemini 2.5 Flash-Lite',
        free: true,
      ),
    ],
    AiProvider.claude: [
      AiModelOption(
        id: 'claude-sonnet-5-5',
        label: 'Claude Sonnet 5.5',
        free: false,
      ),
      AiModelOption(
        id: 'claude-haiku-5-5',
        label: 'Claude Haiku 5.5',
        free: false,
      ),
      AiModelOption(
        id: 'claude-opus-5-5',
        label: 'Claude Opus 5.5',
        free: false,
      ),
    ],
    AiProvider.openai: [
      AiModelOption(id: 'gpt-5-mini', label: 'GPT-5 mini', free: false),
      AiModelOption(id: 'gpt-5', label: 'GPT-5', free: false),
    ],
    AiProvider.grok: [
      AiModelOption(id: 'grok-4', label: 'Grok 4', free: false),
      AiModelOption(id: 'grok-3-mini', label: 'Grok 3 mini', free: false),
    ],
  };

  Future<List<AiModelOption>> fetch(AiProvider provider, String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) return fallback[provider]!;

    final (Uri uri, Map<String, String> headers) = switch (provider) {
      AiProvider.gemini => (
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000',
        ),
        {'x-goog-api-key': key},
      ),
      AiProvider.claude => (
        Uri.parse('https://api.anthropic.com/v1/models?limit=100'),
        {'x-api-key': key, 'anthropic-version': '2023-06-01'},
      ),
      AiProvider.openai => (
        Uri.parse('https://api.openai.com/v1/models'),
        {'Authorization': 'Bearer $key'},
      ),
      AiProvider.grok => (
        Uri.parse('https://api.x.ai/v1/models'),
        {'Authorization': 'Bearer $key'},
      ),
    };

    final response = await _get(provider, uri, headers);
    final json = _decode(provider, response);

    final models = switch (provider) {
      AiProvider.gemini => _gemini(provider, json),
      AiProvider.claude => _claude(provider, json),
      AiProvider.openai => _openAiLike(provider, json, openAi: true),
      AiProvider.grok => _openAiLike(provider, json, openAi: false),
    };

    if (models.isEmpty) return fallback[provider]!;
    return models;
  }

  Future<http.Response> _get(
    AiProvider provider,
    Uri uri,
    Map<String, String> headers,
  ) async {
    final http.Response response;
    try {
      response = await _client.get(uri, headers: headers).timeout(timeout);
    } on TimeoutException {
      throw AiException(
        '${provider.label}: Modellliste konnte nicht geladen werden (keine Verbindung).',
      );
    } on http.ClientException {
      throw AiException(
        '${provider.label}: Modellliste konnte nicht geladen werden (keine Verbindung).',
      );
    }
    if (response.statusCode != 200) {
      throw AiException(
        '${provider.label}: Modellliste konnte nicht geladen werden (HTTP ${response.statusCode}). API-Schlüssel prüfen.',
      );
    }
    return response;
  }

  Object? _decode(AiProvider provider, http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw _unexpected(provider);
    }
  }

  AiException _unexpected(AiProvider provider) => AiException(
    '${provider.label}: Unerwartete Antwort beim Laden der Modelle.',
  );

  List<AiModelOption> _gemini(AiProvider provider, Object? json) {
    final rawModels = json is Map ? json['models'] : null;
    if (rawModels is! List) throw _unexpected(provider);

    const blocked = [
      'image',
      'tts',
      'audio',
      'live',
      'embedding',
      'robotics',
      'computer-use',
      'native',
      'exp',
      'thinking',
      '-latest',
    ];

    final options = <AiModelOption>[];
    for (final entry in rawModels) {
      if (entry is! Map) continue;
      final name = entry['name'];
      if (name is! String) continue;
      final methods = entry['supportedGenerationMethods'];
      if (methods is! List || !methods.contains('generateContent')) continue;

      final id = name.startsWith('models/') ? name.substring(7) : name;
      if (!id.startsWith('gemini-')) continue;
      if (!id.contains('flash')) continue;
      if (blocked.any(id.contains)) continue;

      final displayName = entry['displayName'];
      options.add(
        AiModelOption(
          id: id,
          label: displayName is String && displayName.isNotEmpty
              ? displayName
              : id,
          free: true,
        ),
      );
    }

    options.sort((a, b) {
      final versionCompare = _geminiVersion(b.id).compareTo(
        _geminiVersion(a.id),
      );
      if (versionCompare != 0) return versionCompare;
      final aPreview = a.id.contains('preview');
      final bPreview = b.id.contains('preview');
      if (aPreview != bPreview) return aPreview ? 1 : -1;
      final aLite = a.id.contains('lite');
      final bLite = b.id.contains('lite');
      if (aLite != bLite) return aLite ? 1 : -1;
      return a.id.compareTo(b.id);
    });
    return options;
  }

  static double _geminiVersion(String id) {
    final match = RegExp(r'^gemini-(\d+(?:\.\d+)?)').firstMatch(id);
    if (match == null) return 0;
    return double.tryParse(match.group(1)!) ?? 0;
  }

  List<AiModelOption> _claude(AiProvider provider, Object? json) {
    final rawData = json is Map ? json['data'] : null;
    if (rawData is! List) throw _unexpected(provider);

    final options = <AiModelOption>[];
    for (final entry in rawData) {
      if (entry is! Map) continue;
      final id = entry['id'];
      if (id is! String || !id.startsWith('claude-')) continue;
      final displayName = entry['display_name'];
      options.add(
        AiModelOption(
          id: id,
          label: displayName is String && displayName.isNotEmpty
              ? displayName
              : id,
          free: false,
        ),
      );
    }
    return options;
  }

  List<AiModelOption> _openAiLike(
    AiProvider provider,
    Object? json, {
    required bool openAi,
  }) {
    final rawData = json is Map ? json['data'] : null;
    if (rawData is! List) throw _unexpected(provider);

    const excluded = [
      'audio',
      'realtime',
      'transcribe',
      'tts',
      'image',
      'search',
      'instruct',
      'embedding',
      'codex',
      'moderation',
    ];
    final chatId = RegExp(r'^(gpt-\d|o\d)');
    final dated = RegExp(r'\d{4}-\d{2}-\d{2}');

    final options = <AiModelOption>[];
    final created = <String, num>{};
    for (final entry in rawData) {
      if (entry is! Map) continue;
      final id = entry['id'];
      if (id is! String) continue;

      if (openAi) {
        if (!chatId.hasMatch(id)) continue;
        if (excluded.any(id.contains)) continue;
        if (dated.hasMatch(id)) continue;
      } else {
        if (!id.startsWith('grok')) continue;
        if (id.contains('image')) continue;
      }

      final rawCreated = entry['created'];
      created[id] = rawCreated is num ? rawCreated : 0;
      options.add(AiModelOption(id: id, label: id, free: false));
    }

    options.sort((a, b) => created[b.id]!.compareTo(created[a.id]!));
    return options;
  }
}
