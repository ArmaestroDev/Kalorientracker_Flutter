import 'dart:convert';
import 'dart:typed_data';
import '../models/chat_message.dart';
import '../services/generative_service.dart';
import '../services/food_api_service.dart';

/// Result of unified entry classification - either food or activity
class UnifiedEntry {
  final bool isFood;
  final FoodNutritionInfo? foodInfo;
  final ActivityInfo? activityInfo;

  UnifiedEntry({required this.isFood, this.foodInfo, this.activityInfo});
}

/// Repository that handles all AI and barcode lookups
class ApiServiceRepository {
  GenerativeService? _apiService;
  final FoodApiService _foodApiService = FoodApiService();

  ApiServiceRepository([this._apiService]);

  void updateService(GenerativeService service) {
    _apiService = service;
  }

  GenerativeService get _service {
    final service = _apiService;
    if (service == null) {
      throw const AiException(
        'Kein KI-Anbieter eingerichtet. Bitte im Profil einen API-Schlüssel eintragen.',
      );
    }
    return service;
  }

  Future<FoodNutritionInfo> fetchFoodNutrition(
    String foodName,
    String description,
  ) async {
    final json = await _requestJson(
      AiRequest.single(
        system: _nutritionSystemPrompt,
        prompt: 'Lebensmittel: "$foodName"\nBeschreibung: "$description"',
        jsonOutput: true,
        maxTokens: 2000,
      ),
    );
    final info = FoodNutritionInfo.fromJson(json);
    if (info.calories <= 0) {
      throw AiException('"$foodName" wurde nicht als Lebensmittel erkannt.');
    }
    return info;
  }

  Future<FoodNutritionInfo?> fetchBarCodeNutrition(String code) {
    return _foodApiService.getProductByBarcode(code);
  }

  Future<ActivityInfo> fetchActivityCalories(
    String activityName,
    double? bodyWeightKg,
  ) async {
    final json = await _requestJson(
      AiRequest.single(
        system: _activitySystemPrompt(bodyWeightKg),
        prompt: 'Aktivität: "$activityName"',
        jsonOutput: true,
        maxTokens: 1000,
      ),
    );
    final info = ActivityInfo.fromJson(json);
    if (info.caloriesBurned <= 0) {
      throw AiException('"$activityName" wurde nicht als Aktivität erkannt.');
    }
    return info;
  }

  /// Classify user input as food or activity and return appropriate data
  Future<UnifiedEntry> classifyAndProcess(
    String input,
    String description,
    double? bodyWeightKg,
  ) async {
    final json = await _requestJson(
      AiRequest.single(
        system: _classificationSystemPrompt(bodyWeightKg),
        prompt: 'Eingabe: "$input"\nBeschreibung: "$description"',
        jsonOutput: true,
        maxTokens: 2000,
      ),
    );

    final type = json['type'] as String?;
    if (type == 'activity') {
      final info = ActivityInfo.fromJson(json);
      if (info.caloriesBurned <= 0) {
        throw AiException(
          'Für "$input" konnte kein Verbrauch geschätzt werden.',
        );
      }
      return UnifiedEntry(isFood: false, activityInfo: info);
    }
    if (type == 'food') {
      final info = FoodNutritionInfo.fromJson(json);
      if (info.calories <= 0) {
        throw AiException(
          'Für "$input" konnten keine Nährwerte geschätzt werden.',
        );
      }
      return UnifiedEntry(isFood: true, foodInfo: info);
    }
    throw AiException(
      '"$input" wurde weder als Mahlzeit noch als Aktivität erkannt.',
    );
  }

  Future<FoodNutritionInfo> estimateFoodFromImage(
    Uint8List imageBytes,
    String? description,
  ) async {
    final descText = description != null && description.isNotEmpty
        ? 'Beschreibung des Nutzers: "$description"'
        : 'Keine Beschreibung.';
    final json = await _requestJson(
      AiRequest.single(
        system: _nutritionSystemPrompt,
        prompt:
            'Schätze die Nährwerte des Essens auf diesem Foto. Schätze die sichtbare Portionsgröße.\n$descText',
        jsonOutput: true,
        imageBytes: imageBytes,
        maxTokens: 2000,
      ),
    );
    final info = FoodNutritionInfo.fromJson(json);
    if (info.calories <= 0) {
      throw const AiException('Auf dem Foto wurde kein Essen erkannt.');
    }
    return info;
  }

  Future<String> chat({
    required String system,
    required List<ChatMessage> messages,
    List<AiTool> tools = const [],
    ToolExecutor? onToolCall,
  }) {
    return _service.generate(
      AiRequest(
        system: system,
        messages: messages,
        maxTokens: 16000,
        tools: tools,
        onToolCall: onToolCall,
      ),
    );
  }

  Future<Map<String, dynamic>> _requestJson(AiRequest request) async {
    final response = await _service.generate(request);
    final json = extractJsonObject(response);
    if (json == null) {
      throw AiException(
        '${_service.providerName} hat keine lesbaren Daten geliefert. Bitte erneut versuchen.',
      );
    }
    return json;
  }

  /// Finds the JSON object in a model response, tolerating code fences or
  /// text around it
  static Map<String, dynamic>? extractJsonObject(String response) {
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(response.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static const _foodJsonShape = '''
{
  "name": "string, Name ohne Mengenangabe, z.B. \\"Skyr natur\\"",
  "amount": number oder null, Menge der Portion des Nutzers,
  "unit": "g" | "ml" | "Stk" | "Portion",
  "calories": integer, Kalorien der gesamten Portion,
  "protein": number, Gramm Protein der gesamten Portion,
  "carbs": number, Gramm Kohlenhydrate der gesamten Portion,
  "fat": number, Gramm Fett der gesamten Portion,
  "category": "string, allgemeine Kategorie, z.B. \\"Milchprodukte\\", \\"Fleisch\\", \\"Obst\\", \\"Fertiggerichte\\"",
  "calories_100g": number oder null,
  "protein_100g": number oder null,
  "carbs_100g": number oder null,
  "fat_100g": number oder null
}''';

  static const _nutritionSystemPrompt = '''
Du bist ein präziser Ernährungsassistent für eine deutsche Kalorien-Tracker-App.
Schätze die Nährwerte realistisch anhand typischer deutscher Produkte und Portionsgrößen.
Wenn keine Menge angegeben ist, nimm eine übliche Portion an und gib sie in "amount"/"unit" an.
Die *_100g-Felder beziehen sich auf 100 g bzw. 100 ml; gib sie immer an, wenn sich das Gewicht sinnvoll schätzen lässt.
Wenn die Eingabe kein Lebensmittel ist, setze alle Zahlen auf 0.
Alle Texte auf Deutsch.

JSON-Format:
$_foodJsonShape''';

  static String _weightHint(double? bodyWeightKg) =>
      bodyWeightKg != null && bodyWeightKg > 0
      ? 'Der Nutzer wiegt ${bodyWeightKg.toStringAsFixed(0)} kg.'
      : 'Nimm eine durchschnittliche erwachsene Person an.';

  static String _activitySystemPrompt(double? bodyWeightKg) =>
      '''
Du bist ein Fitness-Assistent für eine deutsche Kalorien-Tracker-App.
Schätze den zusätzlichen Kalorienverbrauch einer Aktivität, also nur den Verbrauch ÜBER dem Ruheumsatz (netto).
${_weightHint(bodyWeightKg)}
Wenn keine Dauer angegeben ist, nimm 60 Minuten an und nenne sie im Namen.
Wenn die Eingabe keine Aktivität ist, setze calories_burned auf 0.

JSON-Format:
{"name": "string, deutscher Name inkl. Dauer, z.B. \\"60 Min BJJ-Training\\"", "calories_burned": integer}''';

  static String _classificationSystemPrompt(double? bodyWeightKg) =>
      '''
Du bist der Assistent einer deutschen Kalorien-Tracker-App.
Entscheide, ob die Eingabe eine Mahlzeit/ein Getränk (type "food") oder eine körperliche Aktivität (type "activity") beschreibt, und liefere die passenden Daten.

Für type "food" gelten diese Regeln:
Schätze die Nährwerte realistisch anhand typischer deutscher Produkte und Portionsgrößen.
Wenn keine Menge angegeben ist, nimm eine übliche Portion an und gib sie in "amount"/"unit" an.
Die *_100g-Felder beziehen sich auf 100 g bzw. 100 ml.
JSON-Format: {"type": "food", ...} mit diesen Feldern:
$_foodJsonShape

Für type "activity" gelten diese Regeln:
Schätze nur den Verbrauch ÜBER dem Ruheumsatz (netto). ${_weightHint(bodyWeightKg)}
Wenn keine Dauer angegeben ist, nimm 60 Minuten an und nenne sie im Namen.
JSON-Format: {"type": "activity", "name": "string inkl. Dauer", "calories_burned": integer}

Alle Texte auf Deutsch.''';
}
