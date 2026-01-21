import 'package:flutter/material.dart';
import '../../data/models/calorie_goals.dart';

class GoalsSummaryCard extends StatelessWidget {
  final int netCalories;
  final int totalProtein;
  final int totalCarbs;
  final int totalFat;
  final CalorieGoals goals;

  const GoalsSummaryCard({
    super.key,
    required this.netCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calories header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tagesübersicht',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$netCalories / ${goals.calories} kcal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Calories progress
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goals.calories > 0
                    ? (netCalories / goals.calories).clamp(0.0, 1.0)
                    : 0,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),

            // Macros
            Row(
              children: [
                Expanded(
                  child: _MacroProgress(
                    name: 'Protein',
                    current: totalProtein,
                    goal: goals.proteinGrams,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MacroProgress(
                    name: 'Kohlenh.',
                    current: totalCarbs,
                    goal: goals.carbsGrams,
                    color: Colors.amber.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MacroProgress(
                    name: 'Fett',
                    current: totalFat,
                    goal: goals.fatGrams,
                    color: Colors.blue.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroProgress extends StatelessWidget {
  final String name;
  final int current;
  final int goal;
  final Color color;

  const _MacroProgress({
    required this.name,
    required this.current,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$current / ${goal}g',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
