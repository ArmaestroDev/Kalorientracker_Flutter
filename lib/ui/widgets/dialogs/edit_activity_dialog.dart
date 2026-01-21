import 'package:flutter/material.dart';
import '../../../data/models/activity_entry.dart';

class EditActivityDialog extends StatefulWidget {
  final ActivityEntry activityEntry;
  final Function(ActivityEntry) onSaveManual;
  final Function(ActivityEntry) onRecalculate;

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
  late TextEditingController _nameController;
  late TextEditingController _caloriesController;

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

  void _saveManual() {
    final updated = widget.activityEntry.copyWith(
      name: _nameController.text,
      caloriesBurned: int.tryParse(_caloriesController.text) ?? 0,
    );
    widget.onSaveManual(updated);
    Navigator.of(context).pop();
  }

  void _recalculate() {
    widget.onRecalculate(widget.activityEntry);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aktivität bearbeiten'),
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
                labelText: 'Verbrannte Kalorien',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
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
