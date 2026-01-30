import 'dart:convert';
import 'dart:typed_data';
import '../services/generative_service.dart';
import '../services/food_api_service.dart';

/// Result of unified entry classification - either food or activity
class UnifiedEntry {
  final bool isFood;
  final FoodNutritionInfo? foodInfo;
  final ActivityInfo? activityInfo;

  UnifiedEntry({required this.isFood, this.foodInfo, this.activityInfo});
}

/// Repository that handles all API calls for nutrition and activity data
class ApiServiceRepository {
  GenerativeService? _apiService;
  final FoodApiService _foodApiService = FoodApiService();

  ApiServiceRepository([this._apiService]);

  void updateService(GenerativeService service) {
    _apiService = service;
  }

  Future<FoodNutritionInfo?> fetchFoodNutrition(
    String foodName,
    String description,
  ) async {
    if (_apiService == null) return null;

    final prompt = _buildFoodPrompt(foodName, description);
    final jsonString = await _apiService!.getApiResponse(prompt);

    if (jsonString == null) return null;

    try {
      final cleanJson = _cleanJsonString(jsonString);
      final json = jsonDecode(cleanJson) as Map<String, dynamic>;
      return FoodNutritionInfo.fromJson(json);
    } catch (e) {
      print('JsonParsingError: Error parsing food nutrition: $e');
      print('Raw response: $jsonString');
      return null;
    }
  }

  Future<FoodNutritionInfo?> fetchBarCodeNutrition(String code) {
    return _foodApiService.getProductByBarcode(code);
  }

  Future<ActivityInfo?> fetchActivityCalories(String activityName) async {
    if (_apiService == null) return null;

    final prompt = _buildActivityPrompt(activityName);
    final jsonString = await _apiService!.getApiResponse(prompt);

    if (jsonString == null) return null;

    try {
      final cleanJson = _cleanJsonString(jsonString);
      final json = jsonDecode(cleanJson) as Map<String, dynamic>;
      return ActivityInfo.fromJson(json);
    } catch (e) {
      print('JsonParsingError: Error parsing activity info: $e');
      print('Raw response: $jsonString');
      return null;
    }
  }

  /// Classify user input as food or activity and return appropriate data
  Future<UnifiedEntry?> classifyAndProcess(
    String input,
    String description,
  ) async {
    if (_apiService == null) return null;

    final prompt = _buildClassificationPrompt(input, description);
    final jsonString = await _apiService!.getApiResponse(prompt);

    if (jsonString == null) return null;

    try {
      final cleanJson = _cleanJsonString(jsonString);
      final json = jsonDecode(cleanJson) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'food') {
        return UnifiedEntry(
          isFood: true,
          foodInfo: FoodNutritionInfo(
            name: json['name'] as String? ?? 'Unknown',
            calories: (json['calories'] as num?)?.toInt() ?? 0,
            protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
            carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
            fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      } else if (type == 'activity') {
        return UnifiedEntry(
          isFood: false,
          activityInfo: ActivityInfo(
            name: json['name'] as String? ?? 'Unknown Activity',
            caloriesBurned: (json['calories_burned'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      return null;
    } catch (e) {
      print('JsonParsingError: Error parsing classification: $e');
      print('Raw response: $jsonString');
      return null;
    }
  }

  /// Estimate food nutrition from an image
  Future<FoodNutritionInfo?> estimateFoodFromImage(
    Uint8List imageBytes,
    String? description,
  ) async {
    if (_apiService == null) return null;

    final prompt = _buildImageFoodPrompt(description);
    final jsonString = await _apiService!.getApiResponseWithImage(
      prompt,
      imageBytes,
    );

    if (jsonString == null) return null;

    try {
      final cleanJson = _cleanJsonString(jsonString);
      final json = jsonDecode(cleanJson) as Map<String, dynamic>;
      return FoodNutritionInfo.fromJson(json);
    } catch (e) {
      print('JsonParsingError: Error parsing image food data: $e');
      print('Raw response: $jsonString');
      return null;
    }
  }

  String _cleanJsonString(String response) {
    var clean = response.trim();
    if (clean.startsWith('```json')) {
      clean = clean.substring(7);
    } else if (clean.startsWith('```')) {
      clean = clean.substring(3);
    }
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }
    return clean.trim();
  }

  String _buildFoodPrompt(String foodName, String description) {
    return '''
You are a nutrition analysis assistant. Respond ONLY with a valid JSON object.
The JSON object must have this exact structure:
{"name": "string", "calories": integer, "protein": double, "carbs": double, "fat": double}

RULES:
1. NEVER respond with anything other than the JSON object. Do not add text like "Here is the JSON:".
2. If the input is not a food, return a JSON object with all values set to 0, e.g., {"name": "Unknown", "calories": 0, "protein": 0.0, "carbs": 0.0, "fat": 0.0}.
3. Capitalize the name of the food in the 'name' field.
4. The "name" string for the json object that you return should be in the german language.
5. IMPORTANT: Include specific details like quantity, brand, or type in the 'name' if provided (e.g., "500g Steak" instead of just "Steak").

USER INPUT:
Food Name: "$foodName"
Description: "$description"
''';
  }

  String _buildActivityPrompt(String activityName) {
    return '''
You are a fitness analysis assistant. Your task is to estimate the calories burned for a given activity. Respond ONLY with a valid JSON object.
Assume the activity is performed by an average person.

The JSON object must have this exact structure:
{"name": "string", "calories_burned": integer}

EXAMPLE:
User Input: "30 minute run"
Your Response:
{"name": "30 Minute Run", "calories_burned": 300}

RULES:
1. NEVER respond with anything other than the JSON object.
2. If the input is not a recognizable activity, return a JSON object with calories_burned set to 0. e.g. {"name": "Unknown Activity", "calories_burned": 0}.
3. Capitalize the name of the activity in the 'name' field.
4. The "name" string for the json object that you return should be in the german language.
5. IMPORTANT: Include duration or intensity in the 'name' if provided (e.g., "30 Min Joggen" instead of just "Joggen").

USER INPUT:
Activity: "$activityName"
''';
  }

  String _buildClassificationPrompt(String input, String description) {
    return '''
You are a smart classification assistant. Your task is to determine if the user input describes a FOOD/MEAL or an ACTIVITY/EXERCISE.

Respond ONLY with a valid JSON object with this structure:
- If it's a FOOD: {"type": "food", "name": "string", "calories": integer, "protein": double, "carbs": double, "fat": double}
- If it's an ACTIVITY: {"type": "activity", "name": "string", "calories_burned": integer}

RULES:
1. NEVER respond with anything other than the JSON object.
2. Classify as "activity" if the input describes physical exercise, sports, walking, running, gym, etc.
3. Classify as "food" if the input describes food, meals, drinks, snacks, etc.
4. The "name" string should be in German language.
5. If you cannot determine the type, default to "food" with 0 values.
6. IMPORTANT: Include specific details like quantity, brand, duration, or intensity in the 'name' if provided by the user.
   - Example: "500g Steak" -> name: "500g Steak" (NOT just "Steak")
   - Example: "30 Min Joggen" -> name: "30 Min Joggen"
   - Example: "Coca Cola Zero" -> name: "Coca Cola Zero"

EXAMPLES:
- "100g Hühnerbrust" -> food
- "30 Minuten Joggen" -> activity
- "Apfel mit Erdnussbutter" -> food
- "1 Stunde Schwimmen" -> activity

USER INPUT:
Input: "$input"
Description: "$description"
''';
  }

  String _buildImageFoodPrompt(String? description) {
    final descText = description != null && description.isNotEmpty
        ? 'User description: "$description"'
        : 'No description provided.';

    return '''
You are a nutrition analysis assistant. Analyze the food in this image and estimate its nutritional values.
$descText

Respond ONLY with a valid JSON object with this exact structure:
{"name": "string", "calories": integer, "protein": double, "carbs": double, "fat": double}

RULES:
1. NEVER respond with anything other than the JSON object.
2. Estimate the portion size visible in the image.
3. The "name" string should be in German language.
4. If you cannot identify the food, return {"name": "Unbekanntes Essen", "calories": 0, "protein": 0.0, "carbs": 0.0, "fat": 0.0}.
5. Be reasonably accurate but err on the side of providing a useful estimate.
6. Include estimated quantity or distinctive features in the 'name' (e.g. "Teller Pasta Carbonara" or "2 Scheiben Toast").
''';
  }
}
