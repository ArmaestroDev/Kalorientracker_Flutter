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
  }) {
    return FoodEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      foodItemId: foodItemId ?? this.foodItemId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'date': date.toIso8601String().split('T')[0],
      'amount': amount,
      'unit': unit,
      'food_item_id': foodItemId,
    };
  }

  factory FoodEntry.fromMap(Map<String, dynamic> map) {
    return FoodEntry(
      id: map['id'] as String? ?? const Uuid().v4(),
      name: map['name'] as String? ?? 'Unbekanntes Essen',
      calories: map['calories'] as int? ?? 0,
      protein: map['protein'] as int? ?? 0,
      carbs: map['carbs'] as int? ?? 0,
      fat: map['fat'] as int? ?? 0,
      date: map['date'] != null
          ? DateTime.parse(map['date'] as String)
          : DateTime.now(),
      amount: (map['amount'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      foodItemId: map['food_item_id'] as String?,
    );
  }
}
