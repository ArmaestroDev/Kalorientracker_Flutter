import '../data/models/activity_entry.dart';
import '../data/models/food_entry.dart';
import '../data/models/weight_entry.dart';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

DateTime startOfWeek(DateTime d) => addDays(d, -(d.weekday - DateTime.monday));

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Totals for one calendar day
class DayStats {
  final DateTime date;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int burned;
  final int entries;

  const DayStats({
    required this.date,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.burned = 0,
    this.entries = 0,
  });

  bool get isLogged => entries > 0;
}

/// Totals for a week, month or custom range
class PeriodStats {
  final DateTime start;
  final DateTime end;
  final List<DayStats> days;
  final int dailyGoal;
  final bool eatBackActivity;

  const PeriodStats({
    required this.start,
    required this.end,
    required this.days,
    required this.dailyGoal,
    required this.eatBackActivity,
  });

  Iterable<DayStats> get _logged => days.where((d) => d.isLogged);

  int get calendarDays => days.length;
  int get loggedDays => _logged.length;
  int get calories => days.fold(0, (s, d) => s + d.calories);
  int get protein => days.fold(0, (s, d) => s + d.protein);
  int get carbs => days.fold(0, (s, d) => s + d.carbs);
  int get fat => days.fold(0, (s, d) => s + d.fat);
  int get burned => days.fold(0, (s, d) => s + d.burned);

  int _budgetFor(Iterable<DayStats> ds) =>
      ds.fold(0, (s, d) => s + dailyGoal + (eatBackActivity ? d.burned : 0));

  /// Budget for every calendar day of the period
  int get budget => _budgetFor(days);

  /// Eaten minus budget, counting only days with entries (negative = deficit)
  int get loggedBalance => calories - _budgetFor(_logged);

  double get avgCaloriesPerLoggedDay =>
      loggedDays == 0 ? 0 : calories / loggedDays;
  double get avgProteinPerLoggedDay =>
      loggedDays == 0 ? 0 : protein / loggedDays;
  double get avgCarbsPerLoggedDay => loggedDays == 0 ? 0 : carbs / loggedDays;
  double get avgFatPerLoggedDay => loggedDays == 0 ? 0 : fat / loggedDays;
}

/// Where the user stands in the week containing [reference]
class WeekStatus {
  final PeriodStats week;
  final DateTime reference;

  const WeekStatus(this.week, this.reference);

  int get consumed => week.days
      .where((d) => !d.date.isAfter(reference))
      .fold(0, (s, d) => s + d.calories);

  int get budget => week.budget;
  int get remaining => budget - consumed;

  /// Days left in the week including the reference day
  int get remainingDays => week.end.difference(reference).inDays + 1;

  /// Remaining budget spread over the remaining days, including today
  int get perRemainingDay =>
      remainingDays <= 0 ? 0 : (remaining / remainingDays).round();

  /// Past days of this week (before the reference day) without any entry
  int get unloggedPastDays =>
      week.days.where((d) => d.date.isBefore(reference) && !d.isLogged).length;
}

class NutritionStats {
  /// One entry per calendar day from [start] to [end] (inclusive), empty days included
  static List<DayStats> daily(
    List<FoodEntry> foods,
    List<ActivityEntry> activities,
    DateTime start,
    DateTime end,
  ) {
    final foodByDay = <String, List<FoodEntry>>{};
    for (final f in foods) {
      foodByDay.putIfAbsent(dayKey(f.date), () => []).add(f);
    }
    final burnedByDay = <String, int>{};
    for (final a in activities) {
      final key = dayKey(a.date);
      burnedByDay[key] = (burnedByDay[key] ?? 0) + a.caloriesBurned;
    }

    final result = <DayStats>[];
    for (var d = dayOnly(start); !d.isAfter(dayOnly(end)); d = addDays(d, 1)) {
      final key = dayKey(d);
      final dayFoods = foodByDay[key] ?? const [];
      result.add(
        DayStats(
          date: d,
          calories: dayFoods.fold(0, (s, f) => s + f.calories),
          protein: dayFoods.fold(0, (s, f) => s + f.protein),
          carbs: dayFoods.fold(0, (s, f) => s + f.carbs),
          fat: dayFoods.fold(0, (s, f) => s + f.fat),
          burned: burnedByDay[key] ?? 0,
          entries: dayFoods.length,
        ),
      );
    }
    return result;
  }

  static PeriodStats period(
    List<DayStats> days,
    DateTime start,
    DateTime end, {
    required int dailyGoal,
    required bool eatBackActivity,
  }) {
    final s = dayOnly(start);
    final e = dayOnly(end);
    return PeriodStats(
      start: s,
      end: e,
      days: days
          .where((d) => !d.date.isBefore(s) && !d.date.isAfter(e))
          .toList(),
      dailyGoal: dailyGoal,
      eatBackActivity: eatBackActivity,
    );
  }

  /// Monday-based weeks overlapping [days], oldest first
  static List<PeriodStats> weekly(
    List<DayStats> days, {
    required int dailyGoal,
    required bool eatBackActivity,
  }) {
    if (days.isEmpty) return [];
    final result = <PeriodStats>[];
    for (
      var weekStart = startOfWeek(days.first.date);
      !weekStart.isAfter(days.last.date);
      weekStart = addDays(weekStart, 7)
    ) {
      result.add(
        period(
          days,
          weekStart,
          addDays(weekStart, 6),
          dailyGoal: dailyGoal,
          eatBackActivity: eatBackActivity,
        ),
      );
    }
    return result;
  }

  /// Calendar months overlapping [days], oldest first
  static List<PeriodStats> monthly(
    List<DayStats> days, {
    required int dailyGoal,
    required bool eatBackActivity,
  }) {
    if (days.isEmpty) return [];
    final result = <PeriodStats>[];
    var month = DateTime(days.first.date.year, days.first.date.month);
    while (!month.isAfter(days.last.date)) {
      final next = DateTime(month.year, month.month + 1);
      result.add(
        period(
          days,
          month,
          addDays(next, -1),
          dailyGoal: dailyGoal,
          eatBackActivity: eatBackActivity,
        ),
      );
      month = next;
    }
    return result;
  }

  static WeekStatus weekStatus(
    List<DayStats> days,
    DateTime reference, {
    required int dailyGoal,
    required bool eatBackActivity,
  }) {
    final start = startOfWeek(reference);
    final weekDays = daily(const [], const [], start, addDays(start, 6)).map((
      empty,
    ) {
      return days.firstWhere(
        (d) => dayKey(d.date) == dayKey(empty.date),
        orElse: () => empty,
      );
    }).toList();
    return WeekStatus(
      PeriodStats(
        start: start,
        end: addDays(start, 6),
        days: weekDays,
        dailyGoal: dailyGoal,
        eatBackActivity: eatBackActivity,
      ),
      dayOnly(reference),
    );
  }

  /// Trailing 7-day average weight for each measurement date
  static List<({DateTime date, double average})> weightTrend(
    List<WeightEntry> weights,
  ) {
    final sorted = [...weights]..sort((a, b) => a.date.compareTo(b.date));
    return [
      for (final w in sorted)
        (
          date: w.date,
          average: () {
            final window = sorted.where(
              (o) =>
                  !o.date.isAfter(w.date) &&
                  o.date.isAfter(addDays(w.date, -7)),
            );
            return window.fold(0.0, (s, o) => s + o.weightKg) / window.length;
          }(),
        ),
    ];
  }
}
