/// Represents a food item in the history/database for quick add
class FoodItem {
  final String id;
  final String name;
  final String category;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String defaultUnit;
  final DateTime lastUsed;

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.defaultUnit = 'g',
    required this.lastUsed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'calories_per_100g': caloriesPer100g,
      'protein_per_100g': proteinPer100g,
      'carbs_per_100g': carbsPer100g,
      'fat_per_100g': fatPer100g,
      'default_unit': defaultUnit,
      'last_used': lastUsed.toIso8601String(),
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String? ?? 'Allgemein',
      caloriesPer100g: (map['calories_per_100g'] as num).toDouble(),
      proteinPer100g: (map['protein_per_100g'] as num?)?.toDouble() ?? 0.0,
      carbsPer100g: (map['carbs_per_100g'] as num?)?.toDouble() ?? 0.0,
      fatPer100g: (map['fat_per_100g'] as num?)?.toDouble() ?? 0.0,
      defaultUnit: map['default_unit'] as String? ?? 'g',
      lastUsed: DateTime.parse(map['last_used'] as String),
    );
  }
}
