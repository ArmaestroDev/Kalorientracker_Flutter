import 'package:flutter/material.dart';

import '../../../data/services/food_api_service.dart';
import '../../../logic/number_format.dart';
import '../../theme/tokens.dart';
import '../app_text_field.dart';
import '../kit/kit.dart';

class BarcodeScannerResultDialog extends StatefulWidget {
  final FoodNutritionInfo foodInfo;
  final Function(int grams) onConfirm;
  final VoidCallback onDismiss;

  const BarcodeScannerResultDialog({
    super.key,
    required this.foodInfo,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  State<BarcodeScannerResultDialog> createState() =>
      _BarcodeScannerResultDialogState();
}

class _BarcodeScannerResultDialogState
    extends State<BarcodeScannerResultDialog> {
  final _gramsController = TextEditingController(text: '100');
  String? _error;

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  String get _unit => widget.foodInfo.unit == 'ml' ? 'ml' : 'g';

  int? get _grams {
    final value = parseLocalizedNumber(_gramsController.text);
    return value == null || value <= 0 ? null : value.round();
  }

  double get _factor => (_grams ?? 0) / 100.0;

  void _confirm() {
    final grams = _grams;
    if (grams == null) {
      setState(() => _error = 'Bitte eine gültige Zahl eingeben');
      return;
    }
    widget.onConfirm(grams);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kcal100 =
        widget.foodInfo.caloriesPer100g ?? widget.foodInfo.calories.toDouble();
    final p100 = widget.foodInfo.proteinPer100g ?? widget.foodInfo.protein;
    final c100 = widget.foodInfo.carbsPer100g ?? widget.foodInfo.carbs;
    final f100 = widget.foodInfo.fatPer100g ?? widget.foodInfo.fat;

    return AlertDialog(
      title: Text(widget.foodInfo.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nährwerte pro 100 $_unit',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  _NutrientRow(
                    label: 'Kalorien',
                    value: '${formatLocalizedNumber(kcal100)} kcal',
                  ),
                  _NutrientRow(
                    label: 'Protein',
                    value: '${formatLocalizedNumber(p100)} g',
                  ),
                  _NutrientRow(
                    label: 'Kohlenhydrate',
                    value: '${formatLocalizedNumber(c100)} g',
                  ),
                  _NutrientRow(
                    label: 'Fett',
                    value: '${formatLocalizedNumber(f100)} g',
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            AppTextField.number(
              controller: _gramsController,
              label: 'Menge',
              suffix: _unit,
              autofocus: true,
              errorText: _error,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _confirm(),
            ),
            if (_grams != null) ...[
              const SizedBox(height: Space.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Für ${_grams ?? 0} $_unit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      '${(kcal100 * _factor).round()} kcal · '
                      'P ${(p100 * _factor).round()} g · '
                      'K ${(c100 * _factor).round()} g · '
                      'F ${(f100 * _factor).round()} g',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onDismiss();
            Navigator.of(context).pop();
          },
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Hinzufügen')),
      ],
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final String label;
  final String value;

  const _NutrientRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xxs),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
