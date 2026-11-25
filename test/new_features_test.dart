import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kalorientracker_flutter/data/models/activity_entry.dart';
import 'package:kalorientracker_flutter/data/models/calorie_goals.dart';
import 'package:kalorientracker_flutter/data/models/food_entry.dart';
import 'package:kalorientracker_flutter/data/models/user_plan.dart';
import 'package:kalorientracker_flutter/data/models/user_profile.dart';
import 'package:kalorientracker_flutter/data/models/weight_entry.dart';
import 'package:kalorientracker_flutter/data/services/food_api_service.dart';
import 'package:kalorientracker_flutter/data/services/generative_service.dart';
import 'package:kalorientracker_flutter/logic/assistant_context_builder.dart';
import 'package:kalorientracker_flutter/logic/coach_tools.dart';
import 'package:kalorientracker_flutter/logic/nutrition_stats.dart';
import 'package:kalorientracker_flutter/ui/widgets/dialogs/edit_food_dialog.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  group('WeekStatus skipped days and DST', () {
    test('skipped past days do not inflate perRemainingDay', () {
      // Wednesday, Mon & Tue skipped, daily goal = 2297 (7 * 2297 = 16079)
      final monday = DateTime(2026, 11, 23);
      final wednesday = addDays(monday, 2);
      final days = NutritionStats.daily(
        const [],
        const [],
        monday,
        addDays(monday, 6),
      );

      final week = NutritionStats.weekStatus(
        days,
        wednesday,
        dailyGoal: 2297,
        eatBackActivity: false,
      );

      expect(week.unloggedPastDays, 2);
      expect(week.remainingDays, 5);
      expect(week.budget, 2297 * 5);
      expect(week.remaining, 2297 * 5);
      expect(week.perRemainingDay, 2297);
    });

    test('spring DST transition still counts 7 days from Monday', () {
      // Last Sunday of March 2026 is 29 March (EU DST spring-forward)
      final dstMonday = DateTime(2026, 3, 23);
      final days = NutritionStats.daily(
        const [],
        const [],
        dstMonday,
        addDays(dstMonday, 6),
      );
      final week = NutritionStats.weekStatus(
        days,
        dstMonday,
        dailyGoal: 2200,
        eatBackActivity: false,
      );
      expect(week.remainingDays, 7);
      expect(week.perRemainingDay, 2200);
    });
  });

  group('Plans & AI Coach pipeline', () {
    test('AssistantContextBuilder injects active plans and omits inactive', () {
      final today = DateTime(2026, 11, 25);
      final days = NutritionStats.daily(const [], const [], today, today);
      final prompt = AssistantContextBuilder.build(
        profile: const UserProfile(age: 25, weightKg: 80, heightCm: 180),
        goals: const CalorieGoals(
          calories: 2500,
          proteinGrams: 170,
          carbsGrams: 270,
          fatGrams: 80,
          maintenanceCalories: 2500,
        ),
        now: DateTime(2026, 11, 25, 12, 0),
        selectedDate: addDays(today, -1),
        dayFoods: [
          FoodEntry(
            name: 'Haferflocken',
            calories: 400,
            protein: 15,
            carbs: 65,
            fat: 7,
            date: today,
          ),
        ],
        dayActivities: const [],
        dayBudget: 2500,
        week: NutritionStats.weekStatus(
          days,
          today,
          dailyGoal: 2500,
          eatBackActivity: false,
        ),
        recentDays: const [],
        recentWeights: const [],
        plans: [
          UserPlan(
            id: 'p1',
            type: PlanType.meal,
            title: 'Aufbauplan',
            content: 'Morgens: 100g Haferflocken + 30g Whey',
            isActive: true,
          ),
          UserPlan(
            id: 'p2',
            type: PlanType.training,
            title: 'Alter Plan',
            content: 'Sollte nicht erscheinen',
            isActive: false,
          ),
        ],
        selectedDayFoods: const [],
        selectedDayActivities: const [],
        selectedDayBudget: 2500,
      );

      expect(prompt, contains('## Persönliche Pläne'));
      expect(prompt, contains('Ernährungsplan: Aufbauplan'));
      expect(prompt, contains('100g Haferflocken + 30g Whey'));
      expect(prompt, isNot(contains('Sollte nicht erscheinen')));
      expect(prompt, contains('## Heute'));
      expect(prompt, contains('## Geöffneter Tag'));
    });

    test('CoachTools reads plans, validates dates, and logs entries', () async {
      final loggedFoods = <FoodEntry>[];
      final loggedActivities = <ActivityEntry>[];
      final loggedWeights = <WeightEntry>[];

      final tools = CoachTools(
        loadFoods: (_, _) async => [],
        loadActivities: (_, _) async => [],
        loadWeights: (_, _) async => [],
        loadPlans: () async => [
          UserPlan(
            id: 'plan-1',
            type: PlanType.training,
            title: 'Push Pull Legs',
            content: 'Montag: Push, Mittwoch: Pull, Freitag: Legs',
          ),
        ],
        onLogFood: (e) async => loggedFoods.add(e),
        onLogActivity: (e) async => loggedActivities.add(e),
        onLogWeight: (e) async => loggedWeights.add(e),
        profile: const UserProfile(),
        goals: const CalorieGoals(),
        today: DateTime(2026, 11, 25),
      );

      final planRes = await tools.execute('get_user_plan', {
        'plan_id': 'plan-1',
      });
      expect(planRes['inhalt'], contains('Montag: Push'));

      final badRange = await tools.execute('get_period_summary', {
        'start_date': 'not-a-date',
        'end_date': '2026-11-25',
        'group_by': 'day',
      });
      expect(badRange['error'], isNotNull);

      final foodRes = await tools.execute('log_food_entry', {
        'name': 'Skyr',
        'calories': 160,
        'protein': 28,
        'carbs': 10,
        'fat': 1,
      });
      expect(foodRes['status'], 'gespeichert');
      expect(loggedFoods.single.name, 'Skyr');

      await tools.execute('log_activity_entry', {
        'name': '45 Min Joggen',
        'calories_burned': 450,
      });
      expect(loggedActivities.single.caloriesBurned, 450);

      await tools.execute('log_weight_entry', {'weight_kg': 81.2});
      expect(loggedWeights.single.weightKg, 81.2);
    });
  });

  group('FoodApiService resilience', () {
    test('handles string numbers, fallback names, and ml detection', () async {
      final api = FoodApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'product_name': '',
                'product_name_de': 'Haferdrink Barista',
                'quantity': '1000 ml',
                'nutriments': {
                  'energy-kcal_100g': '59',
                  'proteins_100g': '1.1',
                  'carbohydrates_100g': '6,8',
                  'fat_100g': '3.0',
                },
              },
            }),
            200,
          ),
        ),
      );

      final info = await api.getProductByBarcode('4001234567890');
      expect(info, isNotNull);
      expect(info!.name, 'Haferdrink Barista');
      expect(info.unit, 'ml');
      expect(info.calories, 59);
      expect(info.carbs, 6.8);
    });

    test('throws AiException on network failure', () async {
      final api = FoodApiService(
        client: MockClient(
          (_) async => throw http.ClientException('offline'),
        ),
      );
      expect(
        () => api.getProductByBarcode('4001234567890'),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('EditFoodDialog rounding stability', () {
    testWidgets('portion chips scale from base without drift', (tester) async {
      FoodEntry? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => EditFoodDialog(
                    foodEntry: FoodEntry(
                      name: 'Proteinriegel',
                      calories: 201,
                      protein: 21,
                      carbs: 15,
                      fat: 7,
                      date: DateTime(2026, 11, 25),
                    ),
                    onSaveManual: (e) => saved = e,
                    onRecalculate: (_) {},
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('0,50×'));
      await tester.pump();
      await tester.tap(find.text('2×'));
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(saved!.calories, 201);
      expect(saved!.protein, 21);
      expect(saved!.carbs, 15);
      expect(saved!.fat, 7);
    });
  });
}
