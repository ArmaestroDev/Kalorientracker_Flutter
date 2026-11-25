import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WeightCard extends StatelessWidget {
  final double? weightOnSelectedDate;
  final double? averageThisWeek;
  final double? averagePreviousWeek;

  /// true = losing is good, false = gaining is good, null = neutral
  final bool? lowerIsBetter;
  final VoidCallback onTap;

  const WeightCard({
    super.key,
    required this.weightOnSelectedDate,
    required this.averageThisWeek,
    required this.averagePreviousWeek,
    required this.lowerIsBetter,
    required this.onTap,
  });

  String _kg(double value) =>
      '${value.toStringAsFixed(1).replaceAll('.', ',')} kg';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final average = averageThisWeek;
    final previous = averagePreviousWeek;
    final rawChange = average != null && previous != null
        ? average - previous
        : null;
    final roundedChange = rawChange == null
        ? null
        : (rawChange * 10).round() / 10;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.monitor_weight_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weightOnSelectedDate != null
                          ? _kg(weightOnSelectedDate!)
                          : 'Gewicht eintragen',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (average != null)
                      Text(
                        'Ø 7 Tage: ${_kg(average)}',
                        style: textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (roundedChange != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${roundedChange > 0 ? '+' : ''}${roundedChange.toStringAsFixed(1).replaceAll('.', ',')} kg',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: lowerIsBetter == null || roundedChange == 0
                            ? colorScheme.onSurface
                            : (roundedChange < 0) == lowerIsBetter
                            ? AppColors.of(context).success
                            : AppColors.of(context).danger,
                      ),
                    ),
                    Text('ggü. Vorwoche', style: textTheme.labelSmall),
                  ],
                )
              else
                Icon(
                  weightOnSelectedDate != null ? Icons.edit_outlined : Icons.add,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
