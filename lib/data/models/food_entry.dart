import 'package:uuid/uuid.dart';

/// Represents a food entry in the calorie tracker
class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final DateTime date;
  final double? amount;
  final String? unit;
  final String? foodItemId;

  FoodEntry({
    String? id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.date,
    this.amount,
    this.unit,
    this.foodItemId,
  }) : id = id ?? const Uuid().v4();

  FoodEntry copyWith({
    String? id,
    String? name,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    DateTime? date,
    double? amount,
    String? unit,
    String? foodItemId,
    bool clearAmount = false,
    bool clearUnit = false,
    bool clearFoodItemId = false,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      date: date ?? this.date,
      amount: clearAmount ? null : (amount ?? this.amount),
      unit: clearUnit ? null : (unit ?? this.unit),
      foodItemId: clearFoodItemId ? null : (foodItemId ?? this.foodItemId),
    );
  }

  static String _sqlDate(DateTime d) {
    final local = d.isUtc ? d.toLocal() : d;
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'date': _sqlDate(date),
      'amount': amount,
      'unit': unit,
      'food_item_id': foodItemId,
    };
  }

  factory FoodEntry.fromMap(Map<String, dynamic> map) {
    final dateRaw = map['date'] as String?;
    return FoodEntry(
      id: map['id'] as String? ?? const Uuid().v4(),
      name: map['name'] as String? ?? 'Unbekanntes Essen',
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      protein: (map['protein'] as num?)?.toInt() ?? 0,
      carbs: (map['carbs'] as num?)?.toInt() ?? 0,
      fat: (map['fat'] as num?)?.toInt() ?? 0,
      date: dateRaw != null
          ? DateTime.tryParse(dateRaw) ?? DateTime.now()
          : DateTime.now(),
      amount: (map['amount'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      foodItemId: map['food_item_id'] as String?,
    );
  }
}
