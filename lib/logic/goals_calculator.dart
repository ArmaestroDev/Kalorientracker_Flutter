import '../data/models/user_profile.dart';
import '../data/models/calorie_goals.dart';
import '../data/models/enums.dart';

/// Calculator for daily calorie and macro goals based on user profile
class GoalsCalculator {
  /// Calculates goals using Harris-Benedict equation for BMR
  static CalorieGoals calculateGoals(UserProfile profile) {
    if (profile.weightKg <= 0 || profile.heightCm <= 0 || profile.age <= 0) {
      return const CalorieGoals();
    }

    // 1. Calculate Basal Metabolic Rate (BMR) using Harris-Benedict Equation
    double bmr;
    if (profile.gender == Gender.male) {
      bmr =
          88.362 +
          (13.397 * profile.weightKg) +
          (4.799 * profile.heightCm) -
          (5.677 * profile.age);
    } else {
      bmr =
          447.593 +
          (9.247 * profile.weightKg) +
          (3.098 * profile.heightCm) -
          (4.330 * profile.age);
    }

    // 2. Calculate Total Daily Energy Expenditure (TDEE)
    final tdee = bmr * profile.activityLevel.multiplier;

    // 3. Adjust for fitness goal and add a safety floor
    int targetCalories = (tdee + profile.goal.calorieModifier).round();
    if (targetCalories < 1200) targetCalories = 1200;

    // 4. Calculate Macronutrients (40% Carbs, 30% Protein, 30% Fat)
    final proteinGrams = ((targetCalories * 0.30) / 4)
        .round(); // 4 cal per gram
    final carbsGrams = ((targetCalories * 0.40) / 4).round(); // 4 cal per gram
    final fatGrams = ((targetCalories * 0.30) / 9).round(); // 9 cal per gram

    return CalorieGoals(
      calories: targetCalories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
    );
  }
}
