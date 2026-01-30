import 'dart:convert';
import 'package:http/http.dart' as http;

/// Food nutrition info from APIs
/// Food nutrition info from APIs
class FoodNutritionInfo {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  // Normalized values for DB
  final String? category;
  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  FoodNutritionInfo({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.category,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
  });

  factory FoodNutritionInfo.fromJson(Map<String, dynamic> json) {
    return FoodNutritionInfo(
      name: json['name'] as String? ?? 'Unknown',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String?,
      caloriesPer100g: (json['calories_100g'] as num?)?.toDouble(),
      proteinPer100g: (json['protein_100g'] as num?)?.toDouble(),
      carbsPer100g: (json['carbs_100g'] as num?)?.toDouble(),
      fatPer100g: (json['fat_100g'] as num?)?.toDouble(),
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

          final c100 =
              (nutriments?['energy-kcal_100g'] as num?)?.toDouble() ?? 0.0;
          final p100 =
              (nutriments?['proteins_100g'] as num?)?.toDouble() ?? 0.0;
          final cb100 =
              (nutriments?['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0;
          final f100 = (nutriments?['fat_100g'] as num?)?.toDouble() ?? 0.0;

          return FoodNutritionInfo(
            name: product['product_name'] as String? ?? 'Unbekanntes Produkt',
            // OFF usually gives per 100g, so total calories for "1 portion" is ambiguous unless quantity known.
            // For now, assume 100g OR just use the 100g values as the "calculated" values for now.
            // A better approach would be to check serving size.
            calories: c100.toInt(),
            protein: p100,
            carbs: cb100,
            fat: f100,
            category: 'Gescannte Produkte',
            caloriesPer100g: c100,
            proteinPer100g: p100,
            carbsPer100g: cb100,
            fatPer100g: f100,
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
