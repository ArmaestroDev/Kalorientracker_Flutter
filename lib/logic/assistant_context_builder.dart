import 'package:intl/intl.dart';
import '../data/models/activity_entry.dart';
import '../data/models/calorie_goals.dart';
import '../data/models/food_entry.dart';
import '../data/models/user_profile.dart';
import '../data/models/weight_entry.dart';

class DaySummary {
  final DateTime date;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int burned;
  final int entries;

  const DaySummary({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.burned,
    required this.entries,
  });

  static List<DaySummary> fromEntries(
    List<FoodEntry> foods,
    List<ActivityEntry> activities,
  ) {
    final days = <String, DateTime>{};
    for (final f in foods) {
      days[_key(f.date)] = DateTime(f.date.year, f.date.month, f.date.day);
    }
    for (final a in activities) {
      days[_key(a.date)] = DateTime(a.date.year, a.date.month, a.date.day);
    }
    final keys = days.keys.toList()..sort();
    return [
      for (final key in keys)
        DaySummary(
          date: days[key]!,
          calories: foods
              .where((f) => _key(f.date) == key)
              .fold(0, (s, f) => s + f.calories),
          protein: foods
              .where((f) => _key(f.date) == key)
              .fold(0, (s, f) => s + f.protein),
          carbs: foods
              .where((f) => _key(f.date) == key)
              .fold(0, (s, f) => s + f.carbs),
          fat: foods
              .where((f) => _key(f.date) == key)
              .fold(0, (s, f) => s + f.fat),
          burned: activities
              .where((a) => _key(a.date) == key)
              .fold(0, (s, a) => s + a.caloriesBurned),
          entries: foods.where((f) => _key(f.date) == key).length,
        ),
    ];
  }

  static String _key(DateTime d) => d.toIso8601String().split('T')[0];
}

/// Builds the system prompt that makes the assistant personal: it always sees
/// the profile, goals, the viewed day and recent history.
class AssistantContextBuilder {
  static String build({
    required UserProfile profile,
    required CalorieGoals goals,
    required DateTime now,
    required DateTime selectedDate,
    required List<FoodEntry> dayFoods,
    required List<ActivityEntry> dayActivities,
    required int dayBudget,
    required List<DaySummary> history,
    required List<WeightEntry> weights,
  }) {
    final date = DateFormat('EEEE, d. MMMM y', 'de_DE');
    final shortDate = DateFormat('EE dd.MM.', 'de_DE');
    final time = DateFormat('HH:mm', 'de_DE');
    final sb = StringBuffer();

    sb.writeln(
      'Du bist der persönliche Ernährungs- und Trainingscoach des Nutzers in seiner Kalorien-Tracker-App.',
    );
    sb.writeln(
      'Du kennst seine Daten unten und nutzt sie aktiv: Beziehe dich auf konkrete Zahlen, Einträge und Gewohnheiten, statt allgemeine Tipps zu geben.',
    );
    sb.writeln();
    sb.writeln('Regeln:');
    sb.writeln('- Antworte immer auf Deutsch und duze den Nutzer.');
    sb.writeln(
      '- Sei kurz, konkret und praktisch umsetzbar. Nutze Markdown (kurze Listen, **fett** für Zahlen). Keine langen Einleitungen.',
    );
    sb.writeln(
      '- Erfinde keine Daten. Wenn etwas fehlt (z. B. keine Einträge oder kein Gewicht), sag das und schlage vor, es nachzutragen.',
    );
    sb.writeln(
      '- Schlage Essen vor, das zu seinen Gewohnheiten und seinem Alltag passt (siehe "Über mich").',
    );
    sb.writeln(
      '- Tagessumme vs. Ziel: Unvollständig geloggte Tage nicht als Erfolg werten.',
    );
    sb.writeln(
      '- Keine medizinischen Diagnosen; bei gesundheitlichen Beschwerden an Ärzte verweisen.',
    );
    sb.writeln();

    sb.writeln('## Jetzt');
    sb.writeln('${date.format(now)}, ${time.format(now)} Uhr');
    if (!_sameDay(now, selectedDate)) {
      sb.writeln(
        'Der Nutzer schaut sich gerade ${date.format(selectedDate)} in der App an.',
      );
    }
    sb.writeln();

    sb.writeln('## Profil');
    if (profile.hasBodyData) {
      sb.writeln(profile.toPromptSummary());
    } else {
      sb.writeln('Profil unvollständig (Alter/Gewicht/Größe fehlen).');
    }
    if (profile.aboutMe.trim().isNotEmpty) {
      sb.writeln();
      sb.writeln('## Über mich (vom Nutzer geschrieben)');
      sb.writeln(profile.aboutMe.trim());
    }
    sb.writeln();

    sb.writeln('## Tagesziele');
    if (goals.calories > 0) {
      sb.writeln(goals.toPromptSummary());
      sb.writeln(
        profile.eatBackActivityCalories
            ? 'Geloggte Aktivitäten werden zum Tagesbudget addiert.'
            : 'Regelmäßiges Training ist über das Aktivitätslevel bereits im Ziel enthalten; geloggte Aktivitäten erhöhen das Budget NICHT.',
      );
    } else {
      sb.writeln('Noch keine Ziele berechnet.');
    }
    sb.writeln();

    final label = _sameDay(now, selectedDate)
        ? 'Heute'
        : shortDate.format(selectedDate);
    final eaten = dayFoods.fold(0, (s, f) => s + f.calories);
    sb.writeln('## $label');
    if (dayFoods.isEmpty) {
      sb.writeln('Noch nichts gegessen/geloggt.');
    } else {
      for (final f in dayFoods) {
        final amount = f.amount != null && f.unit != null
            ? ' (${_num(f.amount!)} ${f.unit})'
            : '';
        sb.writeln(
          '- ${f.name}$amount: ${f.calories} kcal, P ${f.protein} g, K ${f.carbs} g, F ${f.fat} g',
        );
      }
      sb.writeln(
        'Summe: $eaten kcal, P ${dayFoods.fold(0, (s, f) => s + f.protein)} g, '
        'K ${dayFoods.fold(0, (s, f) => s + f.carbs)} g, F ${dayFoods.fold(0, (s, f) => s + f.fat)} g',
      );
    }
    for (final a in dayActivities) {
      sb.writeln('- Aktivität: ${a.name}, ${a.caloriesBurned} kcal');
    }
    if (goals.calories > 0) {
      final remaining = dayBudget - eaten;
      sb.writeln(
        remaining >= 0
            ? 'Noch übrig: $remaining kcal von $dayBudget kcal.'
            : 'Budget um ${-remaining} kcal überschritten ($dayBudget kcal).',
      );
      final proteinLeft =
          goals.proteinGrams - dayFoods.fold(0, (s, f) => s + f.protein);
      if (proteinLeft > 0) sb.writeln('Protein noch offen: $proteinLeft g.');
    }
    sb.writeln();

    final pastDays = history
        .where((d) => d.date.isBefore(_startOfDay(selectedDate)))
        .toList();
    sb.writeln('## Letzte 30 Tage (nur Tage mit Einträgen)');
    if (pastDays.isEmpty) {
      sb.writeln('Keine Einträge.');
    } else {
      for (final d in pastDays) {
        final burned = d.burned > 0 ? ', Aktivität ${d.burned} kcal' : '';
        sb.writeln(
          '- ${shortDate.format(d.date)}: ${d.calories} kcal, P ${d.protein} g, K ${d.carbs} g, F ${d.fat} g, ${d.entries} Einträge$burned',
        );
      }
      final last7 = pastDays
          .where(
            (d) => !d.date.isBefore(
              _startOfDay(selectedDate).subtract(const Duration(days: 7)),
            ),
          )
          .toList();
      if (last7.isNotEmpty) {
        final avgKcal = last7.fold(0, (s, d) => s + d.calories) / last7.length;
        final avgProtein =
            last7.fold(0, (s, d) => s + d.protein) / last7.length;
        sb.writeln(
          'Ø der letzten 7 Tage mit Einträgen (${last7.length} Tage): ${avgKcal.round()} kcal, P ${avgProtein.round()} g',
        );
      }
    }
    sb.writeln();

    sb.writeln('## Gewicht');
    if (weights.isEmpty) {
      sb.writeln('Keine Gewichtseinträge.');
    } else {
      for (final w in weights) {
        sb.writeln('- ${shortDate.format(w.date)}: ${_num(w.weightKg)} kg');
      }
    }

    return sb.toString();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _num(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return text.replaceAll('.', ',');
  }
}
