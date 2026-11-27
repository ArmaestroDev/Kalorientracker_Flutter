import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'kit/kit.dart';

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
    final appColors = AppColors.of(context);

    final average = averageThisWeek;
    final previous = averagePreviousWeek;
    final rawChange = average != null && previous != null
        ? average - previous
        : null;
    final roundedChange = rawChange == null
        ? null
        : (rawChange * 10).round() / 10;

    var trendColor = colorScheme.onSurfaceVariant;
    if (roundedChange != null &&
        roundedChange != 0 &&
        lowerIsBetter != null) {
      trendColor = (roundedChange < 0) == lowerIsBetter
          ? appColors.success
          : appColors.danger;
    }

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.monitor_weight_outlined,
              size: 20,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gewicht', style: textTheme.titleMedium),
                const SizedBox(height: Space.xxs),
                Text(
                  weightOnSelectedDate != null
                      ? _kg(weightOnSelectedDate!)
                      : 'Noch nicht eingetragen',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (roundedChange != null) ...[
            const SizedBox(width: Space.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${roundedChange > 0 ? '+' : ''}${roundedChange.toStringAsFixed(1).replaceAll('.', ',')} kg',
                  style: textTheme.titleSmall?.copyWith(color: trendColor),
                ),
                Text(
                  'ggü. Vorwoche',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
