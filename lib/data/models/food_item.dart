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

  FoodItem copyWith({
    String? id,
    String? name,
    String? category,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    String? defaultUnit,
    DateTime? lastUsed,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

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
    final lastUsedRaw = map['last_used'] as String?;
    return FoodItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unbekanntes Essen',
      category: map['category'] as String? ?? 'Allgemein',
      caloriesPer100g: (map['calories_per_100g'] as num?)?.toDouble() ?? 0.0,
      proteinPer100g: (map['protein_per_100g'] as num?)?.toDouble() ?? 0.0,
      carbsPer100g: (map['carbs_per_100g'] as num?)?.toDouble() ?? 0.0,
      fatPer100g: (map['fat_per_100g'] as num?)?.toDouble() ?? 0.0,
      defaultUnit: map['default_unit'] as String? ?? 'g',
      lastUsed: lastUsedRaw != null
          ? DateTime.tryParse(lastUsedRaw) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
