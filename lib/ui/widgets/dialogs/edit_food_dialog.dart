import 'package:flutter/material.dart';
import '../../../data/models/food_entry.dart';

class EditFoodDialog extends StatefulWidget {
  final FoodEntry foodEntry;
  final Function(FoodEntry) onSaveManual;
  final Function(FoodEntry) onRecalculate;

  const EditFoodDialog({
    super.key,
    required this.foodEntry,
    required this.onSaveManual,
    required this.onRecalculate,
  });

  @override
  State<EditFoodDialog> createState() => _EditFoodDialogState();
}

class _EditFoodDialogState extends State<EditFoodDialog> {
  late TextEditingController _nameController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.foodEntry.name);
    _caloriesController = TextEditingController(
      text: widget.foodEntry.calories.toString(),
    );
    _proteinController = TextEditingController(
      text: widget.foodEntry.protein.toString(),
    );
    _carbsController = TextEditingController(
      text: widget.foodEntry.carbs.toString(),
    );
    _fatController = TextEditingController(
      text: widget.foodEntry.fat.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _saveManual() {
    final updated = widget.foodEntry.copyWith(
      name: _nameController.text,
      calories: int.tryParse(_caloriesController.text) ?? 0,
      protein: int.tryParse(_proteinController.text) ?? 0,
      carbs: int.tryParse(_carbsController.text) ?? 0,
      fat: int.tryParse(_fatController.text) ?? 0,
    );
    widget.onSaveManual(updated);
    Navigator.of(context).pop();
  }

  void _recalculate() {
    widget.onRecalculate(widget.foodEntry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mahlzeit bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caloriesController,
              decoration: const InputDecoration(
                labelText: 'Kalorien',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proteinController,
                    decoration: const InputDecoration(
                      labelText: 'Protein (g)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _carbsController,
                    decoration: const InputDecoration(
                      labelText: 'Kohlenh. (g)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fatController,
                    decoration: const InputDecoration(
                      labelText: 'Fett (g)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        OutlinedButton(
          onPressed: _recalculate,
          child: const Text('Neu berechnen'),
        ),
        FilledButton(onPressed: _saveManual, child: const Text('Speichern')),
      ],
    );
  }
}
