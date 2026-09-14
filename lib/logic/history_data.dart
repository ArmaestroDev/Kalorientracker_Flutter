import '../data/models/activity_entry.dart';
import '../data/models/calorie_goals.dart';
import '../data/models/food_entry.dart';
import '../data/models/weight_entry.dart';
import 'nutrition_stats.dart';

enum HistoryRange {
  days14('14 Tage'),
  weeks12('12 Wochen'),
  months12('12 Monate');

  final String label;
  const HistoryRange(this.label);

  DateTime startFor(DateTime today) => switch (this) {
    HistoryRange.days14 => addDays(today, -13),
    HistoryRange.weeks12 => addDays(startOfWeek(today), -7 * 11),
    HistoryRange.months12 => DateTime(today.year, today.month - 11),
  };
}

/// Everything the history screen shows for one range
class HistoryData {
  final HistoryRange range;
  final DateTime today;
  final CalorieGoals goals;
  final List<DayStats> days;
  final List<PeriodStats> buckets;
  final PeriodStats total;
  final WeekStatus currentWeek;
  final List<WeightEntry> weights;

  const HistoryData({
    required this.range,
    required this.today,
    required this.goals,
    required this.days,
    required this.buckets,
    required this.total,
    required this.currentWeek,
    required this.weights,
  });

  factory HistoryData.build({
    required HistoryRange range,
    required DateTime today,
    required CalorieGoals goals,
    required bool eatBackActivity,
    required List<FoodEntry> foods,
    required List<ActivityEntry> activities,
    required List<WeightEntry> weights,
  }) {
    final start = range.startFor(today);
    final weekStart = startOfWeek(today);
    final loadStart = start.isBefore(weekStart) ? start : weekStart;
    final allDays = NutritionStats.daily(foods, activities, loadStart, today);
    final days = allDays.where((d) => !d.date.isBefore(start)).toList();
    final goal = goals.calories;

    final buckets = switch (range) {
      HistoryRange.days14 => [
        for (final d in days)
          NutritionStats.period(
            days,
            d.date,
            d.date,
            dailyGoal: goal,
            eatBackActivity: eatBackActivity,
          ),
      ],
      HistoryRange.weeks12 => NutritionStats.weekly(
        days,
        dailyGoal: goal,
        eatBackActivity: eatBackActivity,
      ),
      HistoryRange.months12 => NutritionStats.monthly(
        days,
        dailyGoal: goal,
        eatBackActivity: eatBackActivity,
      ),
    };

    return HistoryData(
      range: range,
      today: today,
      goals: goals,
      days: days,
      buckets: buckets,
      total: NutritionStats.period(
        days,
        start,
        today,
        dailyGoal: goal,
        eatBackActivity: eatBackActivity,
      ),
      currentWeek: NutritionStats.weekStatus(
        allDays,
        today,
        dailyGoal: goal,
        eatBackActivity: eatBackActivity,
      ),
      weights: weights.where((w) => !w.date.isBefore(start)).toList(),
    );
  }
}
