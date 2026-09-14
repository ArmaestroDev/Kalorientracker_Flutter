import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../logic/history_data.dart';
import '../../logic/nutrition_stats.dart';
import '../../logic/providers/main_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/goals_summary_card.dart';

final _thousands = NumberFormat.decimalPattern('de_DE');

String _kcal(num value) => '${_thousands.format(value.round())} kcal';

String _axisNumber(double value) {
  if (value >= 1000) {
    final k = value / 1000;
    return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1).replaceAll('.', ',')}k';
  }
  return value.toStringAsFixed(0);
}

double _niceStep(double max) {
  final raw = max / 4;
  for (final step in [100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000]) {
    if (raw <= step) return step.toDouble();
  }
  return 100000;
}

class HistoryScreen extends StatefulWidget {
  final ValueChanged<DateTime> onOpenDay;

  const HistoryScreen({super.key, required this.onOpenDay});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryRange _range = HistoryRange.days14;
  Future<HistoryData>? _future;
  Object? _futureKey;

  Future<HistoryData> _load(MainProvider provider) {
    final key = (
      _range,
      provider.dataVersion,
      provider.goals.calories,
      provider.userProfile.eatBackActivityCalories,
    );
    if (_future == null || key != _futureKey) {
      _futureKey = key;
      _future = provider.loadHistory(_range);
    }
    return _future!;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MainProvider>();
    final future = _load(provider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verlauf')),
      body: FutureBuilder<HistoryData>(
        future: future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              SegmentedButton<HistoryRange>(
                showSelectedIcon: false,
                segments: [
                  for (final r in HistoryRange.values)
                    ButtonSegment(value: r, label: Text(r.label)),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
              const SizedBox(height: 16),
              if (snapshot.hasError)
                Text('Fehler beim Laden: ${snapshot.error}')
              else if (data == null)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (data.goals.calories <= 0)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Trage im Profil Alter, Gewicht und Größe ein, damit Ziele und Wochenbudget berechnet werden können.',
                    ),
                  ),
                )
              else ...[
                _StatTiles(data: data),
                const SizedBox(height: 16),
                _CaloriesChartCard(data: data),
                const SizedBox(height: 16),
                _MacroCard(data: data),
                const SizedBox(height: 16),
                _WeightChartCard(data: data),
                const SizedBox(height: 16),
                _PeriodList(data: data, onOpenDay: widget.onOpenDay),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  final HistoryData data;
  const _StatTiles({required this.data});

  @override
  Widget build(BuildContext context) {
    final week = data.currentWeek;
    final total = data.total;
    final colors = AppColors.of(context);

    final tiles = [
      _StatTile(
        label: 'Diese Woche gegessen',
        value: _kcal(week.consumed),
        detail: 'von ${_kcal(week.budget)}',
      ),
      _StatTile(
        label: week.remaining >= 0 ? 'Übrig diese Woche' : 'Wochenbudget über',
        value: _kcal(week.remaining.abs()),
        valueColor: week.remaining >= 0 ? null : colors.danger,
        detail: week.remaining >= 0
            ? '≈ ${_kcal(week.perRemainingDay)} pro Tag'
            : 'noch ${week.remainingDays} ${week.remainingDays == 1 ? 'Tag' : 'Tage'} in der Woche',
      ),
      _StatTile(
        label: 'Ø pro geloggtem Tag',
        value: total.loggedDays == 0
            ? '–'
            : _kcal(total.avgCaloriesPerLoggedDay),
        detail: '${total.loggedDays} von ${total.calendarDays} Tagen geloggt',
      ),
      _StatTile(
        label: 'Ø Protein pro Tag',
        value: total.loggedDays == 0
            ? '–'
            : '${total.avgProteinPerLoggedDay.round()} g',
        detail: 'Ziel ${data.goals.proteinGrams} g',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color? valueColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.detail,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? legend;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.legend,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (legend != null) ...[const SizedBox(height: 8), legend!],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _LegendKey extends StatelessWidget {
  final Color color;
  final String label;
  final bool isLine;

  const _LegendKey({
    required this.color,
    required this.label,
    this.isLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isLine ? 16 : 10,
          height: isLine ? 2 : 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isLine ? 1 : 5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CaloriesChartCard extends StatelessWidget {
  final HistoryData data;
  const _CaloriesChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final buckets = data.buckets;
    final range = data.range;

    double valueOf(PeriodStats p) => switch (range) {
      HistoryRange.days14 || HistoryRange.weeks12 => p.calories.toDouble(),
      HistoryRange.months12 => p.avgCaloriesPerLoggedDay,
    };
    final goalLine = switch (range) {
      HistoryRange.weeks12 => data.goals.calories * 7.0,
      _ => data.goals.calories.toDouble(),
    };
    final title = switch (range) {
      HistoryRange.days14 => 'Kalorien pro Tag',
      HistoryRange.weeks12 => 'Kalorien pro Woche',
      HistoryRange.months12 => 'Ø Kalorien pro geloggtem Tag',
    };
    final subtitle = switch (range) {
      HistoryRange.weeks12 =>
        'Linie = Wochenbudget ${_kcal(goalLine)} · laufende Woche heller',
      HistoryRange.months12 =>
        'Linie = Tagesziel ${_kcal(goalLine)} · laufender Monat heller',
      HistoryRange.days14 => 'Linie = Tagesziel ${_kcal(goalLine)}',
    };

    final maxValue = [goalLine, ...buckets.map(valueOf)].reduce(math.max);
    final step = _niceStep(maxValue * 1.1);
    final maxY = (maxValue * 1.1 / step).ceil() * step;
    final labelEvery = switch (range) {
      HistoryRange.days14 => 2,
      HistoryRange.weeks12 => 3,
      HistoryRange.months12 => 2,
    };

    String bucketLabel(PeriodStats p) => switch (range) {
      HistoryRange.days14 => DateFormat(
        'E',
        'de_DE',
      ).format(p.start).replaceAll('.', ''),
      HistoryRange.weeks12 => DateFormat('dd.MM.', 'de_DE').format(p.start),
      HistoryRange.months12 => DateFormat(
        'MMM',
        'de_DE',
      ).format(p.start).replaceAll('.', ''),
    };

    String tooltip(PeriodStats p) {
      final head = switch (range) {
        HistoryRange.days14 => DateFormat('EE dd.MM.', 'de_DE').format(p.start),
        HistoryRange.weeks12 =>
          '${DateFormat('dd.MM.', 'de_DE').format(p.start)}–${DateFormat('dd.MM.', 'de_DE').format(p.end)}',
        HistoryRange.months12 => DateFormat('MMMM y', 'de_DE').format(p.start),
      };
      if (p.loggedDays == 0) return '$head\nKeine Einträge';
      return '$head\n${_kcal(valueOf(p))}${range == HistoryRange.days14 ? '' : '\n${p.loggedDays} Tage geloggt'}';
    }

    bool isRunning(PeriodStats p) =>
        range != HistoryRange.days14 && !p.end.isBefore(data.today);

    return _ChartCard(
      title: title,
      subtitle: subtitle,
      child: SizedBox(
        height: 220,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = math.min(
              24.0,
              (constraints.maxWidth - 44) / buckets.length * 0.6,
            );
            return BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barGroups: [
                  for (var i = 0; i < buckets.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: valueOf(buckets[i]),
                          width: barWidth,
                          color: isRunning(buckets[i])
                              ? colorScheme.primary.withValues(alpha: 0.55)
                              : colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: goalLine,
                      color: colorScheme.onSurfaceVariant,
                      strokeWidth: 1.5,
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(bottom: 2),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        labelResolver: (_) => 'Ziel',
                      ),
                    ),
                  ],
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: step,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: step,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          _axisNumber(value),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        final fromEnd = buckets.length - 1 - i;
                        if (i < 0 ||
                            i >= buckets.length ||
                            fromEnd % labelEvery != 0) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                          child: Text(
                            bucketLabel(buckets[i]),
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colorScheme.inverseSurface,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                          tooltip(buckets[group.x]),
                          textTheme.bodySmall!.copyWith(
                            color: colorScheme.onInverseSurface,
                          ),
                        ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final HistoryData data;
  const _MacroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final total = data.total;
    return _ChartCard(
      title: 'Ø Makros pro geloggtem Tag',
      subtitle: total.loggedDays == 0
          ? 'Keine Einträge im Zeitraum'
          : 'Basierend auf ${total.loggedDays} geloggten Tagen',
      child: Row(
        children: [
          Expanded(
            child: MacroProgress(
              name: 'Protein',
              current: total.avgProteinPerLoggedDay.round(),
              goal: data.goals.proteinGrams,
              color: colors.protein,
              isMinimum: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MacroProgress(
              name: 'Kohlenh.',
              current: total.avgCarbsPerLoggedDay.round(),
              goal: data.goals.carbsGrams,
              color: colors.carbs,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MacroProgress(
              name: 'Fett',
              current: total.avgFatPerLoggedDay.round(),
              goal: data.goals.fatGrams,
              color: colors.fat,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightChartCard extends StatelessWidget {
  final HistoryData data;
  const _WeightChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final weights = data.weights;

    if (weights.isEmpty) {
      return const _ChartCard(
        title: 'Gewicht',
        subtitle: 'Noch keine Gewichtseinträge in diesem Zeitraum',
        child: SizedBox.shrink(),
      );
    }

    final start = data.range.startFor(data.today);
    final trend = NutritionStats.weightTrend(weights);
    double x(DateTime d) => d.difference(start).inDays.toDouble();
    final all = weights.map((w) => w.weightKg);
    final minW = all.reduce(math.min);
    final maxW = all.reduce(math.max);
    final pad = math.max(0.5, (maxW - minW) * 0.2);
    final minY = (minW - pad).floorToDouble();
    final maxY = (maxW + pad).ceilToDouble();
    final spanX = x(data.today);
    final change = trend.length > 1
        ? trend.last.average - trend.first.average
        : 0.0;
    final dateFormat = DateFormat('dd.MM.', 'de_DE');
    final muted = colorScheme.onSurfaceVariant;
    final denseDots = weights.length > 30;
    final labelInterval = math.max(1, (spanX / 3).roundToDouble()).toDouble();

    return _ChartCard(
      title: 'Gewicht',
      subtitle: trend.length > 1
          ? 'Ø-Trend im Zeitraum: ${change > 0 ? '+' : ''}${change.toStringAsFixed(1).replaceAll('.', ',')} kg'
          : 'Ein Eintrag im Zeitraum',
      legend: Wrap(
        spacing: 16,
        children: [
          _LegendKey(
            color: colorScheme.primary,
            label: '7-Tage-Schnitt',
            isLine: true,
          ),
          _LegendKey(color: muted, label: 'Messung'),
        ],
      ),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: math.max(spanX, 1),
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: [for (final w in weights) FlSpot(x(w.date), w.weightKg)],
                barWidth: 0,
                color: Colors.transparent,
                dotData: FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: denseDots ? 2 : 4,
                        color: muted.withValues(alpha: denseDots ? 0.6 : 1),
                        strokeWidth: denseDots ? 0 : 2,
                        strokeColor: colorScheme.surfaceContainerLow,
                      ),
                ),
              ),
              LineChartBarData(
                spots: [for (final t in trend) FlSpot(x(t.date), t.average)],
                barWidth: 2,
                isStrokeCapRound: true,
                color: colorScheme.primary,
                dotData: const FlDotData(show: false),
              ),
            ],
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: math.max(
                1,
                ((maxY - minY) / 4).ceilToDouble(),
              ),
              getDrawingHorizontalLine: (_) => FlLine(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: math.max(1, ((maxY - minY) / 4).ceilToDouble()),
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      value.toStringAsFixed(0),
                      style: textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: labelInterval,
                  getTitlesWidget: (value, meta) {
                    if (value % labelInterval != 0) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                      child: Text(
                        dateFormat.format(addDays(start, value.round())),
                        style: textTheme.labelSmall?.copyWith(color: muted),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => colorScheme.inverseSurface,
                fitInsideHorizontally: true,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${s.barIndex == 0 ? 'Messung' : 'Schnitt'} ${dateFormat.format(addDays(start, s.x.round()))}\n${s.y.toStringAsFixed(1).replaceAll('.', ',')} kg',
                      textTheme.bodySmall!.copyWith(
                        color: colorScheme.onInverseSurface,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodList extends StatelessWidget {
  final HistoryData data;
  final ValueChanged<DateTime> onOpenDay;

  const _PeriodList({required this.data, required this.onOpenDay});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final range = data.range;
    final rows = data.buckets.reversed.toList();

    String label(PeriodStats p) => switch (range) {
      HistoryRange.days14 => DateFormat(
        'EEEE, dd.MM.',
        'de_DE',
      ).format(p.start),
      HistoryRange.weeks12 =>
        'Woche ${DateFormat('dd.MM.', 'de_DE').format(p.start)} – ${DateFormat('dd.MM.', 'de_DE').format(p.end)}',
      HistoryRange.months12 => DateFormat('MMMM y', 'de_DE').format(p.start),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              switch (range) {
                HistoryRange.days14 => 'Tage',
                HistoryRange.weeks12 => 'Wochen',
                HistoryRange.months12 => 'Monate',
              },
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final p in rows)
            ListTile(
              onTap: range == HistoryRange.days14
                  ? () => onOpenDay(p.start)
                  : null,
              title: Text(label(p)),
              subtitle: Text(
                p.loggedDays == 0
                    ? 'Keine Einträge'
                    : range == HistoryRange.days14
                    ? 'P ${p.protein} g · K ${p.carbs} g · F ${p.fat} g'
                    : '${p.loggedDays} Tage geloggt · Ø ${_kcal(p.avgCaloriesPerLoggedDay)}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: p.loggedDays == 0
                  ? (range == HistoryRange.days14
                        ? const Icon(Icons.chevron_right)
                        : null)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _kcal(p.calories),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          p.loggedBalance <= 0
                              ? '${_thousands.format(-p.loggedBalance)} unter Ziel'
                              : '${_thousands.format(p.loggedBalance)} über Ziel',
                          style: textTheme.labelSmall?.copyWith(
                            color: p.loggedBalance <= 0
                                ? colors.success
                                : colors.danger,
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
