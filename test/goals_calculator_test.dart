import 'package:flutter_test/flutter_test.dart';
import 'package:kalorientracker_flutter/data/models/enums.dart';
import 'package:kalorientracker_flutter/data/models/user_profile.dart';
import 'package:kalorientracker_flutter/logic/goals_calculator.dart';

void main() {
  const base = UserProfile(
    age: 20,
    weightKg: 82,
    heightCm: 177,
    gender: Gender.male,
    activityLevel: ActivityLevel.moderatelyActive,
    goal: FitnessGoal.loseWeight,
  );

  test('Mifflin-St Jeor without body fat', () {
    final goals = GoalsCalculator.calculateGoals(base);
    expect(GoalsCalculator.calculateBmr(base).round(), 1831);
    expect(goals.maintenanceCalories, 2838);
    expect(goals.calories, 2338);
    expect(goals.proteinGrams, 164);
  });

  test('Katch-McArdle and lean mass protein with body fat', () {
    final profile = base.copyWith(bodyFatPercent: 18);
    final goals = GoalsCalculator.calculateGoals(profile);
    expect(GoalsCalculator.calculateBmr(profile).round(), 1822);
    expect(goals.proteinGrams, 161);
    expect(goals.fatGrams, greaterThanOrEqualTo((82 * 0.8).round()));
  });

  test('macros add up to the calorie target', () {
    for (final goal in FitnessGoal.values) {
      final goals = GoalsCalculator.calculateGoals(base.copyWith(goal: goal));
      final kcal =
          goals.proteinGrams * 4 + goals.carbsGrams * 4 + goals.fatGrams * 9;
      expect((kcal - goals.calories).abs(), lessThanOrEqualTo(4));
    }
  });

  test('incomplete profile yields empty goals', () {
    expect(GoalsCalculator.calculateGoals(const UserProfile()).calories, 0);
  });

  test('legacy goal index is migrated', () {
    final json = base.toJson()..['goal'] = 2;
    expect(UserProfile.fromJson(json).goal, FitnessGoal.gainWeight);
    expect(UserProfile.fromJson(base.toJson()).goal, FitnessGoal.loseWeight);
  });

  test('prompt summary never contains API keys', () {
    final profile = base.copyWith(claudeApiKey: 'sk-secret');
    expect(profile.toPromptSummary(), isNot(contains('sk-secret')));
  });
}
