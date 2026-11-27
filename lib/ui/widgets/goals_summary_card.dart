import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/calorie_goals.dart';
import '../../logic/nutrition_stats.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'kit/kit.dart';

final _thousands = NumberFormat.decimalPattern('de_DE');

class GoalsSummaryCard extends StatelessWidget {
  final int eatenCalories;
  final int calorieBudget;
  final int burnedCalories;
  final bool activityAddedToBudget;
  final int totalProtein;
  final int totalCarbs;
  final int totalFat;
  final CalorieGoals goals;
  final WeekStatus week;
  final VoidCallback? onOpenHistory;

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
    required this.week,
    this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final appColors = AppColors.of(context);

    if (goals.calories <= 0) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.person_outline, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: Space.md),
            const Expanded(
              child: Text(
                'Trage im Profil Alter, Gewicht und Größe ein, um deine Ziele zu berechnen.',
              ),
            ),
          ],
        ),
      );
    }

    final remaining = calorieBudget - eatenCalories;
    final isOver = remaining < 0;
    final progressColor = isOver ? appColors.danger : colorScheme.primary;
    final progress = calorieBudget > 0
        ? (eatenCalories / calorieBudget).clamp(0.0, 1.0)
        : 0.0;
    final weekRemaining = week.remaining;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        color: progressColor,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isOver
                              ? '+${_thousands.format(remaining.abs())}'
                              : _thousands.format(remaining),
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isOver ? appColors.danger : colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          isOver ? 'zu viel' : 'übrig',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryLine(
                      label: 'Gegessen',
                      value: '${_thousands.format(eatenCalories)} kcal',
                    ),
                    const SizedBox(height: Space.sm),
                    _SummaryLine(
                      label: 'Budget',
                      value: '${_thousands.format(calorieBudget)} kcal',
                    ),
                    const SizedBox(height: Space.sm),
                    _SummaryLine(
                      label: 'Verbrannt',
                      value: activityAddedToBudget
                          ? '${_thousands.format(burnedCalories)} kcal'
                          : '${_thousands.format(burnedCalories)} kcal (im Budget)',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MacroProgress(
                  name: 'Protein',
                  current: totalProtein,
                  goal: goals.proteinGrams,
                  color: appColors.protein,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: MacroProgress(
                  name: 'Kohlenhydrate',
                  current: totalCarbs,
                  goal: goals.carbsGrams,
                  color: appColors.carbs,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: MacroProgress(
                  name: 'Fett',
                  current: totalFat,
                  goal: goals.fatGrams,
                  color: appColors.fat,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  weekRemaining >= 0
                      ? 'Woche: ${_thousands.format(weekRemaining)} kcal übrig'
                      : 'Woche: ${_thousands.format(-weekRemaining)} kcal zu viel',
                  style: textTheme.bodySmall?.copyWith(
                    color: weekRemaining >= 0
                        ? colorScheme.onSurfaceVariant
                        : appColors.danger,
                  ),
                ),
              ),
              if (onOpenHistory != null)
                TextButton(
                  onPressed: onOpenHistory,
                  child: const Text('Verlauf'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class MacroProgress extends StatelessWidget {
  final String name;
  final int current;
  final int goal;
  final Color color;

  const MacroProgress({
    super.key,
    required this.name,
    required this.current,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Space.xs),
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          borderRadius: BorderRadius.circular(Corner.full),
          color: color,
        ),
        const SizedBox(height: Space.xs),
        Text(
          '$current / $goal g',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
