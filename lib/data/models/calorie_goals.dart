/// Calorie and macro goals calculated from user profile
class CalorieGoals {
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;

  const CalorieGoals({
    this.calories = 0,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
    };
  }

  factory CalorieGoals.fromJson(Map<String, dynamic> json) {
    return CalorieGoals(
      calories: json['calories'] as int? ?? 0,
      proteinGrams: json['proteinGrams'] as int? ?? 0,
      carbsGrams: json['carbsGrams'] as int? ?? 0,
      fatGrams: json['fatGrams'] as int? ?? 0,
    );
  }
}
