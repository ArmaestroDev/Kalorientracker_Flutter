import '../data/models/user_profile.dart';
import '../data/models/calorie_goals.dart';
import '../data/models/enums.dart';

/// Calculator for daily calorie and macro goals based on user profile.
///
/// BMR uses Katch-McArdle when body fat is known (based on lean mass),
/// otherwise Mifflin-St Jeor. Protein is set per kg (lean) body weight,
/// fat has a hormonal minimum, carbs fill the rest.
class GoalsCalculator {
  static const int _calPerGramProtein = 4;
  static const int _calPerGramCarb = 4;
  static const int _calPerGramFat = 9;

  /// Lean mass needs ~20% more protein per kg than total body weight
  static const double _leanMassProteinBonus = 1.2;
  static const double _minFatPerKg = 0.8;
  static const double _fatRatio = 0.25;

  static CalorieGoals calculateGoals(UserProfile profile) {
    if (profile.weightKg <= 0 ||
        profile.weightKg > 600 ||
        profile.heightCm <= 0 ||
        profile.heightCm > 300 ||
        profile.age <= 0 ||
        profile.age > 120) {
      return const CalorieGoals();
    }

    final bmr = calculateBmr(profile);
    final tdee = bmr * profile.activityLevel.multiplier;

    int targetCalories = (tdee + profile.goal.calorieModifier).round();

    final minCalories = profile.gender == Gender.male ? 1500 : 1200;
    if (targetCalories < minCalories) {
      targetCalories = tdee < minCalories ? tdee.round() : minCalories;
    }

    final leanMass = leanMassKg(profile);
    final proteinGrams = leanMass != null
        ? (leanMass * profile.goal.proteinPerKg * _leanMassProteinBonus).round()
        : (profile.weightKg * profile.goal.proteinPerKg).round();

    final fatGrams = [
      targetCalories * _fatRatio / _calPerGramFat,
      profile.weightKg * _minFatPerKg,
    ].reduce((a, b) => a > b ? a : b).round();

    final carbCalories =
        targetCalories -
        proteinGrams * _calPerGramProtein -
        fatGrams * _calPerGramFat;
    final carbsGrams = carbCalories > 0
        ? (carbCalories / _calPerGramCarb).round()
        : 0;

    return CalorieGoals(
      calories: targetCalories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      maintenanceCalories: tdee.round(),
    );
  }

  static double calculateBmr(UserProfile profile) {
    final leanMass = leanMassKg(profile);
    if (leanMass != null) {
      return 370 + 21.6 * leanMass;
    }
    final base =
        (10 * profile.weightKg) + (6.25 * profile.heightCm) - (5 * profile.age);
    return profile.gender == Gender.male ? base + 5 : base - 161;
  }

  static double? leanMassKg(UserProfile profile) {
    final bf = profile.bodyFatPercent;
    if (bf < 3 || bf > 60) return null;
    return profile.weightKg * (1 - bf / 100);
  }
}
