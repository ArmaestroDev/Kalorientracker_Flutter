import 'package:flutter/material.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/enums.dart';
import '../../logic/goals_calculator.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile initialProfile;
  final Function(UserProfile) onSave;

  const ProfileScreen({
    super.key,
    required this.initialProfile,
    required this.onSave,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _geminiApiKeyController;
  late TextEditingController _claudeApiKeyController;
  late TextEditingController _openaiApiKeyController;
  late TextEditingController _grokApiKeyController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _bodyFatController;

  late AiProvider _selectedProvider;
  late Gender _gender;
  late ActivityLevel _activityLevel;
  late FitnessGoal _goal;
  late bool _eatBackActivityCalories;

  @override
  void initState() {
    super.initState();
    _geminiApiKeyController = TextEditingController(
      text: widget.initialProfile.geminiApiKey,
    );
    _claudeApiKeyController = TextEditingController(
      text: widget.initialProfile.claudeApiKey,
    );
    _openaiApiKeyController = TextEditingController(
      text: widget.initialProfile.openaiApiKey,
    );
    _grokApiKeyController = TextEditingController(
      text: widget.initialProfile.grokApiKey,
    );
    _ageController = TextEditingController(
      text: widget.initialProfile.age > 0
          ? widget.initialProfile.age.toString()
          : '',
    );
    _weightController = TextEditingController(
      text: widget.initialProfile.weightKg > 0
          ? widget.initialProfile.weightKg.toString()
          : '',
    );
    _heightController = TextEditingController(
      text: widget.initialProfile.heightCm > 0
          ? widget.initialProfile.heightCm.toString()
          : '',
    );

    _bodyFatController = TextEditingController(
      text: widget.initialProfile.bodyFatPercent > 0
          ? _formatNumber(widget.initialProfile.bodyFatPercent)
          : '',
    );
    _weightController.text = widget.initialProfile.weightKg > 0
        ? _formatNumber(widget.initialProfile.weightKg)
        : '';
    _heightController.text = widget.initialProfile.heightCm > 0
        ? _formatNumber(widget.initialProfile.heightCm)
        : '';
    for (final controller in [
      _ageController,
      _weightController,
      _heightController,
      _bodyFatController,
    ]) {
      controller.addListener(() => setState(() {}));
    }

    _eatBackActivityCalories = widget.initialProfile.eatBackActivityCalories;
    _selectedProvider = widget.initialProfile.selectedProvider;
    _gender = widget.initialProfile.gender;
    _activityLevel = widget.initialProfile.activityLevel;
    _goal = widget.initialProfile.goal;
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _claudeApiKeyController.dispose();
    _openaiApiKeyController.dispose();
    _grokApiKeyController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  static String _formatNumber(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return text.replaceAll('.', ',');
  }

  static double _parseNumber(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.')) ?? 0.0;

  bool get _isFormValid => _buildProfile().hasBodyData;

  void _save() => widget.onSave(_buildProfile());

  UserProfile _buildProfile() {
    return UserProfile(
      geminiApiKey: _geminiApiKeyController.text,
      claudeApiKey: _claudeApiKeyController.text,
      openaiApiKey: _openaiApiKeyController.text,
      grokApiKey: _grokApiKeyController.text,
      selectedProvider: _selectedProvider,
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      weightKg: _parseNumber(_weightController.text),
      heightCm: _parseNumber(_heightController.text),
      bodyFatPercent: _parseNumber(_bodyFatController.text),
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
      eatBackActivityCalories: _eatBackActivityCalories,
    );
  }

  Widget _buildGoalPreview(BuildContext context) {
    final profile = _buildProfile();
    final goals = GoalsCalculator.calculateGoals(profile);
    if (goals.calories <= 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final usesLeanMass = GoalsCalculator.leanMassKg(profile) != null;

    return Card(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deine Ziele',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${goals.calories} kcal pro Tag',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            Text(
              'Protein ${goals.proteinGrams}g · Kohlenh. ${goals.carbsGrams}g · Fett ${goals.fatGrams}g',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Grundumsatz ${GoalsCalculator.calculateBmr(profile).round()} kcal '
              '(${usesLeanMass ? 'Katch-McArdle, Magermasse' : 'Mifflin-St Jeor'}) · '
              'Erhaltung ca. ${goals.maintenanceCalories} kcal',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dein Profil & Ziele')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AI Provider Selection
            DropdownButtonFormField<AiProvider>(
              initialValue: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'KI-Anbieter',
                border: OutlineInputBorder(),
              ),
              items: AiProvider.values.map((provider) {
                return DropdownMenuItem(
                  value: provider,
                  child: Text(provider.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedProvider = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // API Key Input (conditional)
            if (_selectedProvider == AiProvider.gemini)
              TextFormField(
                controller: _geminiApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Gemini API Schlüssel',
                  hintText: 'Gib deinen Gemini API-Schlüssel ein',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              )
            else if (_selectedProvider == AiProvider.claude)
              TextFormField(
                controller: _claudeApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Claude API Schlüssel',
                  hintText: 'Gib deinen Claude API-Schlüssel ein',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              )
            else if (_selectedProvider == AiProvider.openai)
              TextFormField(
                controller: _openaiApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'OpenAI API Schlüssel',
                  hintText: 'Gib deinen OpenAI API-Schlüssel ein',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              )
            else
              TextFormField(
                controller: _grokApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Grok API Schlüssel',
                  hintText: 'Gib deinen Grok API-Schlüssel ein',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            const SizedBox(height: 16),

            // Age Input
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Alter',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Weight Input
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Gewicht (kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),

            // Height Input
            TextFormField(
              controller: _heightController,
              decoration: const InputDecoration(
                labelText: 'Größe (cm)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _bodyFatController,
              decoration: const InputDecoration(
                labelText: 'Körperfett (%) – optional',
                helperText:
                    'Wenn bekannt, werden Grundumsatz und Protein genauer über die Magermasse berechnet',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),

            // Gender Selection
            DropdownButtonFormField<Gender>(
              initialValue: _gender,
              decoration: const InputDecoration(
                labelText: 'Geschlecht',
                border: OutlineInputBorder(),
              ),
              items: Gender.values.map((gender) {
                return DropdownMenuItem(
                  value: gender,
                  child: Text(gender == Gender.male ? 'Männlich' : 'Weiblich'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _gender = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Activity Level Selection
            DropdownButtonFormField<ActivityLevel>(
              initialValue: _activityLevel,
              decoration: const InputDecoration(
                labelText: 'Aktivitätslevel',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: ActivityLevel.values.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(
                    level.description,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _activityLevel = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Fitness Goal Selection
            DropdownButtonFormField<FitnessGoal>(
              initialValue: _goal,
              decoration: const InputDecoration(
                labelText: 'Fitness-Ziel',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: FitnessGoal.values.map((goal) {
                return DropdownMenuItem(
                  value: goal,
                  child: Text(
                    goal.description,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _goal = value);
                }
              },
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktivitätskalorien zum Tagesziel addieren'),
              subtitle: const Text(
                'Nur aktivieren, wenn dein Aktivitätslevel dein Training NICHT schon enthält (z. B. "Sitzend"). Sonst wird Training doppelt gezählt.',
              ),
              value: _eatBackActivityCalories,
              onChanged: (value) =>
                  setState(() => _eatBackActivityCalories = value),
            ),
            const SizedBox(height: 16),

            _buildGoalPreview(context),
            const SizedBox(height: 16),

            // Save Button
            FilledButton(
              onPressed: _isFormValid ? _save : null,
              child: const Text('Speichern und Ziele neu berechnen'),
            ),
          ],
        ),
      ),
    );
  }
}
