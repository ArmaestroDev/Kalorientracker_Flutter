import 'package:flutter/material.dart';

/// Unified dialog for entering meals or activities via text
/// AI will classify whether the input is a food or activity
class UnifiedInputDialog extends StatefulWidget {
  final Function(String name, String description) onSubmit;

  const UnifiedInputDialog({super.key, required this.onSubmit});

  @override
  State<UnifiedInputDialog> createState() => _UnifiedInputDialogState();
}

class _UnifiedInputDialogState extends State<UnifiedInputDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eintrag hinzufügen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gib eine Mahlzeit oder Aktivität ein - die KI erkennt automatisch, was es ist.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Mahlzeit oder Aktivität',
                hintText: 'z.B. 100g Reis oder 30 min Joggen',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Beschreibung (optional)',
                hintText: 'z.B. mit Soße, im Fitnessstudio',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              widget.onSubmit(
                _nameController.text,
                _descriptionController.text,
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
