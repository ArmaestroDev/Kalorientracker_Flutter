import 'package:flutter/material.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/enums.dart';
import '../../logic/goals_calculator.dart';
import '../../logic/number_format.dart';
import '../widgets/app_text_field.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile initialProfile;
  final ValueChanged<UserProfile> onSave;

  const ProfileScreen({
    super.key,
    required this.initialProfile,
    required this.onSave,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Map<AiProvider, TextEditingController> _apiKeyControllers;
  late final Map<AiProvider, TextEditingController> _modelControllers;
  late final TextEditingController _ageController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _bodyFatController;
  late final TextEditingController _aboutMeController;

  late AiProvider _selectedProvider;
  late Gender _gender;
  late ActivityLevel _activityLevel;
  late FitnessGoal _goal;
  late bool _eatBackActivityCalories;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _apiKeyControllers = {
      for (final provider in AiProvider.values)
        provider: TextEditingController(text: profile.apiKeyFor(provider)),
    };
    _modelControllers = {
      for (final provider in AiProvider.values)
        provider: TextEditingController(
          text: profile.modelOverrides[provider] ?? '',
        ),
    };
    _ageController = TextEditingController(
      text: profile.age > 0 ? '${profile.age}' : '',
    );
    _weightController = TextEditingController(
      text: profile.weightKg > 0 ? formatLocalizedNumber(profile.weightKg) : '',
    );
    _heightController = TextEditingController(
      text: profile.heightCm > 0 ? formatLocalizedNumber(profile.heightCm) : '',
    );
    _bodyFatController = TextEditingController(
      text: profile.bodyFatPercent > 0
          ? formatLocalizedNumber(profile.bodyFatPercent)
          : '',
    );
    _aboutMeController = TextEditingController(text: profile.aboutMe);

    _selectedProvider = profile.selectedProvider;
    _gender = profile.gender;
    _activityLevel = profile.activityLevel;
    _goal = profile.goal;
    _eatBackActivityCalories = profile.eatBackActivityCalories;
  }

  @override
  void dispose() {
    for (final c in [
      ..._apiKeyControllers.values,
      ..._modelControllers.values,
      _ageController,
      _weightController,
      _heightController,
      _bodyFatController,
      _aboutMeController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  UserProfile _buildProfile() {
    return UserProfile(
      geminiApiKey: _apiKeyControllers[AiProvider.gemini]!.text.trim(),
      claudeApiKey: _apiKeyControllers[AiProvider.claude]!.text.trim(),
      openaiApiKey: _apiKeyControllers[AiProvider.openai]!.text.trim(),
      grokApiKey: _apiKeyControllers[AiProvider.grok]!.text.trim(),
      modelOverrides: {
        for (final entry in _modelControllers.entries)
          if (entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
      },
      selectedProvider: _selectedProvider,
      age: parseLocalizedNumber(_ageController.text)?.round() ?? 0,
      weightKg: parseLocalizedNumber(_weightController.text) ?? 0,
      heightCm: parseLocalizedNumber(_heightController.text) ?? 0,
      bodyFatPercent: parseLocalizedNumber(_bodyFatController.text) ?? 0,
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
      eatBackActivityCalories: _eatBackActivityCalories,
      aboutMe: _aboutMeController.text.trim(),
    );
  }

  void _refresh(String _) => setState(() {});

  Widget _sectionTitle(String title, {String? subtitle}) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalPreview(UserProfile profile) {
    final goals = GoalsCalculator.calculateGoals(profile);
    if (goals.calories <= 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final usesLeanMass = GoalsCalculator.leanMassKg(profile) != null;
    final onColor = colorScheme.onSecondaryContainer;

    return Card(
      color: colorScheme.secondaryContainer,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deine Ziele',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: onColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${goals.calories} kcal pro Tag',
              style: textTheme.headlineSmall?.copyWith(color: onColor),
            ),
            Text(
              'Protein ${goals.proteinGrams} g · Kohlenh. ${goals.carbsGrams} g · Fett ${goals.fatGrams} g',
              style: textTheme.bodyMedium?.copyWith(color: onColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Grundumsatz ${GoalsCalculator.calculateBmr(profile).round()} kcal '
              '(${usesLeanMass ? 'Katch-McArdle, Magermasse' : 'Mifflin-St Jeor'}) · '
              'Erhaltung ca. ${goals.maintenanceCalories} kcal',
              style: textTheme.bodySmall?.copyWith(color: onColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _buildProfile();
    final provider = _selectedProvider;

    return Scaffold(
      appBar: AppBar(title: const Text('Dein Profil & Ziele')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            _sectionTitle('Körperdaten'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField.number(
                    controller: _ageController,
                    label: 'Alter',
                    suffix: 'J.',
                    onChanged: _refresh,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<Gender>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Geschlecht',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: Gender.male,
                        child: Text('Männlich'),
                      ),
                      DropdownMenuItem(
                        value: Gender.female,
                        child: Text('Weiblich'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _gender = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField.number(
                    controller: _weightController,
                    label: 'Gewicht',
                    suffix: 'kg',
                    onChanged: _refresh,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField.number(
                    controller: _heightController,
                    label: 'Größe',
                    suffix: 'cm',
                    onChanged: _refresh,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField.number(
              controller: _bodyFatController,
              label: 'Körperfett (optional)',
              suffix: '%',
              helper:
                  'Wenn bekannt, werden Grundumsatz und Protein genauer über die Magermasse berechnet.',
              onChanged: _refresh,
            ),

            _sectionTitle('Aktivität & Ziel'),
            DropdownButtonFormField<ActivityLevel>(
              initialValue: _activityLevel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Aktivitätslevel',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final level in ActivityLevel.values)
                  DropdownMenuItem(
                    value: level,
                    child: Text(
                      level.description,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _activityLevel = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FitnessGoal>(
              initialValue: _goal,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Fitness-Ziel',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final goal in FitnessGoal.values)
                  DropdownMenuItem(
                    value: goal,
                    child: Text(
                      goal.description,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _goal = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktivitätskalorien zum Tagesziel addieren'),
              subtitle: const Text(
                'Nur aktivieren, wenn dein Aktivitätslevel dein Training nicht schon enthält (z. B. „Sitzend“). Sonst wird Training doppelt gezählt.',
              ),
              value: _eatBackActivityCalories,
              onChanged: (value) =>
                  setState(() => _eatBackActivityCalories = value),
            ),
            _buildGoalPreview(profile),

            _sectionTitle(
              'Über mich',
              subtitle:
                  'Dein Coach berücksichtigt das bei jeder Antwort und jedem Vorschlag.',
            ),
            AppTextField(
              controller: _aboutMeController,
              hint:
                  'z. B. BJJ 3–5× pro Woche, koche nicht selbst, esse in der Mensa, abends oft Hunger, keine Allergien, mag Skyr …',
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              maxLines: 8,
              minLines: 4,
            ),

            _sectionTitle('KI-Assistent'),
            DropdownButtonFormField<AiProvider>(
              initialValue: provider,
              decoration: const InputDecoration(
                labelText: 'KI-Anbieter',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final p in AiProvider.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedProvider = value;
                    _showApiKey = false;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    key: ValueKey('key-${provider.name}-$_showApiKey'),
                    controller: _apiKeyControllers[provider]!,
                    label: '${provider.label} API-Schlüssel',
                    obscureText: !_showApiKey,
                  ),
                ),
                IconButton(
                  tooltip: _showApiKey ? 'Verbergen' : 'Anzeigen',
                  icon: Icon(
                    _showApiKey ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _showApiKey = !_showApiKey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              key: ValueKey('model-${provider.name}'),
              controller: _modelControllers[provider]!,
              label: 'Modell (optional)',
              hint: provider.defaultModel,
              helper:
                  'Leer lassen für ${provider.defaultModel}. Nur ändern, wenn der Anbieter das Modell umbenannt hat.',
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: profile.hasBodyData
                  ? () => widget.onSave(_buildProfile())
                  : null,
              icon: const Icon(Icons.save),
              label: const Text('Speichern'),
            ),
            if (!profile.hasBodyData)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Alter, Gewicht und Größe werden zum Speichern benötigt.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
