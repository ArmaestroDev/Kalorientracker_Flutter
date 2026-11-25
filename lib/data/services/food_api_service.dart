import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'generative_service.dart';

/// Food nutrition info from APIs
class FoodNutritionInfo {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  final double? amount;
  final String? unit;

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
    this.amount,
    this.unit,
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
      amount: (json['amount'] as num?)?.toDouble(),
      unit: _normalizeUnit(json['unit'] as String?),
      category: json['category'] as String?,
      caloriesPer100g: (json['calories_100g'] as num?)?.toDouble(),
      proteinPer100g: (json['protein_100g'] as num?)?.toDouble(),
      carbsPer100g: (json['carbs_100g'] as num?)?.toDouble(),
      fatPer100g: (json['fat_100g'] as num?)?.toDouble(),
    );
  }

  static String? _normalizeUnit(String? unit) {
    final value = unit?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (value == 'g' || value.startsWith('gramm')) return 'g';
    if (value == 'ml' || value.startsWith('milliliter')) return 'ml';
    if (value.startsWith('stk') || value.startsWith('stück')) return 'Stk';
    return 'Portion';
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
  final http.Client _client;

  FoodApiService({http.Client? client}) : _client = client ?? http.Client();

  static double? _asDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(raw.trim().replaceAll(',', '.'));
    }
    return null;
  }

  static String _pickName(Map<String, dynamic> product) {
    for (final key in [
      'product_name_de',
      'product_name',
      'generic_name_de',
      'generic_name',
    ]) {
      final value = (product[key] as String?)?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Unbekanntes Produkt';
  }

  static String _detectUnit(Map<String, dynamic> product) {
    final unitHint =
        '${product['serving_quantity_unit'] ?? ''} ${product['quantity'] ?? ''}'
            .toLowerCase();
    if (RegExp(r'\b(ml|cl|dl|l)\b|\d+\s*(ml|cl|l)\b').hasMatch(unitHint)) {
      return 'ml';
    }
    return 'g';
  }

  Future<FoodNutritionInfo?> getProductByBarcode(String barcode) async {
    final cleaned = barcode.trim();
    if (cleaned.isEmpty) return null;
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('$_baseUrl/api/v0/product/$cleaned.json'),
            headers: const {'User-Agent': 'KalorientrackerFlutter/1.0'},
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AiException(
        'OpenFoodFacts: Zeitüberschreitung. Bitte Internet prüfen.',
      );
    } on http.ClientException {
      throw const AiException(
        'OpenFoodFacts: Keine Verbindung zur Produktdatenbank.',
      );
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AiException(
        'OpenFoodFacts hat mit Status ${response.statusCode} geantwortet.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;
    final status = (decoded['status'] as num?)?.toInt();
    final product = decoded['product'];
    if (status != 1 || product is! Map<String, dynamic>) return null;

    final nutrimentsRaw = product['nutriments'];
    final nutriments = nutrimentsRaw is Map<String, dynamic>
        ? nutrimentsRaw
        : const <String, dynamic>{};

    final kcal100 = _asDouble(nutriments['energy-kcal_100g']);
    final kj100 =
        _asDouble(nutriments['energy-kj_100g']) ??
        _asDouble(nutriments['energy_100g']);
    final c100 = kcal100 ?? (kj100 != null ? kj100 / 4.184 : 0.0);
    final p100 = _asDouble(nutriments['proteins_100g']) ?? 0.0;
    final cb100 = _asDouble(nutriments['carbohydrates_100g']) ?? 0.0;
    final f100 = _asDouble(nutriments['fat_100g']) ?? 0.0;
    final unit = _detectUnit(product);

    return FoodNutritionInfo(
      name: _pickName(product),
      calories: c100.round(),
      protein: p100,
      carbs: cb100,
      fat: f100,
      unit: unit,
      category: 'Gescannte Produkte',
      caloriesPer100g: c100,
      proteinPer100g: p100,
      carbsPer100g: cb100,
      fatPer100g: f100,
    );
  }
}
