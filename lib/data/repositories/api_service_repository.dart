import 'dart:convert';
import '../services/generative_service.dart';
import '../services/food_api_service.dart';

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

USER INPUT:
Activity: "$activityName"
''';
  }
}
