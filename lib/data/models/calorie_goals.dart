/// Calorie and macro goals calculated from user profile
class CalorieGoals {
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int maintenanceCalories;

  const CalorieGoals({
    this.calories = 0,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.maintenanceCalories = 0,
  });

  String toPromptSummary() {
    return '$calories kcal (Erhaltungsbedarf ca. $maintenanceCalories kcal), '
        'Protein ${proteinGrams}g, Kohlenhydrate ${carbsGrams}g, Fett ${fatGrams}g';
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'maintenanceCalories': maintenanceCalories,
    };
  }

  factory CalorieGoals.fromJson(Map<String, dynamic> json) {
    return CalorieGoals(
      calories: json['calories'] as int? ?? 0,
      proteinGrams: json['proteinGrams'] as int? ?? 0,
      carbsGrams: json['carbsGrams'] as int? ?? 0,
      fatGrams: json['fatGrams'] as int? ?? 0,
      maintenanceCalories: json['maintenanceCalories'] as int? ?? 0,
    );
  }
}
