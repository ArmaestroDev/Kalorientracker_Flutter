import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/calorie_goals.dart';
import '../../logic/nutrition_stats.dart';
import '../theme/app_theme.dart';

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
    final progressColor = isOver ? appColors.danger : colorScheme.primary;

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
                      isOver ? 'Über dem Tagesziel' : 'Heute noch übrig',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${_thousands.format(remaining.abs())} kcal',
                      style: textTheme.headlineMedium?.copyWith(
                        color: isOver
                            ? appColors.danger
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_thousands.format(eatenCalories)} / ${_thousands.format(calorieBudget)} kcal',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: calorieBudget > 0
                    ? (eatenCalories / calorieBudget).clamp(0.0, 1.0)
                    : 0,
                minHeight: 10,
                color: progressColor,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            if (burnedCalories > 0) ...[
              const SizedBox(height: 6),
              Text(
                activityAddedToBudget
                    ? 'inkl. +$burnedCalories kcal aus Aktivitäten'
                    : '$burnedCalories kcal Aktivität (bereits im Aktivitätslevel enthalten)',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MacroProgress(
                    name: 'Protein',
                    current: totalProtein,
                    goal: goals.proteinGrams,
                    color: appColors.protein,
                    isMinimum: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MacroProgress(
                    name: 'Kohlenh.',
                    current: totalCarbs,
                    goal: goals.carbsGrams,
                    color: appColors.carbs,
                  ),
                ),
                const SizedBox(width: 12),
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
            const Divider(height: 28),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onOpenHistory,
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_view_week,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diese Woche ${_thousands.format(week.consumed)} / ${_thousands.format(week.budget)} kcal',
                          style: textTheme.bodyMedium,
                        ),
                        Text(
                          week.remaining >= 0
                              ? 'Noch ${_thousands.format(week.remaining)} kcal · ≈ ${_thousands.format(week.perRemainingDay)} pro Tag'
                              : 'Wochenbudget um ${_thousands.format(-week.remaining)} kcal überschritten',
                          style: textTheme.bodySmall?.copyWith(
                            color: week.remaining >= 0
                                ? colorScheme.onSurfaceVariant
                                : appColors.danger,
                          ),
                        ),
                        if (week.unloggedPastDays > 0)
                          Text(
                            '${week.unloggedPastDays} ${week.unloggedPastDays == 1 ? 'Tag' : 'Tage'} ohne Einträge',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onOpenHistory != null)
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MacroProgress extends StatelessWidget {
  final String name;
  final int current;
  final int goal;
  final Color color;
  final bool isMinimum;

  const MacroProgress({
    super.key,
    required this.name,
    required this.current,
    required this.goal,
    required this.color,
    this.isMinimum = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final reached = isMinimum && goal > 0 && current >= goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                style: textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (reached) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle, size: 14, color: colorScheme.onSurface),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$current / $goal g',
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
