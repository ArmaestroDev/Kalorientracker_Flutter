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

  FoodEntry({
    String? id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.date,
  }) : id = id ?? const Uuid().v4();

  FoodEntry copyWith({
    String? id,
    String? name,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    DateTime? date,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      date: date ?? this.date,
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
      'date': date.toIso8601String().split('T')[0], // Store only the date part
    };
  }

  factory FoodEntry.fromMap(Map<String, dynamic> map) {
    return FoodEntry(
      id: map['id'] as String,
      name: map['name'] as String,
      calories: map['calories'] as int,
      protein: map['protein'] as int,
      carbs: map['carbs'] as int,
      fat: map['fat'] as int,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
