import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/enums.dart';
import '../../data/models/user_profile.dart';
import '../../logic/goals_calculator.dart';
import '../../logic/number_format.dart';
import '../../logic/providers/main_provider.dart';
import '../theme/app_palettes.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_text_field.dart';
import '../widgets/kit/kit.dart';
import 'plans_screen.dart';

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
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _apiKeyControllers = {
      for (final provider in AiProvider.values)
        provider: TextEditingController(text: profile.apiKeyFor(provider)),
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
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final provider in AiProvider.values) {
      final oldKey = oldWidget.initialProfile.apiKeyFor(provider);
      final newKey = widget.initialProfile.apiKeyFor(provider);
      if (oldKey.trim() == newKey.trim()) continue;
      final controller = _apiKeyControllers[provider]!;
      if (controller.text.trim() == oldKey.trim()) {
        controller.text = newKey;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      ..._apiKeyControllers.values,
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
    final savedModelOverrides = context
        .read<MainProvider>()
        .userProfile
        .modelOverrides;
    return UserProfile(
      geminiApiKey: _apiKeyControllers[AiProvider.gemini]!.text.trim(),
      claudeApiKey: _apiKeyControllers[AiProvider.claude]!.text.trim(),
      openaiApiKey: _apiKeyControllers[AiProvider.openai]!.text.trim(),
      grokApiKey: _apiKeyControllers[AiProvider.grok]!.text.trim(),
      modelOverrides: {
        ...widget.initialProfile.modelOverrides,
        ...savedModelOverrides,
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

  String? _ageError(UserProfile profile) {
    if (_ageController.text.trim().isEmpty) return null;
    if (profile.age <= 0 || profile.age > 120) return '1–120 J.';
    return null;
  }

  String? _weightError(UserProfile profile) {
    if (_weightController.text.trim().isEmpty) return null;
    if (profile.weightKg <= 0 || profile.weightKg > 600) return '1–600 kg';
    return null;
  }

  String? _heightError(UserProfile profile) {
    if (_heightController.text.trim().isEmpty) return null;
    if (profile.heightCm <= 0 || profile.heightCm > 300) return '1–300 cm';
    return null;
  }

  String? _bodyFatError(UserProfile profile) {
    if (_bodyFatController.text.trim().isEmpty) return null;
    if (profile.bodyFatPercent < 3 || profile.bodyFatPercent > 60) {
      return '3–60 %';
    }
    return null;
  }

  String? _validate() {
    final age = parseLocalizedNumber(_ageController.text);
    if (age == null) return 'Bitte gib dein Alter an.';
    if (age < 1 || age > 120) {
      return 'Das Alter muss zwischen 1 und 120 Jahren liegen.';
    }

    final weight = parseLocalizedNumber(_weightController.text);
    if (weight == null) return 'Bitte gib dein Gewicht an.';
    if (weight < 1 || weight > 600) {
      return 'Das Gewicht muss zwischen 1 und 600 kg liegen.';
    }

    final height = parseLocalizedNumber(_heightController.text);
    if (height == null) return 'Bitte gib deine Größe an.';
    if (height < 1 || height > 300) {
      return 'Die Größe muss zwischen 1 und 300 cm liegen.';
    }

    if (_bodyFatController.text.trim().isNotEmpty) {
      final bodyFat = parseLocalizedNumber(_bodyFatController.text);
      if (bodyFat == null || bodyFat < 3 || bodyFat > 60) {
        return 'Der Körperfettanteil muss zwischen 3 und 60 % liegen.';
      }
    }
    return null;
  }

  void _refresh(String _) => setState(() {});

  void _save() {
    final problem = _validate();
    if (problem != null) {
      AppFeedback.error(context, problem);
      return;
    }
    widget.onSave(_buildProfile());
  }

  Future<void> _refreshModels() async {
    final problem = _validate();
    if (problem != null) {
      AppFeedback.error(context, problem);
      return;
    }
    final provider = context.read<MainProvider>();
    await provider.saveUserProfileAndRecalculateGoals(_buildProfile());
    await provider.refreshModelCatalog();
  }

  Future<void> _testConnection() async {
    final problem = _validate();
    if (problem != null) {
      AppFeedback.error(context, problem);
      return;
    }

    final provider = context.read<MainProvider>();
    final profile = _buildProfile();
    setState(() => _testing = true);
    await provider.saveUserProfileAndRecalculateGoals(profile);
    if (!mounted) return;
    final error = await provider.testConnection();
    if (!mounted) return;
    setState(() => _testing = false);
    if (error == null) {
      AppFeedback.success(
        context,
        'Verbindung OK – ${profile.modelFor(profile.selectedProvider)} antwortet',
      );
    } else {
      AppFeedback.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MainProvider>();
    final profile = _buildProfile();
    final selected = _selectedProvider;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.screenX,
            Space.sm,
            Space.screenX,
            Space.xxl + 72,
          ),
          children: [
            const SectionHeader(
              'KI-Anbieter',
              padding: EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.sm),
            ),
            AppCard(child: _buildAiCard(context, provider, profile, selected)),
            const SectionHeader('Körperdaten'),
            AppCard(child: _buildBodyCard(context, profile)),
            if (GoalsCalculator.calculateGoals(profile).calories > 0) ...[
              const SizedBox(height: Space.md),
              _buildGoalPreview(context, profile),
            ],
            const SectionHeader('Über mich'),
            AppCard(
              child: AppTextField(
                controller: _aboutMeController,
                hint:
                    'z. B. BJJ 3–5× pro Woche, koche nicht selbst, esse in der Mensa, abends oft Hunger, keine Allergien, mag Skyr …',
                helper:
                    'Der Coach nutzt diese Infos für persönliche Antworten.',
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                maxLines: 8,
                minLines: 4,
              ),
            ),
            const SectionHeader('Pläne'),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Ernährungs- und Trainingspläne'),
                subtitle: Text('${provider.activePlanCount} aktiv'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlansScreen()),
                  );
                },
              ),
            ),
            const SectionHeader('Darstellung'),
            AppCard(child: _buildAppearanceCard(context, provider)),
            const SizedBox(height: Space.xl),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiCard(
    BuildContext context,
    MainProvider provider,
    UserProfile profile,
    AiProvider selected,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final keyController = _apiKeyControllers[selected]!;
    final modelError = provider.modelErrorFor(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownMenu<AiProvider>(
          expandedInsets: EdgeInsets.zero,
          initialSelection: selected,
          label: const Text('Anbieter'),
          requestFocusOnTap: false,
          dropdownMenuEntries: [
            for (final p in AiProvider.values)
              DropdownMenuEntry(value: p, label: p.label),
          ],
          onSelected: (value) {
            if (value == null) return;
            setState(() {
              _selectedProvider = value;
              _showApiKey = false;
            });
          },
        ),
        const SizedBox(height: Space.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: selected.requiresPaidKey
              ? const StatusPill(
                  'API-Schlüssel mit Bezahlzugang nötig',
                  tone: PillTone.warning,
                  icon: Icons.credit_card_outlined,
                )
              : const StatusPill(
                  'Kostenlos nutzbar',
                  tone: PillTone.success,
                  icon: Icons.check_circle_outline,
                ),
        ),
        const SizedBox(height: Space.md),
        TextField(
          key: ValueKey('key-${selected.name}'),
          controller: keyController,
          obscureText: !_showApiKey,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: '${selected.label}-API-Schlüssel',
            helperText: selected.keyHint,
            helperMaxLines: 2,
            suffixIcon: IconButton(
              tooltip: _showApiKey ? 'Verbergen' : 'Anzeigen',
              icon: Icon(
                _showApiKey
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _showApiKey = !_showApiKey),
            ),
          ),
        ),
        if (!selected.requiresPaidKey && keyController.text.trim().isEmpty) ...[
          const SizedBox(height: Space.sm),
          Text(
            'Ohne Schlüssel werden Standardmodelle angezeigt.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: Space.md),
        DropdownMenu<String>(
          key: ValueKey('model-${selected.name}'),
          expandedInsets: EdgeInsets.zero,
          initialSelection: profile.modelFor(selected),
          label: const Text('Modell'),
          requestFocusOnTap: false,
          dropdownMenuEntries: [
            for (final model in provider.modelsFor(selected))
              DropdownMenuEntry(
                value: model.id,
                label: model.label,
                trailingIcon: model.free
                    ? const StatusPill('Gratis', tone: PillTone.success)
                    : const StatusPill('Bezahlt', tone: PillTone.warning),
              ),
          ],
          onSelected: (id) {
            if (id == null) return;
            provider.selectModel(selected, id);
          },
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            TextButton.icon(
              onPressed: provider.modelsRefreshing ? null : _refreshModels,
              icon: provider.modelsRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Modelle aktualisieren'),
            ),
            OutlinedButton(
              onPressed: _testing ? null : _testConnection,
              child: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verbindung testen'),
            ),
          ],
        ),
        if (modelError != null) ...[
          const SizedBox(height: Space.sm),
          Notice(message: modelError, tone: NoticeTone.error),
        ],
      ],
    );
  }

  Widget _buildBodyCard(BuildContext context, UserProfile profile) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField.number(
                controller: _ageController,
                label: 'Alter',
                suffix: 'J.',
                errorText: _ageError(profile),
                onChanged: _refresh,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppTextField.number(
                controller: _heightController,
                label: 'Größe',
                suffix: 'cm',
                errorText: _heightError(profile),
                onChanged: _refresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField.number(
                controller: _weightController,
                label: 'Gewicht',
                suffix: 'kg',
                errorText: _weightError(profile),
                onChanged: _refresh,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AppTextField.number(
                controller: _bodyFatController,
                label: 'Körperfett',
                suffix: '%',
                errorText: _bodyFatError(profile),
                onChanged: _refresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Körperfett ist optional und macht Grundumsatz und Protein über die Magermasse genauer.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Space.md),
        DropdownMenu<Gender>(
          expandedInsets: EdgeInsets.zero,
          initialSelection: _gender,
          label: const Text('Geschlecht'),
          requestFocusOnTap: false,
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: Gender.male, label: 'Männlich'),
            DropdownMenuEntry(value: Gender.female, label: 'Weiblich'),
          ],
          onSelected: (value) {
            if (value != null) setState(() => _gender = value);
          },
        ),
        const SizedBox(height: Space.md),
        DropdownMenu<ActivityLevel>(
          expandedInsets: EdgeInsets.zero,
          initialSelection: _activityLevel,
          label: const Text('Aktivitätslevel'),
          requestFocusOnTap: false,
          dropdownMenuEntries: [
            for (final level in ActivityLevel.values)
              DropdownMenuEntry(value: level, label: level.description),
          ],
          onSelected: (value) {
            if (value != null) setState(() => _activityLevel = value);
          },
        ),
        const SizedBox(height: Space.md),
        DropdownMenu<FitnessGoal>(
          expandedInsets: EdgeInsets.zero,
          initialSelection: _goal,
          label: const Text('Fitness-Ziel'),
          requestFocusOnTap: false,
          dropdownMenuEntries: [
            for (final goal in FitnessGoal.values)
              DropdownMenuEntry(value: goal, label: goal.description),
          ],
          onSelected: (value) {
            if (value != null) setState(() => _goal = value);
          },
        ),
        const SizedBox(height: Space.xs),
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
      ],
    );
  }

  Widget _buildGoalPreview(BuildContext context, UserProfile profile) {
    final goals = GoalsCalculator.calculateGoals(profile);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final usesLeanMass = GoalsCalculator.leanMassKg(profile) != null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Deine Ziele', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            '${goals.calories} kcal pro Tag',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.md,
            runSpacing: Space.xs,
            children: [
              _macroChip(
                context,
                colors.protein,
                'Protein',
                goals.proteinGrams,
              ),
              _macroChip(
                context,
                colors.carbs,
                'Kohlenhydrate',
                goals.carbsGrams,
              ),
              _macroChip(context, colors.fat, 'Fett', goals.fatGrams),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Grundumsatz ${GoalsCalculator.calculateBmr(profile).round()} kcal '
            '(${usesLeanMass ? 'Katch-McArdle, Magermasse' : 'Mifflin-St Jeor'}) · '
            'Erhaltung ca. ${goals.maintenanceCalories} kcal',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroChip(
    BuildContext context,
    Color color,
    String label,
    int grams,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: Space.sm,
          height: Space.sm,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Space.xs),
        Text('$label $grams g', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAppearanceCard(BuildContext context, MainProvider provider) {
    final activeKey = AppPalettes.byKey(provider.currentTheme).key;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          children: [
            for (final palette in AppPalettes.all)
              _paletteOption(
                context,
                palette,
                highlighted: palette.key == activeKey,
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined, size: 20),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 20),
                label: Text('Hell'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 20),
                label: Text('Dunkel'),
              ),
            ],
            selected: {provider.themeMode},
            onSelectionChanged: (selection) =>
                provider.changeThemeMode(selection.first),
          ),
        ),
      ],
    );
  }

  Widget _paletteOption(
    BuildContext context,
    AppPalette palette, {
    required bool highlighted,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: highlighted,
      label: palette.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(Corner.sm),
        onTap: () => context.read<MainProvider>().changeTheme(palette.key),
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.swatch,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: highlighted ? scheme.primary : scheme.onSurface,
                    width: highlighted ? Stroke.emphasis : Stroke.hairline,
                  ),
                ),
                child: highlighted
                    ? Icon(
                        Icons.check_rounded,
                        size: 20,
                        color:
                            ThemeData.estimateBrightnessForColor(
                                  palette.swatch,
                                ) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      )
                    : null,
              ),
              const SizedBox(height: Space.xs),
              Text(
                palette.label,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
