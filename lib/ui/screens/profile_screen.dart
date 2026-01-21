import 'package:flutter/material.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/enums.dart';

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
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  late AiProvider _selectedProvider;
  late Gender _gender;
  late ActivityLevel _activityLevel;
  late FitnessGoal _goal;

  @override
  void initState() {
    super.initState();
    _geminiApiKeyController = TextEditingController(
      text: widget.initialProfile.geminiApiKey,
    );
    _claudeApiKeyController = TextEditingController(
      text: widget.initialProfile.claudeApiKey,
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

    _selectedProvider = widget.initialProfile.selectedProvider;
    _gender = widget.initialProfile.gender;
    _activityLevel = widget.initialProfile.activityLevel;
    _goal = widget.initialProfile.goal;
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _claudeApiKeyController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    final age = int.tryParse(_ageController.text) ?? 0;
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final height = double.tryParse(_heightController.text) ?? 0.0;
    return age > 0 && weight > 0.0 && height > 0.0;
  }

  void _save() {
    final profile = UserProfile(
      geminiApiKey: _geminiApiKeyController.text,
      claudeApiKey: _claudeApiKeyController.text,
      selectedProvider: _selectedProvider,
      age: int.tryParse(_ageController.text) ?? 0,
      weightKg: double.tryParse(_weightController.text) ?? 0.0,
      heightCm: double.tryParse(_heightController.text) ?? 0.0,
      gender: _gender,
      activityLevel: _activityLevel,
      goal: _goal,
    );
    widget.onSave(profile);
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
            else
              TextFormField(
                controller: _claudeApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Claude API Schlüssel',
                  hintText: 'Gib deinen Claude API-Schlüssel ein',
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
              keyboardType: TextInputType.number,
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
            const SizedBox(height: 32),

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
