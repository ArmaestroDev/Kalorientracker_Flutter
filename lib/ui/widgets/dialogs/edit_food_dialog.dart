import 'package:flutter/material.dart';

import '../../../data/models/food_entry.dart';
import '../../../logic/number_format.dart';
import '../../theme/tokens.dart';
import '../app_text_field.dart';

class EditFoodDialog extends StatefulWidget {
  final FoodEntry foodEntry;
  final ValueChanged<FoodEntry> onSaveManual;
  final ValueChanged<FoodEntry> onRecalculate;

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
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;

  late double _baseAmount;
  late List<double> _baseValues;
  double _portionMultiplier = 1.0;
  bool _submitted = false;

  bool get _hasAmount =>
      widget.foodEntry.amount != null &&
      widget.foodEntry.amount! > 0 &&
      widget.foodEntry.unit != null;

  List<TextEditingController> get _valueControllers => [
    _caloriesController,
    _proteinController,
    _carbsController,
    _fatController,
  ];

  @override
  void initState() {
    super.initState();
    final entry = widget.foodEntry;
    _nameController = TextEditingController(text: entry.name);
    _amountController = TextEditingController(
      text: _hasAmount ? formatLocalizedNumber(entry.amount!) : '',
    );
    _caloriesController = TextEditingController(text: '${entry.calories}');
    _proteinController = TextEditingController(text: '${entry.protein}');
    _carbsController = TextEditingController(text: '${entry.carbs}');
    _fatController = TextEditingController(text: '${entry.fat}');
    _resetScaleBase();
  }

  void _resetScaleBase() {
    _baseAmount = _hasAmount
        ? (parseLocalizedNumber(_amountController.text) ??
              widget.foodEntry.amount!)
        : 1;
    _portionMultiplier = 1.0;
    _baseValues = _valueControllers
        .map((c) => parseLocalizedNumber(c.text) ?? 0)
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    for (final c in _valueControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onAmountChanged(String text) {
    final amount = parseLocalizedNumber(text);
    if (amount == null || amount <= 0 || _baseAmount <= 0) return;
    _applyFactor(amount / _baseAmount);
  }

  void _applyFactor(double factor) {
    setState(() {
      final controllers = _valueControllers;
      for (var i = 0; i < controllers.length; i++) {
        controllers[i].text = (_baseValues[i] * factor).round().toString();
      }
    });
  }

  void _applyPortionChip(double chipFactor) {
    _portionMultiplier *= chipFactor;
    _applyFactor(_portionMultiplier);
  }

  void _onValueEdited(String _) {
    _resetScaleBase();
    if (_submitted) setState(() {});
  }

  int? _parseInt(TextEditingController controller) {
    final value = parseLocalizedNumber(controller.text);
    return value?.round();
  }

  String? _errorFor(TextEditingController controller, {bool required = false}) {
    if (!_submitted) return null;
    final value = parseLocalizedNumber(controller.text);
    if (controller.text.trim().isEmpty) return required ? 'Pflichtfeld' : null;
    if (value == null || value < 0) return 'Ungültige Zahl';
    return null;
  }

  bool get _isValid {
    if (_nameController.text.trim().isEmpty) return false;
    if (_hasAmount) {
      final amount = parseLocalizedNumber(_amountController.text);
      if (amount == null || amount <= 0) return false;
    }
    if (_parseInt(_caloriesController) == null) return false;
    for (final c in [_proteinController, _carbsController, _fatController]) {
      if (c.text.trim().isNotEmpty &&
          (parseLocalizedNumber(c.text) ?? -1) < 0) {
        return false;
      }
    }
    return true;
  }

  FoodEntry _buildEntry() {
    return widget.foodEntry.copyWith(
      name: _nameController.text.trim(),
      amount: _hasAmount ? parseLocalizedNumber(_amountController.text) : null,
      calories: _parseInt(_caloriesController) ?? 0,
      protein: _parseInt(_proteinController) ?? 0,
      carbs: _parseInt(_carbsController) ?? 0,
      fat: _parseInt(_fatController) ?? 0,
    );
  }

  void _saveManual() {
    setState(() => _submitted = true);
    if (!_isValid) return;
    widget.onSaveManual(_buildEntry());
    Navigator.of(context).pop();
  }

  void _recalculate() {
    final parsedAmount = _hasAmount
        ? parseLocalizedNumber(_amountController.text)
        : null;
    if (_nameController.text.trim().isEmpty ||
        (_hasAmount && (parsedAmount == null || parsedAmount <= 0))) {
      setState(() => _submitted = true);
      return;
    }
    widget.onRecalculate(
      widget.foodEntry.copyWith(
        name: _nameController.text.trim(),
        amount: parsedAmount,
        clearAmount: !_hasAmount,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Mahlzeit bearbeiten'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _nameController,
              label: 'Name',
              textCapitalization: TextCapitalization.sentences,
              errorText: _submitted && _nameController.text.trim().isEmpty
                  ? 'Pflichtfeld'
                  : null,
              onChanged: (_) {
                if (_submitted) setState(() {});
              },
            ),
            const SizedBox(height: Space.md),
            if (_hasAmount)
              AppTextField.number(
                controller: _amountController,
                label: 'Menge',
                suffix: widget.foodEntry.unit,
                helper: 'Kalorien und Makros werden automatisch angepasst',
                errorText:
                    _submitted &&
                        ((parseLocalizedNumber(_amountController.text) ?? 0) <=
                            0)
                    ? 'Ungültige Zahl'
                    : null,
                onChanged: _onAmountChanged,
              )
            else ...[
              Text('Portion anpassen', style: textTheme.labelLarge),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                children: [
                  for (final factor in const [0.5, 0.75, 1.5, 2.0])
                    ActionChip(
                      label: Text(
                        '${formatLocalizedNumber(factor, decimals: 2)}×',
                      ),
                      onPressed: () => _applyPortionChip(factor),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.md),
            AppTextField.number(
              controller: _caloriesController,
              label: 'Kalorien',
              suffix: 'kcal',
              errorText: _errorFor(_caloriesController, required: true),
              onChanged: _onValueEdited,
            ),
            const SizedBox(height: Space.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField.number(
                    controller: _proteinController,
                    label: 'Protein',
                    suffix: 'g',
                    errorText: _errorFor(_proteinController),
                    onChanged: _onValueEdited,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: AppTextField.number(
                    controller: _carbsController,
                    label: 'Kohlenh.',
                    suffix: 'g',
                    errorText: _errorFor(_carbsController),
                    onChanged: _onValueEdited,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: AppTextField.number(
                    controller: _fatController,
                    label: 'Fett',
                    suffix: 'g',
                    errorText: _errorFor(_fatController),
                    onChanged: _onValueEdited,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            OutlinedButton.icon(
              onPressed: _recalculate,
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: const Text('Mit KI neu schätzen'),
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Nutzt den Namen und die Menge von oben.',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _saveManual, child: const Text('Speichern')),
      ],
    );
  }
}
