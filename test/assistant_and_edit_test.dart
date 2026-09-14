import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kalorientracker_flutter/data/models/activity_entry.dart';
import 'package:kalorientracker_flutter/data/models/enums.dart';
import 'package:kalorientracker_flutter/data/models/food_entry.dart';
import 'package:kalorientracker_flutter/data/models/user_profile.dart';
import 'package:kalorientracker_flutter/data/models/weight_entry.dart';
import 'package:kalorientracker_flutter/logic/assistant_context_builder.dart';
import 'package:kalorientracker_flutter/logic/goals_calculator.dart';
import 'package:kalorientracker_flutter/logic/number_format.dart';
import 'package:kalorientracker_flutter/ui/widgets/dialogs/edit_food_dialog.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  group('number parsing', () {
    test('accepts comma and dot', () {
      expect(parseLocalizedNumber('82,5'), 82.5);
      expect(parseLocalizedNumber(' 82.5 '), 82.5);
      expect(parseLocalizedNumber(''), isNull);
      expect(parseLocalizedNumber('abc'), isNull);
      expect(formatLocalizedNumber(82.0), '82');
      expect(formatLocalizedNumber(82.45), '82,5');
    });
  });

  group('AssistantContextBuilder', () {
    const profile = UserProfile(
      claudeApiKey: 'sk-secret',
      age: 20,
      weightKg: 82,
      heightCm: 177,
      bodyFatPercent: 18,
      activityLevel: ActivityLevel.moderatelyActive,
      goal: FitnessGoal.loseWeight,
      aboutMe: 'BJJ 4x pro Woche, esse in der Mensa',
    );
    final goals = GoalsCalculator.calculateGoals(profile);
    final today = DateTime(2026, 9, 14);

    String build() => AssistantContextBuilder.build(
      profile: profile,
      goals: goals,
      now: DateTime(2026, 9, 14, 21, 30),
      selectedDate: today,
      dayFoods: [
        FoodEntry(
          name: 'Skyr natur',
          calories: 158,
          protein: 28,
          carbs: 10,
          fat: 1,
          date: today,
          amount: 250,
          unit: 'g',
        ),
      ],
      dayActivities: [
        ActivityEntry(name: '60 Min BJJ', caloriesBurned: 600, date: today),
      ],
      dayBudget: goals.calories,
      history: DaySummary.fromEntries([
        FoodEntry(
          name: 'Döner',
          calories: 750,
          protein: 35,
          carbs: 70,
          fat: 30,
          date: DateTime(2026, 9, 12),
        ),
      ], []),
      weights: [WeightEntry(date: DateTime(2026, 9, 13), weightKg: 81.6)],
    );

    test('contains personal data, remaining budget and history', () {
      final prompt = build();
      expect(prompt, contains('BJJ 4x pro Woche, esse in der Mensa'));
      expect(prompt, contains('Skyr natur (250 g): 158 kcal'));
      expect(prompt, contains('Noch übrig: ${goals.calories - 158} kcal'));
      expect(
        prompt,
        contains('Protein noch offen: ${goals.proteinGrams - 28} g'),
      );
      expect(prompt, contains('750 kcal'));
      expect(prompt, contains('81,6 kg'));
      expect(prompt, contains('21:30'));
    });

    test('never leaks API keys', () {
      expect(build(), isNot(contains('sk-secret')));
    });
  });

  group('EditFoodDialog', () {
    Future<void> openDialog(
      WidgetTester tester,
      FoodEntry entry, {
      required ValueChanged<FoodEntry> onSave,
      ValueChanged<FoodEntry>? onRecalculate,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => EditFoodDialog(
                    foodEntry: entry,
                    onSaveManual: onSave,
                    onRecalculate: onRecalculate ?? (_) {},
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
    }

    Finder field(String label) => find.widgetWithText(TextField, label);

    testWidgets('changing the amount rescales calories and macros', (
      tester,
    ) async {
      FoodEntry? saved;
      await openDialog(
        tester,
        FoodEntry(
          name: 'Skyr natur',
          calories: 160,
          protein: 28,
          carbs: 10,
          fat: 2,
          date: DateTime(2026, 9, 14),
          amount: 250,
          unit: 'g',
        ),
        onSave: (e) => saved = e,
      );

      await tester.enterText(field('Menge'), '500');
      await tester.pump();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.amount, 500);
      expect(saved!.calories, 320);
      expect(saved!.protein, 56);
      expect(saved!.fat, 4);
    });

    testWidgets('accepts decimal commas and rejects empty calories', (
      tester,
    ) async {
      FoodEntry? saved;
      await openDialog(
        tester,
        FoodEntry(
          name: 'Apfel',
          calories: 80,
          protein: 0,
          carbs: 19,
          fat: 0,
          date: DateTime(2026, 9, 14),
        ),
        onSave: (e) => saved = e,
      );

      await tester.enterText(field('Kalorien'), '');
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      expect(saved, isNull);
      expect(find.text('Pflichtfeld'), findsOneWidget);

      await tester.enterText(field('Kalorien'), '95,6');
      await tester.enterText(field('Protein'), '0,4');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(saved!.calories, 96);
      expect(saved!.protein, 0);
    });

    testWidgets('AI re-estimate uses the edited name and amount', (
      tester,
    ) async {
      FoodEntry? recalculated;
      await openDialog(
        tester,
        FoodEntry(
          name: 'Skyr',
          calories: 160,
          protein: 28,
          carbs: 10,
          fat: 2,
          date: DateTime(2026, 9, 14),
          amount: 250,
          unit: 'g',
        ),
        onSave: (_) {},
        onRecalculate: (e) => recalculated = e,
      );

      await tester.enterText(field('Name'), 'Skyr Vanille');
      await tester.enterText(field('Menge'), '150');
      await tester.tap(find.text('Mit KI neu schätzen'));
      await tester.pumpAndSettle();

      expect(recalculated!.name, 'Skyr Vanille');
      expect(recalculated!.amount, 150);
    });
  });
}
