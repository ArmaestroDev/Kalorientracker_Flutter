import 'dart:convert';
import 'package:http/http.dart' as http;

/// Food nutrition info from APIs
class FoodNutritionInfo {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  FoodNutritionInfo({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory FoodNutritionInfo.fromJson(Map<String, dynamic> json) {
    return FoodNutritionInfo(
      name: json['name'] as String? ?? 'Unknown',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Activity info from APIs
class ActivityInfo {
  final String name;
  final int caloriesBurned;

  ActivityInfo({required this.name, required this.caloriesBurned});

  factory ActivityInfo.fromJson(Map<String, dynamic> json) {
    return ActivityInfo(
      name: json['name'] as String? ?? 'Unknown Activity',
      caloriesBurned: (json['calories_burned'] as num?)?.toInt() ?? 0,
    );
  }
}

/// OpenFoodFacts API service for barcode lookups
class FoodApiService {
  static const String _baseUrl = 'https://world.openfoodfacts.org';

  Future<FoodNutritionInfo?> getProductByBarcode(String barcode) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/v0/product/$barcode.json'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final status = json['status'] as int?;

        if (status == 1 && json['product'] != null) {
          final product = json['product'] as Map<String, dynamic>;
          final nutriments = product['nutriments'] as Map<String, dynamic>?;

          return FoodNutritionInfo(
            name: product['product_name'] as String? ?? 'Unbekanntes Produkt',
            calories: (nutriments?['energy-kcal_100g'] as num?)?.toInt() ?? 0,
            protein: (nutriments?['proteins_100g'] as num?)?.toDouble() ?? 0.0,
            carbs:
                (nutriments?['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0,
            fat: (nutriments?['fat_100g'] as num?)?.toDouble() ?? 0.0,
          );
        }
      }
      return null;
    } catch (e) {
      print('FoodApiError: Error fetching barcode data: $e');
      return null;
    }
  }
}
