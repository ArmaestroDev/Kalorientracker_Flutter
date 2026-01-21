/// Enums used throughout the Kalorientracker app
library;

enum AiProvider { gemini, claude }

enum Gender { male, female }

enum ActivityLevel {
  sedentary(1.2, 'Sitzend (wenig oder kein Training)'),
  lightlyActive(1.375, 'Leicht aktiv (1-3 Tage/Woche)'),
  moderatelyActive(1.55, 'Mäßig aktiv (3-5 Tage/Woche)'),
  veryActive(1.725, 'Sehr aktiv (6-7 Tage/Woche)'),
  extraActive(1.9, 'Extrem aktiv (sehr hartes Training)');

  final double multiplier;
  final String description;

  const ActivityLevel(this.multiplier, this.description);
}

enum FitnessGoal {
  loseWeight(-500, 'Gewicht verlieren (-500 kcal Defizit)'),
  maintainWeight(0, 'Gewicht halten'),
  gainWeight(500, 'Gewicht zunehmen (+500 kcal Überschuss)');

  final int calorieModifier;
  final String description;

  const FitnessGoal(this.calorieModifier, this.description);
}
