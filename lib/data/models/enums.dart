/// Enums used throughout the Kalorientracker app
library;

enum AiProvider {
  gemini('Gemini', 'gemini-2.5-flash'),
  claude('Claude', 'claude-sonnet-5-5'),
  openai('OpenAI', 'gpt-5-mini'),
  grok('Grok', 'grok-4');

  final String label;
  final String defaultModel;

  const AiProvider(this.label, this.defaultModel);

  bool get requiresPaidKey => this != AiProvider.gemini;

  String get keyHint => switch (this) {
    AiProvider.gemini => 'Kostenloser Schlüssel: aistudio.google.com/apikey',
    AiProvider.claude => 'Kostenpflichtig: console.anthropic.com',
    AiProvider.openai => 'Kostenpflichtig: platform.openai.com/api-keys',
    AiProvider.grok => 'Kostenpflichtig: console.x.ai',
  };
}

enum Gender { male, female }

enum ActivityLevel {
  sedentary(1.2, 'Sitzend (Bürojob, kein Training)'),
  lightlyActive(1.375, 'Leicht aktiv (Bürojob, 1-3x Training/Woche)'),
  moderatelyActive(1.55, 'Mäßig aktiv (Bürojob, 3-5x Training/Woche)'),
  veryActive(1.725, 'Sehr aktiv (6-7x Training/Woche)'),
  extraActive(1.9, 'Extrem aktiv (körperliche Arbeit + Training)');

  final double multiplier;
  final String description;

  const ActivityLevel(this.multiplier, this.description);
}

enum FitnessGoal {
  loseWeight(-500, 2.0, 'Abnehmen (-500 kcal, ~0,45 kg/Woche)'),
  loseWeightSlow(-250, 2.0, 'Rekomposition (-250 kcal, ~0,25 kg/Woche)'),
  maintainWeight(0, 1.8, 'Gewicht halten'),
  gainWeightSlow(250, 1.8, 'Lean Bulk (+250 kcal)'),
  gainWeight(500, 1.8, 'Zunehmen (+500 kcal)');

  final int calorieModifier;
  final double proteinPerKg;
  final String description;

  const FitnessGoal(this.calorieModifier, this.proteinPerKg, this.description);

  bool get isDeficit => calorieModifier < 0;

  static const _legacyIndexOrder = [loseWeight, maintainWeight, gainWeight];

  static FitnessGoal fromStored(Object? value) {
    if (value is String) {
      return values.firstWhere(
        (g) => g.name == value,
        orElse: () => maintainWeight,
      );
    }
    if (value is int && value >= 0 && value < _legacyIndexOrder.length) {
      return _legacyIndexOrder[value];
    }
    return maintainWeight;
  }
}
