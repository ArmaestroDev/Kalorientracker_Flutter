import 'package:flutter/material.dart';
import '../../../data/services/food_api_service.dart';
import '../../../logic/number_format.dart';
import '../app_text_field.dart';

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
    if (_grams == null) return;
    widget.onConfirm(_grams!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nährwerte pro 100 $_unit:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Kalorien: ${formatLocalizedNumber(kcal100)} kcal'),
            Text('Protein: ${formatLocalizedNumber(p100)} g'),
            Text('Kohlenhydrate: ${formatLocalizedNumber(c100)} g'),
            Text('Fett: ${formatLocalizedNumber(f100)} g'),
            const SizedBox(height: 16),
            AppTextField.number(
              controller: _gramsController,
              label: 'Menge',
              suffix: _unit,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Für ${_grams ?? 0} $_unit:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '${(kcal100 * _factor).round()} kcal · '
                    'P ${(p100 * _factor).round()} g · '
                    'K ${(c100 * _factor).round()} g · '
                    'F ${(f100 * _factor).round()} g',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
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
        FilledButton(
          onPressed: _grams == null ? null : _confirm,
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
