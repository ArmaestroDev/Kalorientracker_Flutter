import 'package:intl/intl.dart';
import '../data/models/activity_entry.dart';
import '../data/models/calorie_goals.dart';
import '../data/models/food_entry.dart';
import '../data/models/user_plan.dart';
import '../data/models/user_profile.dart';
import '../data/models/weight_entry.dart';
import 'nutrition_stats.dart';

/// Builds the always-included system prompt: who the user is, active plans,
/// today, this week and a short recent trend.
class AssistantContextBuilder {
  static const int _maxPlanCharsInline = 12000;

  static String build({
    required UserProfile profile,
    required CalorieGoals goals,
    required DateTime now,
    required DateTime selectedDate,
    required List<FoodEntry> dayFoods,
    required List<ActivityEntry> dayActivities,
    required int dayBudget,
    required WeekStatus week,
    required List<DayStats> recentDays,
    required List<WeightEntry> recentWeights,
    List<UserPlan> plans = const [],
    List<FoodEntry>? selectedDayFoods,
    List<ActivityEntry>? selectedDayActivities,
    int? selectedDayBudget,
  }) {
    final longDate = DateFormat('EEEE, d. MMMM y', 'de_DE');
    final shortDate = DateFormat('EE dd.MM.', 'de_DE');
    final time = DateFormat('HH:mm', 'de_DE');
    final today = dayOnly(now);
    final activePlans = plans
        .where((p) => p.isActive && p.content.trim().isNotEmpty)
        .toList();
    final sb = StringBuffer();

    sb.writeln(
      'Du bist der persönliche Ernährungs- und Trainingscoach des Nutzers in seiner Kalorien-Tracker-App.',
    );
    sb.writeln(
      'Unten stehen Profil, hinterlegte Pläne, heutiger Tag, die aktuelle Woche und die letzten 7 Tage. Für alles Weitere (ältere Tage, einzelne Mahlzeiten, Wochen-/Monatsvergleiche, Gewichtsverlauf, Suche nach Lebensmitteln) rufst du die Tools auf.',
    );
    sb.writeln();
    sb.writeln('Regeln:');
    sb.writeln('- Antworte auf Deutsch, duze den Nutzer.');
    sb.writeln(
      '- Kurz, konkret, umsetzbar. Markdown mit kurzen Listen und **fetten Zahlen**. Keine langen Einleitungen.',
    );
    sb.writeln(
      '- Nenne echte Zahlen aus den Daten (z. B. "Diese Woche hast du 9.800 kcal gegessen, dir bleiben noch 6.500 kcal").',
    );
    sb.writeln(
      '- Rate nie Daten. Wenn dir etwas fehlt, hol es mit einem Tool; wenn es nicht existiert, sag das.',
    );
    sb.writeln(
      '- Hol nur, was die Frage braucht: z. B. für einen Monatsrückblick get_period_summary mit group_by "week", nicht jeden Tag einzeln.',
    );
    sb.writeln(
      '- Tage ohne Einträge sind vermutlich nicht geloggt, nicht gefastet. Weise darauf hin statt sie als Erfolg zu werten.',
    );
    sb.writeln(
      '- Schlage Essen passend zu Alltag und Vorlieben vor (siehe "Über mich").',
    );
    if (activePlans.isNotEmpty) {
      sb.writeln(
        '- Orientiere deine Mahlzeiten-, Makro-, Timing- und Trainingsempfehlungen immer aktiv an den hinterlegten Ernährungs- und Trainingsplänen des Nutzers und passe sie an das aktuelle Budget an.',
      );
    }
    sb.writeln(
      '- Logge Mahlzeiten, Aktivitäten oder Gewicht nur mit den log_*-Tools, wenn der Nutzer ausdrücklich darum bittet.',
    );
    sb.writeln(
      '- Keine medizinischen Diagnosen; bei Beschwerden an Ärzte verweisen.',
    );
    sb.writeln('- Datumsangaben für Tools im Format YYYY-MM-DD.');
    sb.writeln();

    sb.writeln('## Jetzt');
    sb.writeln(
      '${longDate.format(now)}, ${time.format(now)} Uhr (${dayKey(today)})',
    );
    if (dayOnly(selectedDate) != today) {
      sb.writeln(
        'In der App geöffnet: ${longDate.format(selectedDate)} (${dayKey(selectedDate)}).',
      );
    }
    sb.writeln();

    sb.writeln('## Profil');
    sb.writeln(
      profile.hasBodyData
          ? profile.toPromptSummary()
          : 'Profil unvollständig (Alter/Gewicht/Größe fehlen).',
    );
    if (profile.aboutMe.trim().isNotEmpty) {
      sb.writeln();
      sb.writeln('## Über mich (vom Nutzer)');
      sb.writeln(profile.aboutMe.trim());
    }
    sb.writeln();

    if (activePlans.isNotEmpty) {
      sb.writeln('## Persönliche Pläne (Ernährungs- & Trainingspläne)');
      var remainingChars = _maxPlanCharsInline;
      for (final plan in activePlans) {
        sb.writeln('### ${plan.type.label}: ${plan.title} (id: ${plan.id})');
        final content = plan.content.trim();
        if (content.length <= remainingChars) {
          sb.writeln(content);
          remainingChars -= content.length;
        } else {
          final slice = remainingChars > 200
              ? '${content.substring(0, remainingChars)}\n[… gekürzt – rufe get_user_plan(plan_id: "${plan.id}") für den vollständigen Plan auf]'
              : '[Inhalt lang – rufe get_user_plan(plan_id: "${plan.id}") auf]';
          sb.writeln(slice);
          remainingChars = 0;
        }
        sb.writeln();
      }
    }

    sb.writeln('## Ziele');
    if (goals.calories > 0) {
      sb.writeln(goals.toPromptSummary());
      sb.writeln(
        profile.eatBackActivityCalories
            ? 'Geloggte Aktivitäten erhöhen das Tagesbudget.'
            : 'Training ist über das Aktivitätslevel bereits im Ziel enthalten; geloggte Aktivitäten erhöhen das Budget nicht.',
      );
    } else {
      sb.writeln('Noch keine Ziele berechnet.');
    }
    sb.writeln();

    final primaryDay = selectedDayFoods != null
        ? today
        : dayOnly(selectedDate);
    final primaryLabel = primaryDay == today
        ? 'Heute'
        : shortDate.format(primaryDay);
    _writeDaySection(
      sb,
      label: primaryLabel,
      foods: dayFoods,
      activities: dayActivities,
      dayBudget: dayBudget,
      goals: goals,
    );

    if (selectedDayFoods != null && dayOnly(selectedDate) != today) {
      _writeDaySection(
        sb,
        label: 'Geöffneter Tag (${shortDate.format(selectedDate)})',
        foods: selectedDayFoods,
        activities: selectedDayActivities ?? const [],
        dayBudget: selectedDayBudget ?? goals.calories,
        goals: goals,
      );
    }

    if (goals.calories > 0) {
      sb.writeln(
        '## Diese Woche (${shortDate.format(week.week.start)} – ${shortDate.format(week.week.end)})',
      );
      sb.writeln(
        'Gegessen bis einschließlich $primaryLabel: ${_thousands(week.consumed)} kcal von ${_thousands(week.budget)} kcal Wochenbudget.',
      );
      sb.writeln(
        week.remaining >= 0
            ? 'Übrig für die Woche: ${_thousands(week.remaining)} kcal, verteilt auf ${week.remainingDays} verbleibende Tage (inkl. $primaryLabel) ≈ ${_thousands(week.perRemainingDay)} kcal/Tag.'
            : 'Wochenbudget um ${_thousands(-week.remaining)} kcal überschritten.',
      );
      if (week.unloggedPastDays > 0) {
        sb.writeln(
          'Hinweis: ${week.unloggedPastDays} vergangene Tage dieser Woche ohne Einträge (im Wochenbudget oben bereits herausgerechnet).',
        );
      }
      sb.writeln();
    }

    sb.writeln('## Letzte 7 Tage (Tagessummen)');
    for (final d in recentDays) {
      sb.writeln(
        d.isLogged
            ? '- ${shortDate.format(d.date)}: ${d.calories} kcal, P ${d.protein} g${d.burned > 0 ? ', Aktivität ${d.burned} kcal' : ''}'
            : '- ${shortDate.format(d.date)}: keine Einträge',
      );
    }
    sb.writeln();

    sb.writeln('## Gewicht');
    if (recentWeights.isEmpty) {
      sb.writeln('Keine Einträge in den letzten 14 Tagen.');
    } else {
      final trend = NutritionStats.weightTrend(recentWeights);
      final latest = recentWeights.last;
      sb.writeln(
        'Zuletzt ${_num(latest.weightKg)} kg am ${shortDate.format(latest.date)}, 7-Tage-Schnitt ${_num(trend.last.average)} kg.',
      );
      final weekAgo = trend.where(
        (t) => !t.date.isAfter(addDays(latest.date, -7)),
      );
      if (weekAgo.isNotEmpty) {
        final change = trend.last.average - weekAgo.last.average;
        sb.writeln(
          'Veränderung des Schnitts ggü. Vorwoche: ${change > 0 ? '+' : ''}${_num(change)} kg.',
        );
      }
    }

    return sb.toString();
  }

  static void _writeDaySection(
    StringBuffer sb, {
    required String label,
    required List<FoodEntry> foods,
    required List<ActivityEntry> activities,
    required int dayBudget,
    required CalorieGoals goals,
  }) {
    final eaten = foods.fold(0, (s, f) => s + f.calories);
    final protein = foods.fold(0, (s, f) => s + f.protein);
    sb.writeln('## $label');
    if (foods.isEmpty) {
      sb.writeln('Noch nichts geloggt.');
    } else {
      for (final f in foods) {
        final amount = f.amount != null && f.unit != null && f.unit!.isNotEmpty
            ? ' (${_num(f.amount!)} ${f.unit})'
            : '';
        sb.writeln(
          '- ${f.name}$amount: ${f.calories} kcal, P ${f.protein} g, K ${f.carbs} g, F ${f.fat} g',
        );
      }
      sb.writeln(
        'Summe: $eaten kcal, P $protein g, K ${foods.fold(0, (s, f) => s + f.carbs)} g, F ${foods.fold(0, (s, f) => s + f.fat)} g',
      );
    }
    for (final a in activities) {
      sb.writeln('- Aktivität: ${a.name}, ${a.caloriesBurned} kcal');
    }
    if (goals.calories > 0) {
      final remaining = dayBudget - eaten;
      sb.writeln(
        remaining >= 0
            ? 'Tagesbudget: noch $remaining von $dayBudget kcal.'
            : 'Tagesbudget um ${-remaining} kcal überschritten ($dayBudget kcal).',
      );
      if (goals.proteinGrams > protein) {
        sb.writeln('Protein noch offen: ${goals.proteinGrams - protein} g.');
      }
    }
    sb.writeln();
  }

  static String _num(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    final text = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
    return text.replaceAll('.', ',');
  }

  static String _thousands(int value) =>
      NumberFormat.decimalPattern('de_DE').format(value);
}
