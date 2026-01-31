import '../data/models/user_profile.dart';
import '../data/models/calorie_goals.dart';
import '../data/models/enums.dart';

/// Calculator for daily calorie and macro goals based on user profile.
///
/// Uses the Mifflin-St Jeor equation (modern standard) and adjusts
/// macro ratios based on specific fitness goals.
class GoalsCalculator {
  static const int _calPerGramProtein = 4;
  static const int _calPerGramCarb = 4;
  static const int _calPerGramFat = 9;

  static CalorieGoals calculateGoals(UserProfile profile) {
    // 1. Sanity Checks & Validation
    // Prevents calculations for incomplete profiles or biological impossibilities
    if (profile.weightKg <= 0 ||
        profile.weightKg > 600 ||
        profile.heightCm <= 0 ||
        profile.heightCm > 300 ||
        profile.age <= 0 ||
        profile.age > 120) {
      return const CalorieGoals();
    }

    // 2. Calculate Basal Metabolic Rate (BMR)
    // Using Mifflin-St Jeor Equation (More accurate than Harris-Benedict for modern populations)
    double bmr =
        (10 * profile.weightKg) + (6.25 * profile.heightCm) - (5 * profile.age);

    if (profile.gender == Gender.male) {
      bmr += 5;
    } else {
      bmr -= 161;
    }

    // 3. Calculate Total Daily Energy Expenditure (TDEE)
    final tdee = bmr * profile.activityLevel.multiplier;

    // 4. Calculate Target Calories
    int targetCalories = (tdee + profile.goal.calorieModifier).round();

    // 5. Safety Floors (Biologically Safe Minimums)
    // Men generally should not eat below 1500, Women below 1200
    // unless under strict medical supervision.
    int minCalories = profile.gender == Gender.male ? 1500 : 1200;

    // Edge case: If a very small, sedentary person's TDEE is below the floor,
    // we shouldn't force them to overeat, but generally, we clamp for safety.
    // Ideally, deficit shouldn't exceed ~20% of TDEE.
    if (targetCalories < minCalories) {
      // If TDEE itself is very low, set target to TDEE (maintenance)
      // rather than arbitrary floor, otherwise use the floor.
      targetCalories = tdee < minCalories ? tdee.round() : minCalories;
    }

    // 6. Calculate Macronutrients based on Goal
    // Protein is calculated as grams per kg body weight (more accurate than %)
    // Fat remains ratio-based, carbs fill the remaining calories.

    double proteinGoalGrams;
    double fatRatio;

    switch (profile.goal) {
      case FitnessGoal.loseWeight:
        // High protein for satiety & muscle retention during deficit
        proteinGoalGrams = 2.0 * profile.weightKg;
        fatRatio = 0.30;
        break;
      case FitnessGoal.gainWeight:
        // Moderate protein, higher carbs for training fuel
        proteinGoalGrams = 1.5 * profile.weightKg;
        fatRatio = 0.25;
        break;
      case FitnessGoal.maintainWeight:
        // Balanced approach
        proteinGoalGrams = 1.7 * profile.weightKg;
        fatRatio = 0.30;
        break;
    }

    // 7. Calculate Grams
    // Protein is fixed by body weight, fat by ratio, carbs fill the rest.
    final int proteinGrams = proteinGoalGrams.round();
    final int proteinCalories = proteinGrams * _calPerGramProtein;

    final int fatCalories = (targetCalories * fatRatio).round();
    final int fatGrams = (fatCalories / _calPerGramFat).round();

    // Carbs get the remaining calories
    final int carbCalories = targetCalories - (proteinCalories + fatCalories);
    final int carbsGrams = (carbCalories / _calPerGramCarb).round();

    return CalorieGoals(
      calories: targetCalories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
    );
  }
}
