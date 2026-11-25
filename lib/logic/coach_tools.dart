import 'package:intl/intl.dart';
import '../data/models/activity_entry.dart';
import '../data/models/calorie_goals.dart';
import '../data/models/food_entry.dart';
import '../data/models/user_plan.dart';
import '../data/models/user_profile.dart';
import '../data/models/weight_entry.dart';
import '../data/services/generative_service.dart';
import 'nutrition_stats.dart';

typedef RangeLoader<T> = Future<List<T>> Function(DateTime start, DateTime end);

/// Data and action tools the coach can call on demand
class CoachTools {
  final RangeLoader<FoodEntry> loadFoods;
  final RangeLoader<ActivityEntry> loadActivities;
  final RangeLoader<WeightEntry> loadWeights;
  final Future<List<UserPlan>> Function()? loadPlans;
  final Future<void> Function(FoodEntry entry)? onLogFood;
  final Future<void> Function(ActivityEntry entry)? onLogActivity;
  final Future<void> Function(WeightEntry entry)? onLogWeight;
  final UserProfile profile;
  final CalorieGoals goals;
  final DateTime today;

  /// Called before a tool runs, with a short German description for the UI
  final void Function(String status)? onStatus;

  CoachTools({
    required this.loadFoods,
    required this.loadActivities,
    required this.loadWeights,
    this.loadPlans,
    this.onLogFood,
    this.onLogActivity,
    this.onLogWeight,
    required this.profile,
    required this.goals,
    required this.today,
    this.onStatus,
  });

  static const maxDayRange = 62;
  static const maxRange = 730;
  static const maxSearchResults = 40;

  static final _weekday = DateFormat('EEEE', 'de_DE');
  static final _short = DateFormat('dd.MM.', 'de_DE');

  static const _date = {
    'type': 'string',
    'description': 'Datum im Format YYYY-MM-DD',
  };

  static final List<AiTool> definitions = [
    const AiTool(
      name: 'get_day_log',
      description:
          'Alle Mahlzeiten (mit Menge, kcal, Protein, Kohlenhydraten, Fett), Aktivitäten, Gewicht und Tagesbilanz eines einzelnen Tages.',
      parameters: {
        'type': 'object',
        'properties': {'date': _date},
        'required': ['date'],
      },
    ),
    const AiTool(
      name: 'get_period_summary',
      description:
          'Summen und Durchschnitte für einen Zeitraum, gruppiert nach Tag, Woche (Mo–So) oder Monat: kcal, Makros, Aktivitätsverbrauch, geloggte Tage, Budget und Bilanz. Für Rückblicke und Trends. Tagesgruppierung höchstens 62 Tage.',
      parameters: {
        'type': 'object',
        'properties': {
          'start_date': _date,
          'end_date': _date,
          'group_by': {
            'type': 'string',
            'enum': ['day', 'week', 'month'],
            'description': 'Gruppierung der Ergebnisse',
          },
        },
        'required': ['start_date', 'end_date', 'group_by'],
      },
    ),
    const AiTool(
      name: 'get_weight_history',
      description:
          'Gewichtseinträge eines Zeitraums mit gleitendem 7-Tage-Durchschnitt.',
      parameters: {
        'type': 'object',
        'properties': {'start_date': _date, 'end_date': _date},
        'required': ['start_date', 'end_date'],
      },
    ),
    const AiTool(
      name: 'search_meals',
      description:
          'Sucht Mahlzeiten nach Name (z. B. "Döner", "Skyr") in einem Zeitraum. Ohne Zeitraum: letzte 365 Tage. Liefert Datum, Menge und Nährwerte der Treffer.',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Suchbegriff'},
          'start_date': _date,
          'end_date': _date,
        },
        'required': ['query'],
      },
    ),
    const AiTool(
      name: 'get_top_foods',
      description:
          'Lebensmittel, die in einem Zeitraum am häufigsten gegessen wurden bzw. die meisten Kalorien geliefert haben.',
      parameters: {
        'type': 'object',
        'properties': {
          'start_date': _date,
          'end_date': _date,
          'limit': {
            'type': 'integer',
            'description': 'Anzahl der Ergebnisse, Standard 10',
          },
        },
        'required': ['start_date', 'end_date'],
      },
    ),
    const AiTool(
      name: 'get_user_plan',
      description:
          'Lädt den vollständigen Text eines gespeicherten Ernährungs- oder Trainingsplans anhand der plan_id (oder listet alle aktiven Pläne auf, falls plan_id fehlt).',
      parameters: {
        'type': 'object',
        'properties': {
          'plan_id': {'type': 'string', 'description': 'ID des Plans'},
        },
      },
    ),
    const AiTool(
      name: 'log_food_entry',
      description:
          'Trägt eine Mahlzeit oder ein Lebensmittel ins Tagebuch ein. Nur aufrufen, wenn der Nutzer ausdrücklich darum bittet.',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Name der Mahlzeit'},
          'calories': {'type': 'integer', 'description': 'Kalorien in kcal'},
          'protein': {'type': 'integer', 'description': 'Protein in Gramm'},
          'carbs': {'type': 'integer', 'description': 'Kohlenhydrate in Gramm'},
          'fat': {'type': 'integer', 'description': 'Fett in Gramm'},
          'amount': {'type': 'number', 'description': 'Menge, optional'},
          'unit': {
            'type': 'string',
            'enum': ['g', 'ml', 'Stk', 'Portion'],
            'description': 'Einheit, optional',
          },
          'date': _date,
        },
        'required': ['name', 'calories', 'protein', 'carbs', 'fat'],
      },
    ),
    const AiTool(
      name: 'log_activity_entry',
      description:
          'Trägt eine sportliche Aktivität ins Tagebuch ein. Nur aufrufen, wenn der Nutzer ausdrücklich darum bittet.',
      parameters: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Name inkl. Dauer'},
          'calories_burned': {
            'type': 'integer',
            'description': 'Zusätzlich verbrannte Kalorien (netto)',
          },
          'date': _date,
        },
        'required': ['name', 'calories_burned'],
      },
    ),
    const AiTool(
      name: 'log_weight_entry',
      description:
          'Speichert einen Gewichtseintrag in kg. Nur aufrufen, wenn der Nutzer ausdrücklich darum bittet.',
      parameters: {
        'type': 'object',
        'properties': {
          'weight_kg': {'type': 'number', 'description': 'Gewicht in kg'},
          'date': _date,
        },
        'required': ['weight_kg'],
      },
    ),
  ];

  Future<Map<String, dynamic>> execute(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'get_day_log':
        return _dayLog(args);
      case 'get_period_summary':
        return _periodSummary(args);
      case 'get_weight_history':
        return _weightHistory(args);
      case 'search_meals':
        return _searchMeals(args);
      case 'get_top_foods':
        return _topFoods(args);
      case 'get_user_plan':
        return _getUserPlan(args);
      case 'log_food_entry':
        return _logFood(args);
      case 'log_activity_entry':
        return _logActivity(args);
      case 'log_weight_entry':
        return _logWeight(args);
      default:
        return {'error': 'Unbekanntes Tool: $name'};
    }
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
    if (ymd != null) {
      final y = int.parse(ymd.group(1)!);
      final m = int.parse(ymd.group(2)!);
      final d = int.parse(ymd.group(3)!);
      final candidate = DateTime(y, m, d);
      if (candidate.year == y && candidate.month == m && candidate.day == d) {
        return candidate;
      }
      return null;
    }
    final parsed = DateTime.tryParse(trimmed);
    return parsed == null ? null : dayOnly(parsed);
  }

  ({({DateTime start, DateTime end})? range, String? error}) _parseRange(
    Map<String, dynamic> args, {
    int defaultDays = 30,
  }) {
    final rawEnd = args['end_date'];
    final rawStart = args['start_date'];
    DateTime end = today;
    if (rawEnd != null) {
      final parsed = _parseDate(rawEnd);
      if (parsed == null) {
        return (range: null, error: 'end_date ist ungültig (Format YYYY-MM-DD)');
      }
      end = parsed;
    }
    DateTime start = addDays(end, -defaultDays);
    if (rawStart != null) {
      final parsed = _parseDate(rawStart);
      if (parsed == null) {
        return (
          range: null,
          error: 'start_date ist ungültig (Format YYYY-MM-DD)',
        );
      }
      start = parsed;
    }
    if (start.isAfter(end)) {
      return (range: null, error: 'start_date liegt nach end_date');
    }
    final days = calendarDayDiff(start, end) + 1;
    if (days > maxRange) {
      return (range: null, error: 'Zeitraum zu lang (max. $maxRange Tage)');
    }
    return (range: (start: start, end: end), error: null);
  }

  int _dailyBudget(int burned) =>
      goals.calories + (profile.eatBackActivityCalories ? burned : 0);

  Map<String, dynamic> _food(FoodEntry f) => {
    'name': f.name,
    if (f.amount != null) 'menge': '${_num(f.amount!)} ${f.unit ?? ''}'.trim(),
    'kcal': f.calories,
    'protein_g': f.protein,
    'kohlenhydrate_g': f.carbs,
    'fett_g': f.fat,
  };

  Future<Map<String, dynamic>> _dayLog(Map<String, dynamic> args) async {
    final date = _parseDate(args['date']);
    if (date == null) return {'error': 'date fehlt oder ist ungültig'};
    onStatus?.call('Schaut sich den ${_short.format(date)} an …');

    final foods = await loadFoods(date, date);
    final activities = await loadActivities(date, date);
    final weights = await loadWeights(date, date);
    final day = NutritionStats.daily(foods, activities, date, date).first;
    final budget = _dailyBudget(day.burned);

    return {
      'datum': dayKey(date),
      'wochentag': _weekday.format(date),
      'mahlzeiten': foods.map(_food).toList(),
      'aktivitaeten': [
        for (final a in activities) {'name': a.name, 'kcal': a.caloriesBurned},
      ],
      if (weights.isNotEmpty) 'gewicht_kg': weights.first.weightKg,
      'summe': {
        'kcal': day.calories,
        'protein_g': day.protein,
        'kohlenhydrate_g': day.carbs,
        'fett_g': day.fat,
      },
      if (goals.calories > 0) ...{
        'budget_kcal': budget,
        'differenz_kcal': day.calories - budget,
        'protein_ziel_g': goals.proteinGrams,
      },
      if (!day.isLogged) 'hinweis': 'An diesem Tag wurde nichts geloggt.',
    };
  }

  Future<Map<String, dynamic>> _periodSummary(Map<String, dynamic> args) async {
    final parsed = _parseRange(args);
    if (parsed.range == null) return {'error': parsed.error};
    final range = parsed.range!;
    final groupBy = args['group_by'] as String? ?? 'week';
    final days = calendarDayDiff(range.start, range.end) + 1;
    if (groupBy == 'day' && days > maxDayRange) {
      return {
        'error':
            'Für mehr als $maxDayRange Tage bitte group_by "week" oder "month" nutzen',
      };
    }
    onStatus?.call(
      'Wertet ${_short.format(range.start)}–${_short.format(range.end)} aus …',
    );

    final foods = await loadFoods(range.start, range.end);
    final activities = await loadActivities(range.start, range.end);
    final daily = NutritionStats.daily(
      foods,
      activities,
      range.start,
      range.end,
    );
    final goal = goals.calories;
    final eatBack = profile.eatBackActivityCalories;

    final List<PeriodStats> groups = switch (groupBy) {
      'day' => [
        for (final d in daily)
          NutritionStats.period(
            daily,
            d.date,
            d.date,
            dailyGoal: goal,
            eatBackActivity: eatBack,
          ),
      ],
      'month' => NutritionStats.monthly(
        daily,
        dailyGoal: goal,
        eatBackActivity: eatBack,
      ),
      _ => NutritionStats.weekly(
        daily,
        dailyGoal: goal,
        eatBackActivity: eatBack,
      ),
    };
    final total = NutritionStats.period(
      daily,
      range.start,
      range.end,
      dailyGoal: goal,
      eatBackActivity: eatBack,
    );

    return {
      'zeitraum': '${dayKey(range.start)} bis ${dayKey(range.end)}',
      'tagesziel_kcal': goal,
      'protein_ziel_g': goals.proteinGrams,
      'gesamt': _periodJson(total),
      'gruppen': [
        for (final g in groups)
          {
            'von': dayKey(g.start),
            'bis': dayKey(g.end),
            if (groupBy == 'day') 'wochentag': _weekday.format(g.start),
            ..._periodJson(g),
          },
      ],
      'hinweis':
          'budget_kcal zählt alle Kalendertage; bilanz_geloggte_tage_kcal nur Tage mit Einträgen (negativ = Defizit). Tage ohne Einträge sind vermutlich nicht geloggt, nicht gefastet.',
    };
  }

  Map<String, dynamic> _periodJson(PeriodStats p) => {
    'kcal': p.calories,
    'protein_g': p.protein,
    'kohlenhydrate_g': p.carbs,
    'fett_g': p.fat,
    if (p.burned > 0) 'aktivitaet_kcal': p.burned,
    'kalendertage': p.calendarDays,
    'geloggte_tage': p.loggedDays,
    if (goals.calories > 0) ...{
      'budget_kcal': p.budget,
      'bilanz_geloggte_tage_kcal': p.loggedBalance,
    },
    if (p.loggedDays > 0) ...{
      'durchschnitt_kcal_pro_geloggtem_tag': p.avgCaloriesPerLoggedDay.round(),
      'durchschnitt_protein_g_pro_geloggtem_tag': p.avgProteinPerLoggedDay
          .round(),
    },
  };

  Future<Map<String, dynamic>> _weightHistory(Map<String, dynamic> args) async {
    final parsed = _parseRange(args, defaultDays: 60);
    if (parsed.range == null) return {'error': parsed.error};
    final range = parsed.range!;
    onStatus?.call('Schaut sich deinen Gewichtsverlauf an …');
    final weights = await loadWeights(addDays(range.start, -6), range.end);
    final trend = NutritionStats.weightTrend(weights);
    final inRange = [
      for (var i = 0; i < weights.length; i++)
        if (!weights[i].date.isBefore(range.start)) i,
    ];
    return {
      'zeitraum': '${dayKey(range.start)} bis ${dayKey(range.end)}',
      'eintraege': [
        for (final i in inRange)
          {
            'datum': dayKey(weights[i].date),
            'kg': weights[i].weightKg,
            'durchschnitt_7_tage_kg': double.parse(
              trend[i].average.toStringAsFixed(2),
            ),
          },
      ],
      if (inRange.isEmpty) 'hinweis': 'Keine Gewichtseinträge im Zeitraum.',
    };
  }

  Future<Map<String, dynamic>> _searchMeals(Map<String, dynamic> args) async {
    final query = (args['query'] as String? ?? '').trim().toLowerCase();
    if (query.isEmpty) return {'error': 'query fehlt'};
    final parsed = _parseRange(args, defaultDays: 365);
    if (parsed.range == null) return {'error': parsed.error};
    final range = parsed.range!;
    onStatus?.call('Sucht nach „${args['query']}“ …');

    final matches = (await loadFoods(
      range.start,
      range.end,
    )).where((f) => f.name.toLowerCase().contains(query)).toList();
    matches.sort((a, b) => b.date.compareTo(a.date));

    return {
      'suchbegriff': args['query'],
      'zeitraum': '${dayKey(range.start)} bis ${dayKey(range.end)}',
      'anzahl_treffer': matches.length,
      'kcal_gesamt': matches.fold(0, (s, f) => s + f.calories),
      'treffer': [
        for (final f in matches.take(maxSearchResults))
          {'datum': dayKey(f.date), ..._food(f)},
      ],
      if (matches.length > maxSearchResults)
        'hinweis': 'Nur die neuesten $maxSearchResults Treffer gezeigt.',
    };
  }

  Future<Map<String, dynamic>> _topFoods(Map<String, dynamic> args) async {
    final parsed = _parseRange(args);
    if (parsed.range == null) return {'error': parsed.error};
    final range = parsed.range!;
    final limit = ((args['limit'] as num?)?.toInt() ?? 10).clamp(1, 30);
    onStatus?.call('Sucht deine häufigsten Lebensmittel …');

    final foods = await loadFoods(range.start, range.end);
    final groups =
        <String, ({String name, int count, int kcal, int protein})>{};
    for (final f in foods) {
      final key = f.name.toLowerCase().trim();
      final g = groups[key];
      groups[key] = (
        name: g?.name ?? f.name,
        count: (g?.count ?? 0) + 1,
        kcal: (g?.kcal ?? 0) + f.calories,
        protein: (g?.protein ?? 0) + f.protein,
      );
    }
    final totalKcal = foods.fold(0, (s, f) => s + f.calories);
    List<Map<String, dynamic>> top(
      int Function(
        ({String name, int count, int kcal, int protein}),
        ({String name, int count, int kcal, int protein}),
      )
      compare,
    ) {
      final sorted = groups.values.toList()..sort(compare);
      return [
        for (final g in sorted.take(limit))
          {
            'name': g.name,
            'anzahl': g.count,
            'kcal_gesamt': g.kcal,
            'protein_g_gesamt': g.protein,
            if (totalKcal > 0)
              'anteil_kcal_prozent': (g.kcal * 100 / totalKcal).round(),
          },
      ];
    }

    return {
      'zeitraum': '${dayKey(range.start)} bis ${dayKey(range.end)}',
      'kcal_gesamt': totalKcal,
      'meiste_kalorien': top((a, b) => b.kcal.compareTo(a.kcal)),
      'am_haeufigsten': top((a, b) => b.count.compareTo(a.count)),
    };
  }

  Future<Map<String, dynamic>> _getUserPlan(Map<String, dynamic> args) async {
    if (loadPlans == null) return {'error': 'Keine Pläne verfügbar.'};
    onStatus?.call('Liest deinen Plan …');
    final plans = await loadPlans!();
    final active = plans.where((p) => p.isActive).toList();
    final planId = (args['plan_id'] as String?)?.trim();
    if (planId == null || planId.isEmpty) {
      return {
        'plaene': [
          for (final p in active)
            {
              'id': p.id,
              'typ': p.type.label,
              'titel': p.title,
              'laenge_zeichen': p.content.length,
              'inhalt': p.content,
            },
        ],
      };
    }
    final match = plans.where((p) => p.id == planId).firstOrNull;
    if (match == null) return {'error': 'Plan "$planId" nicht gefunden.'};
    return {
      'id': match.id,
      'typ': match.type.label,
      'titel': match.title,
      'inhalt': match.content,
    };
  }

  Future<Map<String, dynamic>> _logFood(Map<String, dynamic> args) async {
    if (onLogFood == null) return {'error': 'Schreibzugriff nicht verfügbar.'};
    final name = (args['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return {'error': 'name fehlt'};
    final date = args['date'] == null ? today : _parseDate(args['date']);
    if (date == null) return {'error': 'date ist ungültig'};
    final calories = (args['calories'] as num?)?.round();
    if (calories == null || calories < 0) return {'error': 'calories ungültig'};

    onStatus?.call('Trägt „$name“ ein …');
    final entry = FoodEntry(
      name: name,
      calories: calories,
      protein: ((args['protein'] as num?)?.round() ?? 0).clamp(0, 10000),
      carbs: ((args['carbs'] as num?)?.round() ?? 0).clamp(0, 10000),
      fat: ((args['fat'] as num?)?.round() ?? 0).clamp(0, 10000),
      date: date,
      amount: (args['amount'] as num?)?.toDouble(),
      unit: args['unit'] as String?,
    );
    await onLogFood!(entry);
    return {'status': 'gespeichert', 'datum': dayKey(date), ..._food(entry)};
  }

  Future<Map<String, dynamic>> _logActivity(Map<String, dynamic> args) async {
    if (onLogActivity == null) {
      return {'error': 'Schreibzugriff nicht verfügbar.'};
    }
    final name = (args['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return {'error': 'name fehlt'};
    final date = args['date'] == null ? today : _parseDate(args['date']);
    if (date == null) return {'error': 'date ist ungültig'};
    final burned = (args['calories_burned'] as num?)?.round();
    if (burned == null || burned <= 0) {
      return {'error': 'calories_burned ungültig'};
    }

    onStatus?.call('Trägt Aktivität „$name“ ein …');
    final entry = ActivityEntry(
      name: name,
      caloriesBurned: burned,
      date: date,
    );
    await onLogActivity!(entry);
    return {
      'status': 'gespeichert',
      'datum': dayKey(date),
      'name': entry.name,
      'kcal': entry.caloriesBurned,
    };
  }

  Future<Map<String, dynamic>> _logWeight(Map<String, dynamic> args) async {
    if (onLogWeight == null) return {'error': 'Schreibzugriff nicht verfügbar.'};
    final date = args['date'] == null ? today : _parseDate(args['date']);
    if (date == null) return {'error': 'date ist ungültig'};
    final weight = (args['weight_kg'] as num?)?.toDouble();
    if (weight == null || weight < 20 || weight > 400) {
      return {'error': 'weight_kg ungültig'};
    }

    onStatus?.call('Speichert Gewicht …');
    final entry = WeightEntry(date: date, weightKg: weight);
    await onLogWeight!(entry);
    return {
      'status': 'gespeichert',
      'datum': dayKey(date),
      'gewicht_kg': entry.weightKg,
    };
  }

  static String _num(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
