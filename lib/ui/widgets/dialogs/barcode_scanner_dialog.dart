import 'package:flutter/material.dart';
import '../../../data/services/food_api_service.dart';

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

  int get _grams => int.tryParse(_gramsController.text) ?? 100;

  double get _factor => _grams / 100.0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.foodInfo.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nährwerte pro 100g:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Kalorien: ${widget.foodInfo.calories} kcal'),
            Text('Protein: ${widget.foodInfo.protein.toStringAsFixed(1)}g'),
            Text('Kohlenhydrate: ${widget.foodInfo.carbs.toStringAsFixed(1)}g'),
            Text('Fett: ${widget.foodInfo.fat.toStringAsFixed(1)}g'),
            const SizedBox(height: 16),
            TextField(
              controller: _gramsController,
              decoration: const InputDecoration(
                labelText: 'Menge (in Gramm)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
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
                    'Für $_grams g:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '${(widget.foodInfo.calories * _factor).round()} kcal',
                    style: TextStyle(
                      fontSize: 20,
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
          onPressed: () {
            widget.onConfirm(_grams);
            Navigator.of(context).pop();
          },
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
