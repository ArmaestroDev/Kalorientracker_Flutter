import 'package:flutter/material.dart';

class WeightCard extends StatelessWidget {
  final double? weightOnSelectedDate;
  final double? averageThisWeek;
  final double? averagePreviousWeek;
  final bool lowerIsBetter;
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
    final change = average != null && previous != null
        ? average - previous
        : null;

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
              if (change != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${change > 0 ? '+' : ''}${change.toStringAsFixed(1).replaceAll('.', ',')} kg',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: (change <= 0) == lowerIsBetter
                            ? Colors.green.shade600
                            : colorScheme.error,
                      ),
                    ),
                    Text('ggü. Vorwoche', style: textTheme.labelSmall),
                  ],
                )
              else
                Icon(Icons.add, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
