import 'enums.dart';

/// User profile containing personal data and API keys
class UserProfile {
  final String geminiApiKey;
  final String claudeApiKey;
  final String openaiApiKey;
  final String grokApiKey;
  final Map<AiProvider, String> modelOverrides;
  final AiProvider selectedProvider;
  final int age;
  final double weightKg;
  final double heightCm;
  final double bodyFatPercent;
  final Gender gender;
  final ActivityLevel activityLevel;
  final FitnessGoal goal;
  final bool eatBackActivityCalories;
  final String aboutMe;

  const UserProfile({
    this.geminiApiKey = '',
    this.claudeApiKey = '',
    this.openaiApiKey = '',
    this.grokApiKey = '',
    this.modelOverrides = const {},
    this.selectedProvider = AiProvider.gemini,
    this.age = 0,
    this.weightKg = 0.0,
    this.heightCm = 0.0,
    this.bodyFatPercent = 0.0,
    this.gender = Gender.male,
    this.activityLevel = ActivityLevel.sedentary,
    this.goal = FitnessGoal.maintainWeight,
    this.eatBackActivityCalories = false,
    this.aboutMe = '',
  });

  bool get hasBodyData => age > 0 && weightKg > 0 && heightCm > 0;

  String apiKeyFor(AiProvider provider) => switch (provider) {
    AiProvider.gemini => geminiApiKey,
    AiProvider.claude => claudeApiKey,
    AiProvider.openai => openaiApiKey,
    AiProvider.grok => grokApiKey,
  };

  String modelFor(AiProvider provider) {
    final override = modelOverrides[provider]?.trim() ?? '';
    return override.isEmpty ? provider.defaultModel : override;
  }

  UserProfile copyWith({
    String? geminiApiKey,
    String? claudeApiKey,
    String? openaiApiKey,
    String? grokApiKey,
    Map<AiProvider, String>? modelOverrides,
    AiProvider? selectedProvider,
    int? age,
    double? weightKg,
    double? heightCm,
    double? bodyFatPercent,
    Gender? gender,
    ActivityLevel? activityLevel,
    FitnessGoal? goal,
    bool? eatBackActivityCalories,
    String? aboutMe,
  }) {
    return UserProfile(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      claudeApiKey: claudeApiKey ?? this.claudeApiKey,
      openaiApiKey: openaiApiKey ?? this.openaiApiKey,
      grokApiKey: grokApiKey ?? this.grokApiKey,
      modelOverrides: modelOverrides ?? this.modelOverrides,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      age: age ?? this.age,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      eatBackActivityCalories:
          eatBackActivityCalories ?? this.eatBackActivityCalories,
      aboutMe: aboutMe ?? this.aboutMe,
    );
  }

  /// Profile data safe to share with AI providers (no API keys)
  String toPromptSummary() {
    final bodyFat = bodyFatPercent > 0
        ? ', Körperfett ${bodyFatPercent.toStringAsFixed(1)}%'
        : '';
    return '${gender == Gender.male ? 'Männlich' : 'Weiblich'}, $age Jahre, '
        '${weightKg.toStringAsFixed(1)} kg, ${heightCm.toStringAsFixed(0)} cm'
        '$bodyFat, Aktivität: ${activityLevel.description}, '
        'Ziel: ${goal.description}';
  }

  Map<String, dynamic> _modelOverridesToJson() => {
    for (final entry in modelOverrides.entries)
      if (entry.value.trim().isNotEmpty) entry.key.name: entry.value.trim(),
  };

  static Map<AiProvider, String> _modelOverridesFromJson(Object? json) {
    if (json is! Map) return const {};
    return {
      for (final provider in AiProvider.values)
        if (json[provider.name] is String)
          provider: json[provider.name] as String,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'geminiApiKey': geminiApiKey,
      'claudeApiKey': claudeApiKey,
      'openaiApiKey': openaiApiKey,
      'grokApiKey': grokApiKey,
      'modelOverrides': _modelOverridesToJson(),
      'selectedProvider': selectedProvider.index,
      'age': age,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'bodyFatPercent': bodyFatPercent,
      'gender': gender.index,
      'activityLevel': activityLevel.index,
      'goal': goal.name,
      'eatBackActivityCalories': eatBackActivityCalories,
      'aboutMe': aboutMe,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      claudeApiKey: json['claudeApiKey'] as String? ?? '',
      openaiApiKey: json['openaiApiKey'] as String? ?? '',
      grokApiKey: json['grokApiKey'] as String? ?? '',
      modelOverrides: _modelOverridesFromJson(json['modelOverrides']),
      selectedProvider:
          AiProvider.values[json['selectedProvider'] as int? ?? 0],
      age: json['age'] as int? ?? 0,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0.0,
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble() ?? 0.0,
      gender: Gender.values[json['gender'] as int? ?? 0],
      activityLevel: ActivityLevel.values[json['activityLevel'] as int? ?? 0],
      goal: FitnessGoal.fromStored(json['goal']),
      eatBackActivityCalories:
          json['eatBackActivityCalories'] as bool? ?? false,
      aboutMe: json['aboutMe'] as String? ?? '',
    );
  }
}
