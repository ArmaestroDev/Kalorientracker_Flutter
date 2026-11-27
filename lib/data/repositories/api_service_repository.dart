import 'dart:convert';
import 'dart:typed_data';
import '../models/chat_message.dart';
import '../models/user_plan.dart';
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
  final FoodApiService _foodApiService;

  ApiServiceRepository([this._apiService, FoodApiService? foodApiService])
    : _foodApiService = foodApiService ?? FoodApiService();

  void updateService(GenerativeService service) {
    if (!identical(_apiService, service)) {
      _apiService?.close();
      _apiService = service;
    }
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

  Future<void> ping() async {
    final text = await _service.generate(
      AiRequest.single(
        system: 'Antworte nur mit OK.',
        prompt: 'Test',
        maxTokens: 256,
      ),
    );
    if (text.trim().isEmpty) {
      throw const AiException('Leere Antwort vom Modell.');
    }
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

  /// Classifies user input into every mentioned food and activity
  Future<List<UnifiedEntry>> classifyAndProcessAll(
    String input,
    String description,
    double? bodyWeightKg,
  ) async {
    final json = await _requestJson(
      AiRequest.single(
        system: _classificationSystemPrompt(bodyWeightKg),
        prompt: 'Eingabe: "$input"\nBeschreibung: "$description"',
        jsonOutput: true,
        maxTokens: 8192,
      ),
    );

    final rawItems = json['items'];
    final List<dynamic> elements;
    if (rawItems is List) {
      elements = rawItems;
    } else if (json.containsKey('type')) {
      elements = [json];
    } else {
      elements = const [];
    }

    final entries = <UnifiedEntry>[];
    for (final element in elements) {
      if (element is! Map) continue;
      final item = Map<String, dynamic>.from(element);
      final type = item['type'];
      if (type == 'food') {
        final info = FoodNutritionInfo.fromJson(item);
        if (info.calories > 0) {
          entries.add(UnifiedEntry(isFood: true, foodInfo: info));
        }
      } else if (type == 'activity') {
        final info = ActivityInfo.fromJson(item);
        if (info.caloriesBurned > 0) {
          entries.add(UnifiedEntry(isFood: false, activityInfo: info));
        }
      }
    }

    if (entries.isEmpty) {
      final label = input.length > 60 ? '${input.substring(0, 60)}…' : input;
      throw AiException(
        '"$label" wurde weder als Mahlzeit noch als Aktivität erkannt.',
      );
    }
    return entries;
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

  /// Extracts a clean, structured Markdown version of a scanned or dense PDF plan
  Future<String> extractPlanFromPdf(
    Uint8List pdfBytes,
    PlanType type,
    String fileName,
  ) {
    return _service.generate(
      AiRequest.single(
        system:
            'Du extrahierst einen ${type.label} aus einer PDF-Datei für einen persönlichen Ernährungs- und Fitnesscoach. '
            'Gib den vollständigen Inhalt strukturiert als klares deutsches Markdown wieder (Wochentage, Mahlzeiten, Mengen/Makros, Übungen, Sätze/Wiederholungen, Regeln). '
            'Lasse keine wichtigen Angaben weg und erfinde nichts hinzu.',
        prompt:
            'Bitte lies die angehängte PDF-Datei "$fileName" (${type.label}) vollständig aus und fasse alle Plandaten übersichtlich zusammen.',
        pdfBytes: pdfBytes,
        maxTokens: 8000,
      ),
    );
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
    if (json != null) return json;
    final retry = await _service.generate(request);
    final retried = extractJsonObject(retry);
    if (retried != null) return retried;
    throw AiException(
      '${_service.providerName} hat keine lesbaren Daten geliefert. Bitte erneut versuchen oder die Eingabe kürzer fassen.',
    );
  }

  /// Finds the JSON object in a model response, tolerating code fences or
  /// text around it
  static Map<String, dynamic>? extractJsonObject(String response) {
    final text = _stripFences(response);
    if (text.startsWith('[')) {
      final arrayEnd = text.lastIndexOf(']');
      if (arrayEnd <= 0) return null;
      try {
        final decoded = jsonDecode(text.substring(0, arrayEnd + 1));
        return decoded is List ? {'items': decoded} : null;
      } catch (_) {
        return null;
      }
    }
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

  static String _stripFences(String value) {
    var text = value.trim();
    if (text.startsWith('```')) {
      text = text.substring(3);
      final newline = text.indexOf('\n');
      if (newline >= 0) text = text.substring(newline + 1);
    }
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3);
    }
    return text.trim();
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
Die Eingabe kann MEHRERE Lebensmittel, Getränke und/oder Aktivitäten enthalten.
Erzeuge für JEDES einzelne genannte Lebensmittel, Getränk und jede Aktivität genau ein Element in "items". Fasse verschiedene Lebensmittel niemals zu einem Element zusammen und lasse keines weg.
Beispiel: "200 g Reis, 150 g Hähnchen und ein Apfel" ergibt 3 food-Elemente (Reis 200 g, Hähnchen 150 g, Apfel 1 Stk).
Verwende für jedes Element genau die Menge, die der Nutzer für dieses Element genannt hat (z. B. "200 g Reis" → amount 200, unit "g"). Ist für ein Element keine Menge genannt, nimm eine übliche Portion an.
Eine einzelne Speise, die der Nutzer als ein Ding benennt (z. B. "Döner", "Spaghetti Bolognese 400 g"), bleibt EIN Element.
Eine optionale "Beschreibung" gilt als Kontext für die gesamte Eingabe (z. B. Ort, Zubereitung).

Für type "food" gelten diese Regeln:
Schätze die Nährwerte realistisch anhand typischer deutscher Produkte und Portionsgrößen.
Die *_100g-Felder beziehen sich auf 100 g bzw. 100 ml.
Felder eines food-Elements:
$_foodJsonShape

Für type "activity" gelten diese Regeln:
Schätze nur den Verbrauch ÜBER dem Ruheumsatz (netto). ${_weightHint(bodyWeightKg)}
Wenn keine Dauer angegeben ist, nimm 60 Minuten an und nenne sie im Namen.
Felder eines activity-Elements: {"type": "activity", "name": "string inkl. Dauer", "calories_burned": integer}

Alle Texte auf Deutsch. Halte Zahlen kurz (max. 1 Nachkommastelle).
Antworte NUR mit dem JSON-Objekt, ohne Text drumherum.

JSON-Format:
{"items": [{"type": "food", ...Felder wie oben...}, {"type": "activity", "name": "...", "calories_burned": integer}]}''';
}
