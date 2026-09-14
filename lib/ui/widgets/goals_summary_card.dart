import 'package:flutter/material.dart';
import '../../data/models/calorie_goals.dart';

class GoalsSummaryCard extends StatelessWidget {
  final int eatenCalories;
  final int calorieBudget;
  final int burnedCalories;
  final bool activityAddedToBudget;
  final int totalProtein;
  final int totalCarbs;
  final int totalFat;
  final CalorieGoals goals;
  final int weekCalorieBalance;
  final int weekLoggedDays;

  const GoalsSummaryCard({
    super.key,
    required this.eatenCalories,
    required this.calorieBudget,
    required this.burnedCalories,
    required this.activityAddedToBudget,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.goals,
    required this.weekCalorieBalance,
    required this.weekLoggedDays,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (goals.calories <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.person_outline, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Trage im Profil Alter, Gewicht und Größe ein, um deine Ziele zu berechnen.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final remaining = calorieBudget - eatenCalories;
    final isOver = remaining < 0;
    final progressColor = isOver ? colorScheme.error : colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOver ? 'Über dem Ziel' : 'Noch übrig',
                      style: textTheme.bodySmall,
                    ),
                    Text(
                      '${remaining.abs()} kcal',
                      style: textTheme.headlineSmall?.copyWith(
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$eatenCalories / $calorieBudget kcal',
                  style: textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: calorieBudget > 0
                    ? (eatenCalories / calorieBudget).clamp(0.0, 1.0)
                    : 0,
                minHeight: 8,
                color: progressColor,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            if (burnedCalories > 0) ...[
              const SizedBox(height: 4),
              Text(
                activityAddedToBudget
                    ? 'inkl. +$burnedCalories kcal aus Aktivitäten'
                    : '$burnedCalories kcal Aktivität (bereits im Aktivitätslevel enthalten)',
                style: textTheme.labelSmall,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MacroProgress(
                    name: 'Protein',
                    current: totalProtein,
                    goal: goals.proteinGrams,
                    color: Colors.red.shade400,
                    isMinimum: true,
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
            if (weekLoggedDays > 0) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.calendar_view_week,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Woche ($weekLoggedDays ${weekLoggedDays == 1 ? 'Tag' : 'Tage'})',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    weekCalorieBalance <= 0
                        ? '${weekCalorieBalance.abs()} kcal unter Ziel'
                        : '$weekCalorieBalance kcal über Ziel',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: weekCalorieBalance <= 0
                          ? Colors.green.shade600
                          : colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
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
  final bool isMinimum;

  const _MacroProgress({
    required this.name,
    required this.current,
    required this.goal,
    required this.color,
    this.isMinimum = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final reached = isMinimum && goal > 0 && current >= goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(name, style: Theme.of(context).textTheme.bodySmall),
            if (reached) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle, size: 12, color: color),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isMinimum && goal > current
              ? '$current / ${goal}g · noch ${goal - current}g'
              : '$current / ${goal}g',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
