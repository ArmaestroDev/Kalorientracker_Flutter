import 'package:flutter/material.dart';
import '../../../data/models/activity_entry.dart';
import '../../../logic/number_format.dart';
import '../app_text_field.dart';

class EditActivityDialog extends StatefulWidget {
  final ActivityEntry activityEntry;
  final ValueChanged<ActivityEntry> onSaveManual;
  final ValueChanged<ActivityEntry> onRecalculate;

  const EditActivityDialog({
    super.key,
    required this.activityEntry,
    required this.onSaveManual,
    required this.onRecalculate,
  });

  @override
  State<EditActivityDialog> createState() => _EditActivityDialogState();
}

class _EditActivityDialogState extends State<EditActivityDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.activityEntry.name);
    _caloriesController = TextEditingController(
      text: widget.activityEntry.caloriesBurned.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  int? get _calories {
    final value = parseLocalizedNumber(_caloriesController.text);
    return value == null || value < 0 ? null : value.round();
  }

  void _saveManual() {
    setState(() => _submitted = true);
    if (_nameController.text.trim().isEmpty || _calories == null) return;
    widget.onSaveManual(
      widget.activityEntry.copyWith(
        name: _nameController.text.trim(),
        caloriesBurned: _calories,
      ),
    );
    Navigator.of(context).pop();
  }

  void _recalculate() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _submitted = true);
      return;
    }
    widget.onRecalculate(
      widget.activityEntry.copyWith(name: _nameController.text.trim()),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aktivität bearbeiten'),
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
            ),
            const SizedBox(height: 12),
            AppTextField.number(
              controller: _caloriesController,
              label: 'Verbrannte Kalorien',
              suffix: 'kcal',
              errorText: _submitted && _calories == null
                  ? 'Ungültige Zahl'
                  : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _recalculate,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Mit KI neu schätzen'),
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
